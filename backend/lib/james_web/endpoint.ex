defmodule JamesWeb.Endpoint do
  @moduledoc false

  use Phoenix.Endpoint, otp_app: :james

  socket "/socket", JamesWeb.UserSocket,
    websocket: [timeout: 45_000],
    longpoll: false

  plug CORSPlug,
    origin: [
      "http://localhost:4173",
      "http://localhost:5173",
      "tauri://localhost",
      ~r/chrome-extension:\/\/.*/
    ],
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    headers: ["Authorization", "Content-Type", "Accept"]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason

  plug JamesWeb.Router
end
