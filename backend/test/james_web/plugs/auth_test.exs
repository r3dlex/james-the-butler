defmodule JamesWeb.Plugs.AuthTest do
  use JamesWeb.ConnCase

  alias James.{Accounts, Auth}
  alias JamesWeb.Plugs.Auth, as: AuthPlug

  describe "call/2 — user not found" do
    test "returns 401 when token is valid but user no longer exists", %{conn: conn} do
      # Generate a token for a user_id that doesn't exist in the DB
      fake_user = %{id: Ecto.UUID.generate()}
      {:ok, token} = Auth.generate_token(fake_user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> AuthPlug.call([])

      assert conn.halted
      assert conn.status == 401
      body = json_response(conn, 401)
      assert body["error"] == "user not found"
    end
  end

  describe "call/2 — invalid token format" do
    test "returns 401 when authorization header is missing", %{conn: conn} do
      conn = AuthPlug.call(conn, [])
      assert conn.halted
      assert conn.status == 401
    end

    test "returns 401 when token is malformed", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer not.a.valid.jwt")
        |> AuthPlug.call([])

      assert conn.halted
      assert conn.status == 401
    end

    test "returns 401 when authorization header uses wrong scheme", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Basic dXNlcjpwYXNz")
        |> AuthPlug.call([])

      assert conn.halted
      assert conn.status == 401
    end
  end
end
