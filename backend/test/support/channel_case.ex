defmodule JamesWeb.ChannelCase do
  @moduledoc """
  Test case for Phoenix channel tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest

      @endpoint JamesWeb.Endpoint

      def connect_socket(user) do
        {:ok, token} = James.Auth.generate_token(user)

        {:ok, socket} =
          Phoenix.ChannelTest.connect(JamesWeb.UserSocket, %{"token" => token})

        socket
      end
    end
  end

  setup tags do
    James.DataCase.setup_sandbox(tags)
    :ok
  end
end
