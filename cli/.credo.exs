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
          {Credo.Check.Refactor.PipeChainStart, []},
          # TUI socket handler inherently uses dynamic callbacks
          {Credo.Check.DesignAvoidSpec, []},
          {Credo.Check.Refactor.Nesting, []},
          {Credo.Check.Refactor.CyclomaticComplexity, []}
        ]
      }
    }
  ]
}
