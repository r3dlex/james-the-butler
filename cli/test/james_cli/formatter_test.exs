defmodule JamesCli.FormatterTest do
  use ExUnit.Case, async: true

  alias JamesCli.Formatter

  describe "format/2 with :json format" do
    test "returns pretty-printed JSON string" do
      data = %{"key" => "value", "count" => 42}
      result = Formatter.format(data, :json)
      assert is_binary(result)
      parsed = Jason.decode!(result)
      assert parsed["key"] == "value"
      assert parsed["count"] == 42
    end

    test "handles lists" do
      data = [1, 2, 3]
      result = Formatter.format(data, :json)
      assert Jason.decode!(result) == [1, 2, 3]
    end
  end

  describe "format/2 with :stream_json format" do
    test "returns newline-delimited JSON for a list" do
      data = [%{"id" => 1}, %{"id" => 2}]
      result = Formatter.format(data, :stream_json)
      lines = String.split(String.trim(result), "\n")
      assert length(lines) == 2
      assert Jason.decode!(Enum.at(lines, 0)) == %{"id" => 1}
      assert Jason.decode!(Enum.at(lines, 1)) == %{"id" => 2}
    end

    test "returns single JSON line for a non-list" do
      data = %{"status" => "ok"}
      result = Formatter.format(data, :stream_json)
      lines = String.split(String.trim(result), "\n")
      assert length(lines) == 1
      assert Jason.decode!(Enum.at(lines, 0)) == %{"status" => "ok"}
    end
  end

  describe "format/2 with :text format" do
    test "returns human-readable string for a map" do
      data = %{"name" => "alice", "status" => "active"}
      result = Formatter.format(data, :text)
      assert is_binary(result)
      assert result =~ "alice"
    end

    test "returns the string as-is for a binary" do
      assert Formatter.format("hello", :text) == "hello"
    end
  end
end
