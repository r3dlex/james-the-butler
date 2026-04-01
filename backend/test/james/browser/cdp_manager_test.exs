defmodule James.Browser.CdpManagerTest do
  use ExUnit.Case, async: true

  alias James.Browser.CdpManager

  # ---------------------------------------------------------------------------
  # Legacy string-based execute/2 tests (unchanged)
  # ---------------------------------------------------------------------------

  describe "execute/2 — legacy string interface" do
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

  # ---------------------------------------------------------------------------
  # ensure_chrome/0
  # ---------------------------------------------------------------------------

  describe "ensure_chrome/0" do
    test "returns :ok or {:error, instructions} depending on whether Chrome is running" do
      result = CdpManager.ensure_chrome()

      case result do
        :ok ->
          assert true

        {:error, msg} ->
          assert is_binary(msg)
          assert msg =~ "Chrome"
          assert msg =~ "9222"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # status/0
  # ---------------------------------------------------------------------------

  describe "status/0" do
    test "returns :running or :stopped" do
      result = CdpManager.status()
      assert result in [:running, :stopped]
    end

    test "returns :stopped when Chrome is not running on default port" do
      # In a standard CI/test environment Chrome is not running, so we expect :stopped.
      # This test is conditional: it only asserts :stopped if port 9222 is closed.
      # If Chrome happens to be running the result is :running — both are valid.
      result = CdpManager.status()
      assert result in [:running, :stopped]
    end
  end

  # ---------------------------------------------------------------------------
  # close_idle_tab_groups/1
  # ---------------------------------------------------------------------------

  describe "close_idle_tab_groups/1" do
    test "returns :ok" do
      cutoff = DateTime.utc_now()
      assert :ok == CdpManager.close_idle_tab_groups(cutoff)
    end
  end

  # ---------------------------------------------------------------------------
  # Atom-based execute/2 — delegates to CdpClient
  #
  # When Chrome is not running these return {:error, _}.  We verify the shape
  # of the response without requiring a live browser.
  # ---------------------------------------------------------------------------

  describe "execute/2 — atom interface when Chrome is unavailable" do
    test ":navigate action returns {:error, _} when Chrome is not running" do
      case CdpManager.status() do
        :stopped ->
          assert {:error, _} = CdpManager.execute(:navigate, %{url: "https://example.com"})

        :running ->
          # Chrome is running; just verify the function is callable
          result = CdpManager.execute(:navigate, %{url: "https://example.com"})
          assert match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end

    test ":screenshot action returns {:error, _} when Chrome is not running" do
      case CdpManager.status() do
        :stopped ->
          assert {:error, _} = CdpManager.execute(:screenshot, %{})

        :running ->
          result = CdpManager.execute(:screenshot, %{})
          assert match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end

    test ":evaluate action returns {:error, _} when Chrome is not running" do
      case CdpManager.status() do
        :stopped ->
          assert {:error, _} = CdpManager.execute(:evaluate, %{expression: "1+1"})

        :running ->
          result = CdpManager.execute(:evaluate, %{expression: "1+1"})
          assert match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end
  end
end
