defmodule James.Desktop.ProtocolTest do
  use ExUnit.Case, async: true

  alias James.Desktop.Protocol

  # ---------------------------------------------------------------------------
  # encode/2
  # ---------------------------------------------------------------------------

  describe "encode/2" do
    test "screenshot produces JSON with action: screenshot" do
      json = Protocol.encode(:screenshot, %{})
      assert {:ok, map} = Jason.decode(json)
      assert map["action"] == "screenshot"
    end

    test "click produces correct JSON with x and y" do
      json = Protocol.encode(:click, %{x: 100, y: 200})
      assert {:ok, map} = Jason.decode(json)
      assert map["action"] == "click"
      assert map["x"] == 100
      assert map["y"] == 200
    end

    test "type_text produces correct JSON with text" do
      json = Protocol.encode(:type_text, %{text: "hello"})
      assert {:ok, map} = Jason.decode(json)
      assert map["action"] == "type_text"
      assert map["text"] == "hello"
    end

    test "key_press produces correct JSON with key" do
      json = Protocol.encode(:key_press, %{key: "enter"})
      assert {:ok, map} = Jason.decode(json)
      assert map["action"] == "key_press"
      assert map["key"] == "enter"
    end

    test "scroll produces correct JSON with direction and amount" do
      json = Protocol.encode(:scroll, %{direction: "down", amount: 3})
      assert {:ok, map} = Jason.decode(json)
      assert map["action"] == "scroll"
      assert map["direction"] == "down"
      assert map["amount"] == 3
    end

    test "drag produces correct JSON with from/to coordinates" do
      json = Protocol.encode(:drag, %{from_x: 10, from_y: 20, to_x: 100, to_y: 200})
      assert {:ok, map} = Jason.decode(json)
      assert map["action"] == "drag"
      assert map["from_x"] == 10
      assert map["to_y"] == 200
    end

    test "encode/1 with just action and no params works" do
      json = Protocol.encode(:screenshot)
      assert {:ok, map} = Jason.decode(json)
      assert map["action"] == "screenshot"
    end
  end

  # ---------------------------------------------------------------------------
  # decode/1
  # ---------------------------------------------------------------------------

  describe "decode/1" do
    test "parses success response with data" do
      json = Jason.encode!(%{"status" => "ok", "data" => %{"width" => 1920, "height" => 1080}})
      assert {:ok, data} = Protocol.decode(json)
      assert data["width"] == 1920
      assert data["height"] == 1080
    end

    test "parses error response" do
      json = Jason.encode!(%{"status" => "error", "reason" => "permission denied"})
      assert {:error, "permission denied"} = Protocol.decode(json)
    end

    test "returns {:error, {:json_decode, _}} for invalid JSON" do
      assert {:error, {:json_decode, _}} = Protocol.decode("not json }{")
    end

    test "returns {:error, {:unexpected_response, _}} for unknown shape" do
      json = Jason.encode!(%{"foo" => "bar"})
      assert {:error, {:unexpected_response, _}} = Protocol.decode(json)
    end
  end

  # ---------------------------------------------------------------------------
  # Round-trip tests
  # ---------------------------------------------------------------------------

  describe "round-trip encode → decode" do
    # Simulate a daemon that echoes back {"status":"ok","data":{...original...}}
    defp simulate_daemon_response(json) do
      {:ok, payload} = Jason.decode(json)
      Jason.encode!(%{"status" => "ok", "data" => payload})
    end

    for action <- [:screenshot, :click, :type_text, :key_press, :scroll, :drag] do
      @action action
      test "round-trip for #{action}" do
        params = sample_params(@action)
        encoded = Protocol.encode(@action, params)
        response = simulate_daemon_response(encoded)
        assert {:ok, data} = Protocol.decode(response)
        assert data["action"] == Atom.to_string(@action)
      end
    end

    defp sample_params(:screenshot), do: %{}
    defp sample_params(:click), do: %{x: 50, y: 60}
    defp sample_params(:type_text), do: %{text: "world"}
    defp sample_params(:key_press), do: %{key: "escape"}
    defp sample_params(:scroll), do: %{direction: "up", amount: 2}
    defp sample_params(:drag), do: %{from_x: 0, from_y: 0, to_x: 50, to_y: 50}
  end
end
