defmodule James.Providers.GeminiTest do
  use ExUnit.Case, async: false

  alias James.Providers.Gemini

  setup do
    original_key = Application.get_env(:james, :google_api_key)
    original_env = System.get_env("GOOGLE_API_KEY")
    original_url = System.get_env("GEMINI_API_URL")

    Application.delete_env(:james, :google_api_key)
    System.delete_env("GOOGLE_API_KEY")

    on_exit(fn ->
      case original_key do
        nil -> Application.delete_env(:james, :google_api_key)
        v -> Application.put_env(:james, :google_api_key, v)
      end

      case original_env do
        nil -> System.delete_env("GOOGLE_API_KEY")
        v -> System.put_env("GOOGLE_API_KEY", v)
      end

      case original_url do
        nil -> System.delete_env("GEMINI_API_URL")
        v -> System.put_env("GEMINI_API_URL", v)
      end
    end)

    :ok
  end

  describe "send_message/2 — no API key" do
    test "returns error when GOOGLE_API_KEY is not configured" do
      assert {:error, reason} = Gemini.send_message([%{role: "user", content: "hi"}])
      assert reason =~ "not configured"
    end
  end

  describe "stream_message/2 — no API key" do
    test "returns error when GOOGLE_API_KEY is not configured" do
      assert {:error, reason} = Gemini.stream_message([%{role: "user", content: "hi"}])
      assert reason =~ "not configured"
    end

    test "returns error tuple for empty messages list when no key is set" do
      assert {:error, _} = Gemini.stream_message([])
    end
  end

  describe "send_message/2 — with Bypass" do
    setup do
      bypass = Bypass.open()
      System.put_env("GEMINI_API_URL", "http://localhost:#{bypass.port}")
      System.put_env("GOOGLE_API_KEY", "test-google-key")
      {:ok, bypass: bypass}
    end

    test "sends POST to generateContent endpoint and returns content", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/v1beta/models/gemini-2.0-flash:generateContent",
        fn conn ->
          resp =
            Jason.encode!(%{
              "candidates" => [
                %{
                  "content" => %{
                    "parts" => [%{"text" => "Gemini says hello"}],
                    "role" => "model"
                  },
                  "finishReason" => "STOP"
                }
              ],
              "usageMetadata" => %{
                "promptTokenCount" => 10,
                "candidatesTokenCount" => 5
              }
            })

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, resp)
        end
      )

      messages = [%{role: "user", content: "hi"}]

      assert {:ok, %{content: "Gemini says hello", usage: usage}} =
               Gemini.send_message(messages)

      assert usage.input_tokens == 10
      assert usage.output_tokens == 5
    end

    test "passes API key as query param", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/v1beta/models/gemini-2.0-flash:generateContent",
        fn conn ->
          query = URI.decode_query(conn.query_string)
          assert query["key"] == "test-google-key"

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(
            200,
            Jason.encode!(%{
              "candidates" => [
                %{
                  "content" => %{"parts" => [%{"text" => "ok"}], "role" => "model"},
                  "finishReason" => "STOP"
                }
              ],
              "usageMetadata" => %{"promptTokenCount" => 1, "candidatesTokenCount" => 1}
            })
          )
        end
      )

      Gemini.send_message([%{role: "user", content: "hi"}])
    end

    test "converts standard messages to Gemini contents format", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/v1beta/models/gemini-2.0-flash:generateContent",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          decoded = Jason.decode!(body)
          contents = decoded["contents"]
          assert length(contents) == 1
          [msg] = contents
          assert msg["role"] == "user"
          assert [%{"text" => "hello"}] = msg["parts"]

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(
            200,
            Jason.encode!(%{
              "candidates" => [
                %{
                  "content" => %{"parts" => [%{"text" => "sure"}], "role" => "model"},
                  "finishReason" => "STOP"
                }
              ],
              "usageMetadata" => %{"promptTokenCount" => 2, "candidatesTokenCount" => 1}
            })
          )
        end
      )

      Gemini.send_message([%{role: "user", content: "hello"}])
    end

    test "sends system_instruction when :system opt is provided", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/v1beta/models/gemini-2.0-flash:generateContent",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          decoded = Jason.decode!(body)
          assert %{"parts" => [%{"text" => sys_text}]} = decoded["system_instruction"]
          assert sys_text =~ "be helpful"

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(
            200,
            Jason.encode!(%{
              "candidates" => [
                %{
                  "content" => %{"parts" => [%{"text" => "ok"}], "role" => "model"},
                  "finishReason" => "STOP"
                }
              ],
              "usageMetadata" => %{"promptTokenCount" => 3, "candidatesTokenCount" => 1}
            })
          )
        end
      )

      Gemini.send_message([%{role: "user", content: "hi"}], system: "be helpful")
    end

    test "returns error on 4xx response", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/v1beta/models/gemini-2.0-flash:generateContent",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(
            400,
            Jason.encode!(%{"error" => %{"message" => "Bad Request", "code" => 400}})
          )
        end
      )

      assert {:error, reason} = Gemini.send_message([%{role: "user", content: "hi"}])
      assert reason =~ "400"
    end

    test "returns empty content when candidates list is empty", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "POST",
        "/v1beta/models/gemini-2.0-flash:generateContent",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(
            200,
            Jason.encode!(%{
              "candidates" => [],
              "usageMetadata" => %{"promptTokenCount" => 1, "candidatesTokenCount" => 0}
            })
          )
        end
      )

      assert {:ok, %{content: ""}} = Gemini.send_message([%{role: "user", content: "hi"}])
    end
  end
end
