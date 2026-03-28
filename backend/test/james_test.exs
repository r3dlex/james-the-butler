defmodule JamesTest do
  use ExUnit.Case

  test "james module exists" do
    assert is_list(James.module_info())
  end
end
