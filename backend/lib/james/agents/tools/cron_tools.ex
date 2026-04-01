defmodule James.Agents.Tools.CronTools do
  @moduledoc """
  Agent tool implementations for managing cron tasks.

  Provides three tools that agents can call:
  - `cron_schedule` — create a new cron task for the current session.
  - `cron_delete`   — remove an existing cron task by ID.
  - `cron_list`     — list all active cron tasks for the current session.

  The `execute/3` function follows the standard tool-execution contract used by
  other agent tools in this codebase: it accepts a tool name string, a map of
  string-keyed parameters, and a state map containing at least `:session_id`.
  It returns a `{:ok, result_string}` or `{:error, reason_string}` tuple.
  """

  alias James.Cron
  alias James.Cron.Parser

  # ---------------------------------------------------------------------------
  # Tool definitions
  # ---------------------------------------------------------------------------

  @doc "Returns the list of tool schema maps for the three cron tools."
  def tool_definitions do
    [
      %{
        name: "cron_schedule",
        description: "Schedule a recurring or one-off cron task for the current session.",
        input_schema: %{
          type: "object",
          properties: %{
            cron: %{type: "string", description: "5-field cron expression (e.g. '*/5 * * * *')"},
            prompt: %{
              type: "string",
              description: "Prompt text to inject into the session when the task fires"
            },
            recurring: %{type: "boolean", description: "Whether the task repeats (default true)"}
          },
          required: ["cron", "prompt"]
        }
      },
      %{
        name: "cron_delete",
        description: "Delete a cron task by its ID.",
        input_schema: %{
          type: "object",
          properties: %{
            id: %{type: "string", description: "The UUID of the cron task to delete"}
          },
          required: ["id"]
        }
      },
      %{
        name: "cron_list",
        description: "List all cron tasks for the current session.",
        input_schema: %{
          type: "object",
          properties: %{},
          required: []
        }
      }
    ]
  end

  # ---------------------------------------------------------------------------
  # Execute
  # ---------------------------------------------------------------------------

  @doc """
  Executes a cron tool by name.

  Returns `{:ok, message}` on success or `{:error, message}` on failure.
  """
  def execute("cron_schedule", params, state) do
    cron_expr = Map.get(params, "cron")
    prompt = Map.get(params, "prompt")
    recurring = Map.get(params, "recurring", true)

    case Parser.next_fire_at(cron_expr, DateTime.utc_now()) do
      {:ok, next_fire_at} ->
        attrs = %{
          session_id: state.session_id,
          cron_expression: cron_expr,
          prompt: prompt,
          recurring: recurring,
          next_fire_at: next_fire_at
        }

        case Cron.create_cron_task(attrs) do
          {:ok, task} ->
            {:ok,
             "Cron task scheduled. ID: #{task.id}, next fire at: #{DateTime.to_iso8601(task.next_fire_at)}"}

          {:error, changeset} ->
            {:error, "Failed to create cron task: #{inspect(changeset.errors)}"}
        end

      {:error, :invalid_cron} ->
        {:error, "Invalid cron expression: #{inspect(cron_expr)}"}
    end
  end

  def execute("cron_delete", params, _state) do
    id = Map.get(params, "id")

    case Cron.get_cron_task(id) do
      nil ->
        {:error, "Cron task not found: #{id}"}

      task ->
        {:ok, _} = Cron.delete_cron_task(task)
        {:ok, "Cron task #{id} deleted."}
    end
  end

  def execute("cron_list", _params, state) do
    tasks = Cron.list_cron_tasks_for_session(state.session_id)

    if tasks == [] do
      {:ok, "No cron tasks scheduled for this session."}
    else
      lines =
        Enum.map(tasks, fn t ->
          "- #{t.id}: #{t.cron_expression} | #{t.prompt} | enabled: #{t.enabled}"
        end)

      {:ok, Enum.join(lines, "\n")}
    end
  end
end
