defmodule James.TokensTest do
  use James.DataCase

  alias James.{Accounts, Sessions, Tokens}

  defp create_user(email \\ "token_user@example.com") do
    {:ok, user} = Accounts.create_user(%{email: email})
    user
  end

  defp create_session(user) do
    {:ok, session} = Sessions.create_session(%{user_id: user.id, name: "Token Session"})
    session
  end

  describe "record_usage/1" do
    test "creates a token ledger entry with session_id and model" do
      user = create_user()
      session = create_session(user)

      assert {:ok, entry} =
               Tokens.record_usage(%{
                 session_id: session.id,
                 model: "claude-3-5-sonnet",
                 input_tokens: 100,
                 output_tokens: 50
               })

      assert entry.session_id == session.id
      assert entry.model == "claude-3-5-sonnet"
      assert entry.input_tokens == 100
      assert entry.output_tokens == 50
    end

    test "fails when session_id is missing" do
      assert {:error, changeset} = Tokens.record_usage(%{model: "claude-3-5-sonnet"})
      assert %{session_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "fails when model is missing" do
      user = create_user("token_no_model@example.com")
      session = create_session(user)
      assert {:error, changeset} = Tokens.record_usage(%{session_id: session.id})
      assert %{model: ["can't be blank"]} = errors_on(changeset)
    end

    test "records cost_usd" do
      user = create_user("token_cost@example.com")
      session = create_session(user)

      {:ok, entry} =
        Tokens.record_usage(%{
          session_id: session.id,
          model: "claude-3-5-sonnet",
          cost_usd: Decimal.new("0.0025")
        })

      assert Decimal.eq?(entry.cost_usd, Decimal.new("0.0025"))
    end
  end

  describe "list_usage/1" do
    test "returns usage entries for a session" do
      user = create_user("token_list@example.com")
      session = create_session(user)

      {:ok, _} =
        Tokens.record_usage(%{
          session_id: session.id,
          model: "claude-3-5-sonnet",
          input_tokens: 100
        })

      {:ok, _} =
        Tokens.record_usage(%{
          session_id: session.id,
          model: "claude-3-5-sonnet",
          input_tokens: 200
        })

      entries = Tokens.list_usage(session_id: session.id)
      assert length(entries) == 2
    end

    test "filters by model" do
      user = create_user("token_model_filter@example.com")
      session = create_session(user)
      {:ok, _} = Tokens.record_usage(%{session_id: session.id, model: "sonnet", input_tokens: 10})
      {:ok, _} = Tokens.record_usage(%{session_id: session.id, model: "haiku", input_tokens: 5})
      entries = Tokens.list_usage(session_id: session.id, model: "haiku")
      assert length(entries) == 1
      assert hd(entries).model == "haiku"
    end

    test "returns empty list when no entries exist" do
      user = create_user("token_empty@example.com")
      session = create_session(user)
      assert Tokens.list_usage(session_id: session.id) == []
    end
  end

  describe "usage_summary/1" do
    test "aggregates totals grouped by model" do
      user = create_user("token_summary@example.com")
      session = create_session(user)

      {:ok, _} =
        Tokens.record_usage(%{
          session_id: session.id,
          model: "claude-3-5-sonnet",
          input_tokens: 100,
          output_tokens: 50
        })

      {:ok, _} =
        Tokens.record_usage(%{
          session_id: session.id,
          model: "claude-3-5-sonnet",
          input_tokens: 200,
          output_tokens: 75
        })

      summary = Tokens.usage_summary(session_id: session.id)
      assert length(summary) == 1
      row = hd(summary)
      assert row.model == "claude-3-5-sonnet"
      assert row.total_input == 300
      assert row.total_output == 125
    end

    test "returns empty list when no entries" do
      user = create_user("token_empty_summary@example.com")
      session = create_session(user)
      assert Tokens.usage_summary(session_id: session.id) == []
    end
  end
end
