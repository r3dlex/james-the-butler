defmodule JamesWeb.ErrorJSONTest do
  use JamesWeb.ConnCase

  alias JamesWeb.ErrorJSON

  describe "render/2" do
    test "renders 404.json with a details field" do
      assert %{errors: %{detail: _}} = ErrorJSON.render("404.json", %{})
    end

    test "renders 500.json with a details field" do
      assert %{errors: %{detail: _}} = ErrorJSON.render("500.json", %{})
    end
  end
end
