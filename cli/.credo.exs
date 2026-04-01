%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/"],
        excluded: []
      },
      strict: true,
      color: true,
      checks: %{
        disabled: [
          # Allow piping into anonymous functions (used in formatter)
          {Credo.Check.Refactor.PipeChainStart, []}
        ]
      }
    }
  ]
}
