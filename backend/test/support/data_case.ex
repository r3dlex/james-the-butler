defmodule James.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring access to the application's
  data layer. It wraps each test in a database transaction that is rolled back
  after the test completes, ensuring test isolation.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias James.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import James.DataCase
    end
  end

  setup tags do
    James.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(James.Repo, shared: not tags[:async])

    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
