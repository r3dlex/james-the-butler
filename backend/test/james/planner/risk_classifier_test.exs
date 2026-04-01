defmodule James.Planner.RiskClassifierTest do
  use ExUnit.Case, async: true

  alias James.Planner.RiskClassifier

  describe "classify/1" do
    test "read operation returns read_only" do
      assert RiskClassifier.classify("read the contents of config.json") == "read_only"
    end

    test "create operation returns additive" do
      assert RiskClassifier.classify("create a new document about elixir") == "additive"
    end

    test "delete operation returns destructive" do
      assert RiskClassifier.classify("delete all temporary files") == "destructive"
    end

    test "update database schema returns destructive" do
      assert RiskClassifier.classify("update the database schema") == "destructive"
    end

    test "list operation returns read_only" do
      assert RiskClassifier.classify("list all running processes") == "read_only"
    end

    test "send email returns destructive (irreversible)" do
      assert RiskClassifier.classify("send an email to the team") == "destructive"
    end

    test "unknown or ambiguous description defaults to additive" do
      assert RiskClassifier.classify("do something with the files") == "additive"
    end

    test "get operation returns read_only" do
      assert RiskClassifier.classify("get the current system status") == "read_only"
    end

    test "search operation returns read_only" do
      assert RiskClassifier.classify("search for documents matching the query") == "read_only"
    end

    test "write operation returns additive" do
      assert RiskClassifier.classify("write a summary report") == "additive"
    end

    test "remove operation returns destructive" do
      assert RiskClassifier.classify("remove the old configuration files") == "destructive"
    end

    test "generate operation returns additive" do
      assert RiskClassifier.classify("generate a new API key") == "additive"
    end

    test "destructive verbs take priority over read-only verbs" do
      assert RiskClassifier.classify("get and then delete the file") == "destructive"
    end

    test "case insensitive matching" do
      assert RiskClassifier.classify("DELETE all logs") == "destructive"
      assert RiskClassifier.classify("LIST all users") == "read_only"
      assert RiskClassifier.classify("CREATE a project") == "additive"
    end
  end
end
