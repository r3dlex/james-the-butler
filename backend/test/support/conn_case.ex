defmodule JamesWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by tests that require setting up
  a connection. It provides helpers for building authenticated connections.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest

      import James.DataCase, only: [errors_on: 1]

      @endpoint JamesWeb.Endpoint

      def authed_conn(conn, user) do
        {:ok, token} = James.Auth.generate_token(user)
        put_req_header(conn, "authorization", "Bearer #{token}")
      end
    end
  end

  setup tags do
    James.DataCase.setup_sandbox(tags)

    conn =
      Phoenix.ConnTest.build_conn()
      |> Plug.Conn.put_req_header("content-type", "application/json")

    {:ok, conn: conn}
  end
end
