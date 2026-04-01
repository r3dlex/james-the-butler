defmodule James.PersonalityResolveTest do
  use James.DataCase

  alias James.{Accounts, Hosts, Personality, Projects, Sessions}

  defp create_user(attrs \\ %{}) do
    {:ok, user} =
      Accounts.create_user(
        Map.merge(%{email: "pers_#{System.unique_integer()}@example.com"}, attrs)
      )

    user
  end

  defp create_host do
    {:ok, host} =
      Hosts.create_host(%{
        name: "pers-host-#{System.unique_integer()}",
        endpoint: "http://localhost:9600"
      })

    host
  end

  defp create_session(user, host, attrs \\ %{}) do
    {:ok, session} =
      Sessions.create_session(
        Map.merge(%{user_id: user.id, host_id: host.id, name: "Pers Session"}, attrs)
      )

    session
  end

  defp create_profile(user, attrs \\ %{}) do
    {:ok, profile} =
      Accounts.create_personality_profile(
        Map.merge(%{user_id: user.id, name: "test-profile", preset: "collaborator"}, attrs)
      )

    profile
  end

  # ---------------------------------------------------------------------------
  # resolve_system_prompt/1
  # ---------------------------------------------------------------------------

  describe "resolve_system_prompt/1" do
    test "returns default prompt when session has no personality and no user/project personality" do
      user = create_user()
      host = create_host()
      session = create_session(user, host)

      prompt = Personality.resolve_system_prompt(session)
      assert is_binary(prompt) and String.length(prompt) > 0
    end

    test "uses session personality_id when set" do
      user = create_user()
      host = create_host()
      profile = create_profile(user, %{preset: "silent"})
      session = create_session(user, host, %{personality_id: profile.id})

      prompt = Personality.resolve_system_prompt(session)
      # Silent preset: output only
      assert is_binary(prompt)
      assert String.downcase(prompt) =~ "no commentary"
    end

    test "uses user personality when session has none" do
      user = create_user()
      profile = create_profile(user, %{preset: "analyst"})
      {:ok, user} = Accounts.update_user(user, %{personality_id: profile.id})
      host = create_host()
      session = create_session(user, host)

      prompt = Personality.resolve_system_prompt(session)
      assert is_binary(prompt)
      assert String.downcase(prompt) =~ "reasoning"
    end

    test "uses project personality over user personality" do
      user = create_user()
      host = create_host()
      user_profile = create_profile(user, %{preset: "butler"})
      {:ok, user} = Accounts.update_user(user, %{personality_id: user_profile.id})

      {:ok, project} =
        Projects.create_project(%{
          user_id: user.id,
          name: "Pers Project #{System.unique_integer()}"
        })

      project_profile = create_profile(user, %{preset: "coach"})
      {:ok, _project} = Projects.update_project(project, %{personality_id: project_profile.id})

      session = create_session(user, host, %{project_id: project.id})

      prompt = Personality.resolve_system_prompt(session)
      assert is_binary(prompt)
      # Coach preset: step by step
      assert String.downcase(prompt) =~ "step"
    end

    test "session personality overrides project personality" do
      user = create_user()
      host = create_host()

      {:ok, project} =
        Projects.create_project(%{
          user_id: user.id,
          name: "Override Project #{System.unique_integer()}"
        })

      project_profile = create_profile(user, %{preset: "coach"})
      {:ok, _project} = Projects.update_project(project, %{personality_id: project_profile.id})

      session_profile = create_profile(user, %{preset: "silent"})

      session =
        create_session(user, host, %{
          project_id: project.id,
          personality_id: session_profile.id
        })

      prompt = Personality.resolve_system_prompt(session)
      assert String.downcase(prompt) =~ "no commentary"
    end

    test "profile with custom_prompt uses that prompt" do
      user = create_user()
      host = create_host()

      {:ok, profile} =
        Accounts.create_personality_profile(%{
          user_id: user.id,
          name: "custom",
          custom_prompt: "You are a custom butler bot."
        })

      session = create_session(user, host, %{personality_id: profile.id})
      prompt = Personality.resolve_system_prompt(session)
      assert prompt == "You are a custom butler bot."
    end
  end
end
