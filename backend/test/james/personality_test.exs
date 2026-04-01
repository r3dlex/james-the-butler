defmodule James.PersonalityTest do
  use ExUnit.Case, async: true

  alias James.Personality

  @preset_ids ~w[butler collaborator analyst coach editor silent]

  # ---------------------------------------------------------------------------
  # preset_ids/0
  # ---------------------------------------------------------------------------

  describe "preset_ids/0" do
    test "returns a list" do
      assert is_list(Personality.preset_ids())
    end

    test "returns exactly 6 preset identifiers" do
      assert length(Personality.preset_ids()) == 6
    end

    test "includes all expected preset identifiers" do
      ids = Personality.preset_ids()
      Enum.each(@preset_ids, fn id -> assert id in ids end)
    end
  end

  # ---------------------------------------------------------------------------
  # get_preset/1
  # ---------------------------------------------------------------------------

  describe "get_preset/1" do
    test "returns a map for each known preset id" do
      Enum.each(@preset_ids, fn id ->
        assert is_map(Personality.get_preset(id)), "expected map for preset #{id}"
      end)
    end

    test "each preset map has a :name key" do
      Enum.each(@preset_ids, fn id ->
        preset = Personality.get_preset(id)
        assert Map.has_key?(preset, :name), "preset #{id} missing :name"
      end)
    end

    test "each preset map has a :prompt key" do
      Enum.each(@preset_ids, fn id ->
        preset = Personality.get_preset(id)
        assert Map.has_key?(preset, :prompt), "preset #{id} missing :prompt"
      end)
    end

    test "each preset's prompt is a non-empty string" do
      Enum.each(@preset_ids, fn id ->
        %{prompt: prompt} = Personality.get_preset(id)
        assert is_binary(prompt) and String.length(prompt) > 0
      end)
    end

    test "butler preset has name 'Butler'" do
      assert Personality.get_preset("butler").name == "Butler"
    end

    test "collaborator preset has name 'Collaborator'" do
      assert Personality.get_preset("collaborator").name == "Collaborator"
    end

    test "analyst preset has name 'Analyst'" do
      assert Personality.get_preset("analyst").name == "Analyst"
    end

    test "coach preset has name 'Coach'" do
      assert Personality.get_preset("coach").name == "Coach"
    end

    test "editor preset has name 'Editor'" do
      assert Personality.get_preset("editor").name == "Editor"
    end

    test "silent preset has name 'Silent'" do
      assert Personality.get_preset("silent").name == "Silent"
    end

    test "butler prompt mentions 'James the Butler'" do
      assert Personality.get_preset("butler").prompt =~ "James the Butler"
    end

    test "silent preset prompt emphasises output only with no commentary" do
      prompt = Personality.get_preset("silent").prompt
      assert String.downcase(prompt) =~ "no commentary"
    end

    test "analyst preset prompt mentions reasoning" do
      prompt = Personality.get_preset("analyst").prompt
      assert String.downcase(prompt) =~ "reasoning"
    end

    test "returns nil for an unknown preset id" do
      assert Personality.get_preset("unknown_preset") == nil
    end

    test "returns nil for an empty string" do
      assert Personality.get_preset("") == nil
    end
  end

  # ---------------------------------------------------------------------------
  # list_presets/0
  # ---------------------------------------------------------------------------

  describe "list_presets/0" do
    test "returns a list" do
      assert is_list(Personality.list_presets())
    end

    test "returns 6 entries" do
      assert length(Personality.list_presets()) == 6
    end

    test "each entry is a map" do
      assert Enum.all?(Personality.list_presets(), &is_map/1)
    end

    test "each entry has :id, :name, and :prompt keys" do
      Enum.each(Personality.list_presets(), fn preset ->
        assert Map.has_key?(preset, :id)
        assert Map.has_key?(preset, :name)
        assert Map.has_key?(preset, :prompt)
      end)
    end

    test "all expected preset ids appear in the list" do
      ids = Personality.list_presets() |> Enum.map(& &1.id)
      Enum.each(@preset_ids, fn id -> assert id in ids end)
    end

    test "all prompts are non-empty strings" do
      Enum.each(Personality.list_presets(), fn %{prompt: p} ->
        assert is_binary(p) and String.length(p) > 0
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # presets/0 — alias for list_presets/0
  # ---------------------------------------------------------------------------

  describe "presets/0" do
    test "returns the same result as list_presets/0" do
      assert Personality.presets() == Personality.list_presets()
    end

    test "returns a list of 6 entries" do
      assert length(Personality.presets()) == 6
    end

    test "each entry has :id, :name, and :prompt" do
      Enum.each(Personality.presets(), fn preset ->
        assert Map.has_key?(preset, :id)
        assert Map.has_key?(preset, :name)
        assert Map.has_key?(preset, :prompt)
      end)
    end
  end
end
