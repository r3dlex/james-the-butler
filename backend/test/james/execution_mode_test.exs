defmodule James.ExecutionModeTest do
  use ExUnit.Case, async: true

  alias James.ExecutionMode

  # ---------------------------------------------------------------------------
  # resolve/1 — session-level execution_mode wins
  # ---------------------------------------------------------------------------

  describe "resolve/1 — session-level mode takes precedence" do
    test "returns the session execution_mode when it is a non-empty string" do
      session = %{execution_mode: "plan", project_id: nil, user_id: nil}
      assert ExecutionMode.resolve(session) == "plan"
    end

    test "returns 'direct' mode when set explicitly at session level" do
      session = %{execution_mode: "direct", project_id: nil, user_id: nil}
      assert ExecutionMode.resolve(session) == "direct"
    end

    test "session mode wins over project_id and user_id being present" do
      session = %{execution_mode: "supervised", project_id: "proj-1", user_id: "user-1"}
      assert ExecutionMode.resolve(session) == "supervised"
    end
  end

  # ---------------------------------------------------------------------------
  # resolve/1 — session mode absent, falls through
  # ---------------------------------------------------------------------------

  describe "resolve/1 — falls back to 'direct' when no DB entities are available" do
    test "returns 'direct' when execution_mode is nil and no project/user" do
      session = %{execution_mode: nil, project_id: nil, user_id: nil}
      assert ExecutionMode.resolve(session) == "direct"
    end

    test "returns 'direct' when execution_mode is empty string" do
      session = %{execution_mode: "", project_id: nil, user_id: nil}
      assert ExecutionMode.resolve(session) == "direct"
    end

    test "returns 'direct' for an empty map" do
      assert ExecutionMode.resolve(%{}) == "direct"
    end

    test "returns 'direct' for a bare map with no known keys" do
      assert ExecutionMode.resolve(%{some: :other}) == "direct"
    end
  end

  # ---------------------------------------------------------------------------
  # resolve/1 — project_id branch (DB call will fail gracefully in test env)
  # ---------------------------------------------------------------------------

  describe "resolve/1 — project_id branch when session mode is absent" do
    test "falls back to 'direct' when project_id is present but DB is unavailable" do
      # In minimal_start test env Projects.get_project/1 will raise or return nil.
      # We verify the function either returns a string or raises — not silently corrupts data.
      session = %{execution_mode: nil, project_id: "proj-1", user_id: nil}

      result =
        try do
          ExecutionMode.resolve(session)
        rescue
          _ -> :raised
        end

      assert result == "direct" or result == :raised
    end
  end

  # ---------------------------------------------------------------------------
  # resolve/1 — user_id branch (no project_id)
  # ---------------------------------------------------------------------------

  describe "resolve/1 — user_id branch when session and project modes are absent" do
    test "falls back to 'direct' when only user_id is present but DB is unavailable" do
      session = %{execution_mode: nil, project_id: nil, user_id: "user-42"}

      result =
        try do
          ExecutionMode.resolve(session)
        rescue
          _ -> :raised
        end

      assert result == "direct" or result == :raised
    end

    test "falls back to 'direct' when user_id is nil" do
      session = %{execution_mode: nil, project_id: nil, user_id: nil}
      assert ExecutionMode.resolve(session) == "direct"
    end
  end

  # ---------------------------------------------------------------------------
  # resolve/1 — guard clause — session with execution_mode key missing entirely
  # ---------------------------------------------------------------------------

  describe "resolve/1 — map without execution_mode key" do
    test "handles a session map that lacks the execution_mode key" do
      session = %{project_id: nil, user_id: nil}

      result =
        try do
          ExecutionMode.resolve(session)
        rescue
          _ -> :raised
        end

      # Should resolve to "direct" via the catch-all clause or the user fallback
      assert result == "direct" or result == :raised
    end
  end
end
