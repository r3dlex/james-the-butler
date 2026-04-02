defmodule JamesWeb.PathControllerTest do
  use JamesWeb.ConnCase

  alias James.Accounts

  defp create_user do
    {:ok, user} =
      Accounts.create_user(%{email: "path_ctrl_#{System.unique_integer()}@example.com"})

    user
  end

  describe "GET /api/paths/git-check" do
    test "returns is_git: true for a directory with .git folder", %{conn: conn} do
      user = create_user()
      # Create a temp dir with a .git subfolder to simulate a git repo
      path = Path.join(System.tmp_dir!(), "james-git-test-#{System.unique_integer()}")
      File.mkdir_p!(Path.join(path, ".git"))

      conn = authed_conn(conn, user)
      conn = get(conn, "/api/paths/git-check?path=#{URI.encode(path)}")

      assert json_response(conn, 200)["is_git"] == true
      assert json_response(conn, 200)["path"] == path

      File.rm_rf!(path)
    end

    test "returns is_git: false for a directory without .git folder", %{conn: conn} do
      user = create_user()
      path = System.tmp_dir!()

      conn = authed_conn(conn, user)
      conn = get(conn, "/api/paths/git-check?path=#{URI.encode(path)}")

      assert json_response(conn, 200)["is_git"] == false
      assert json_response(conn, 200)["path"] == path
    end

    test "returns is_git: false for a non-existent path", %{conn: conn} do
      user = create_user()
      path = "/tmp/does-not-exist-james-test-#{System.unique_integer()}"

      conn = authed_conn(conn, user)
      conn = get(conn, "/api/paths/git-check?path=#{URI.encode(path)}")

      assert json_response(conn, 200)["is_git"] == false
    end

    test "returns 400 when path parameter is missing", %{conn: conn} do
      user = create_user()
      conn = authed_conn(conn, user)
      conn = get(conn, "/api/paths/git-check")
      assert json_response(conn, 400)["error"] == "path parameter required"
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, "/api/paths/git-check?path=/tmp")
      assert conn.status == 401
    end
  end
end
