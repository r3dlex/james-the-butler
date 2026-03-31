defmodule JamesWeb.HookController do
  use Phoenix.Controller, formats: [:json]

  alias James.Hooks

  def index(conn, _params) do
    user = conn.assigns.current_user
    hooks = Hooks.list_hooks(user.id)
    json(conn, %{hooks: Enum.map(hooks, &hook_json/1)})
  end

  def create(conn, params) do
    user = conn.assigns.current_user
    attrs = Map.put(params, "user_id", user.id)

    case Hooks.create_hook(attrs) do
      {:ok, hook} ->
        conn |> put_status(:created) |> json(%{hook: hook_json(hook)})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(changeset)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Hooks.get_hook(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not found"})

      hook ->
        case Hooks.update_hook(hook, params) do
          {:ok, updated} ->
            json(conn, %{hook: hook_json(updated)})

          {:error, changeset} ->
            conn |> put_status(:unprocessable_entity) |> json(%{errors: format_errors(changeset)})
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case Hooks.get_hook(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not found"})

      hook ->
        {:ok, _} = Hooks.delete_hook(hook)
        json(conn, %{ok: true})
    end
  end

  defp hook_json(h) do
    %{
      id: h.id,
      scope: h.scope,
      event: h.event,
      type: h.type,
      config: h.config,
      matcher: h.matcher,
      enabled: h.enabled,
      inserted_at: h.inserted_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
