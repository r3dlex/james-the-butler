defmodule James.ExecutionHistoryTest do
  use James.DataCase

  alias James.{Accounts, ExecutionHistory, Hosts, Sessions}

  defp create_session do
    {:ok, user} = Accounts.create_user(%{email: "eh_#{System.unique_integer()}@example.com"})

    {:ok, host} =
      Hosts.create_host(%{
        name: "eh-host-#{System.unique_integer()}",
        endpoint: "http://localhost:9700"
      })

    {:ok, session} =
      Sessions.create_session(%{user_id: user.id, host_id: host.id, name: "EH Session"})

    session
  end

  describe "create_entry/1" do
    test "creates with session_id only" do
      session = create_session()

      {:ok, entry} = ExecutionHistory.create_entry(%{session_id: session.id})
      assert entry.session_id == session.id
      assert is_nil(entry.narrative_summary)
      assert is_nil(entry.structured_log)
    end

    test "creates with structured_log and narrative_summary" do
      session = create_session()

      {:ok, entry} =
        ExecutionHistory.create_entry(%{
          session_id: session.id,
          structured_log: %{"steps" => 3, "tool" => "bash"},
          narrative_summary: "Ran 3 bash commands successfully."
        })

      assert entry.structured_log == %{"steps" => 3, "tool" => "bash"}
      assert entry.narrative_summary == "Ran 3 bash commands successfully."
    end

    test "requires session_id" do
      assert {:error, changeset} = ExecutionHistory.create_entry(%{})
      assert %{session_id: [_ | _]} = errors_on(changeset)
    end
  end

  describe "list_entries/1" do
    test "returns entries for session_id" do
      session = create_session()

      {:ok, _} = ExecutionHistory.create_entry(%{session_id: session.id})
      {:ok, _} = ExecutionHistory.create_entry(%{session_id: session.id})

      entries = ExecutionHistory.list_entries(session_id: session.id)
      assert length(entries) == 2
    end

    test "does not return entries for other sessions" do
      s1 = create_session()
      s2 = create_session()

      {:ok, _} = ExecutionHistory.create_entry(%{session_id: s1.id})

      assert ExecutionHistory.list_entries(session_id: s2.id) == []
    end

    test "returns all entries when no filter" do
      session = create_session()
      before_count = length(ExecutionHistory.list_entries())

      {:ok, _} = ExecutionHistory.create_entry(%{session_id: session.id})
      assert length(ExecutionHistory.list_entries()) == before_count + 1
    end
  end

  describe "get_entry/1 and get_entry!/1" do
    test "get_entry returns entry" do
      session = create_session()
      {:ok, entry} = ExecutionHistory.create_entry(%{session_id: session.id})

      assert ExecutionHistory.get_entry(entry.id).id == entry.id
    end

    test "get_entry returns nil for unknown id" do
      assert is_nil(ExecutionHistory.get_entry(Ecto.UUID.generate()))
    end

    test "get_entry! raises for unknown id" do
      assert_raise Ecto.NoResultsError, fn ->
        ExecutionHistory.get_entry!(Ecto.UUID.generate())
      end
    end
  end

  describe "update_narrative/2" do
    test "sets narrative_summary" do
      session = create_session()
      {:ok, entry} = ExecutionHistory.create_entry(%{session_id: session.id})

      {:ok, updated} = ExecutionHistory.update_narrative(entry, "Summary text here.")
      assert updated.narrative_summary == "Summary text here."
    end
  end
end
