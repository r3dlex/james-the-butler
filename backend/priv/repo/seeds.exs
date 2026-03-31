# Seed data for James the Butler
# Run with: mix run priv/repo/seeds.exs

alias James.Repo
alias James.Hosts.Host

# Ensure a primary host record exists
case Repo.get_by(Host, is_primary: true) do
  nil ->
    %Host{}
    |> Ecto.Changeset.cast(
      %{
        name: "Primary Host",
        endpoint: "http://localhost:4000",
        status: "online",
        is_primary: true
      },
      [:name, :endpoint, :status, :is_primary]
    )
    |> Repo.insert!()

    IO.puts("Created primary host record.")

  host ->
    IO.puts("Primary host already exists: #{host.name}")
end
