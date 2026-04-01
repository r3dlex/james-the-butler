defmodule JamesCli.MixProject do
  use Mix.Project

  def project do
    [
      app: :james_cli,
      version: "0.1.0",
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      escript: escript(),
      deps: deps(),
      aliases: aliases(),
      test_coverage: [tool: ExCoveralls, summary: [threshold: 85]],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  defp escript do
    [
      main_module: JamesCli.Main,
      name: "james"
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:toml, "~> 0.7"},
      {:jason, "~> 1.4"},
      {:req, "~> 0.5"},
      {:excoveralls, "~> 0.18", only: :test},
      {:mox, "~> 1.1", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      test: ["test --no-start"]
    ]
  end
end
