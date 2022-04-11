tags = if Version.match?(System.version(), "~> 1.10"), do: [], else: [:"disable_elixir_lt_1.10"]

ExUnit.start(exclude: tags)
