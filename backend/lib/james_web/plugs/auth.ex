defmodule JamesWeb.Plugs.Auth do
  @moduledoc """
  Verifies Bearer JWT token and assigns current_user to the conn.
  """

  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias James.Accounts
  alias James.Auth

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, token} <- extract_token(conn),
         {:ok, claims} <- Auth.verify_token(token),
         user_id = claims["sub"],
         user when not is_nil(user) <- Accounts.get_user(user_id) do
      assign(conn, :current_user, user)
    else
      {:error, _reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "unauthorized"})
        |> halt()

      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "user not found"})
        |> halt()
    end
  end

  defp extract_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      _ -> {:error, :missing_token}
    end
  end
end
