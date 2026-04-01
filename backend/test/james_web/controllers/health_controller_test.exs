defmodule JamesWeb.HealthControllerTest do
  use JamesWeb.ConnCase

  describe "GET /health" do
    test "returns 200 with ok status", %{conn: conn} do
      conn = get(conn, "/health")
      assert json_response(conn, 200)["status"] == "ok"
    end

    test "does not require authentication", %{conn: conn} do
      conn = get(conn, "/health")
      assert conn.status == 200
    end
  end
end
