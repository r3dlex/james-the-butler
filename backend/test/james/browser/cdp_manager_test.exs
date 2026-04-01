defmodule James.Browser.CdpManagerTest do
  use ExUnit.Case, async: true

  alias James.Browser.CdpManager

  describe "ensure_chrome/0" do
    test "returns :ok or {:error, ...} depending on whether chrome is installed" do
      result = CdpManager.ensure_chrome()
      assert result == :ok or match?({:error, _}, result)
    end
  end

  describe "execute/2" do
    test "navigate returns navigated message" do
      result = CdpManager.execute("navigate", %{"url" => "https://example.com"})
      assert result =~ "Navigated to"
      assert result =~ "example.com"
    end

    test "navigate with no params uses empty url" do
      result = CdpManager.execute("navigate", %{})
      assert result =~ "Navigated to"
    end

    test "click_element returns clicked message" do
      result = CdpManager.execute("click_element", %{"selector" => "#submit"})
      assert result =~ "Clicked element"
      assert result =~ "#submit"
    end

    test "fill_form returns filled message" do
      result = CdpManager.execute("fill_form", %{"selector" => "input[name=q]"})
      assert result =~ "Filled form field"
    end

    test "get_page_content returns content placeholder" do
      result = CdpManager.execute("get_page_content")
      assert result =~ "Page content"
    end

    test "run_javascript returns execution placeholder" do
      result = CdpManager.execute("run_javascript", %{"script" => "alert(1)"})
      assert result =~ "JavaScript execution"
    end

    test "screenshot_page returns screenshot placeholder" do
      result = CdpManager.execute("screenshot_page")
      assert result =~ "Screenshot"
    end

    test "unknown action returns unknown message" do
      result = CdpManager.execute("frobnicate")
      assert result =~ "Unknown browser action"
      assert result =~ "frobnicate"
    end

    test "works with default empty params" do
      result = CdpManager.execute("navigate")
      assert is_binary(result)
    end
  end

  describe "close_idle_tab_groups/1" do
    test "returns :ok" do
      cutoff = DateTime.utc_now()
      assert :ok == CdpManager.close_idle_tab_groups(cutoff)
    end
  end
end
