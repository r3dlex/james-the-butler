FROM elixir:1.16-otp-26-alpine

RUN apk add --no-cache build-base git postgresql-client

WORKDIR /app

ENV MIX_ENV=dev

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs ./
RUN mix deps.get && mix deps.compile

COPY config config
COPY lib lib
COPY priv priv

RUN mix compile

EXPOSE 4000

CMD ["sh", "-c", "mix ecto.create && mix ecto.migrate && mix phx.server"]
