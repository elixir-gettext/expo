# credo:disable-for-this-file Credo.Check.Readability.Specs
defmodule Expo.MixProject do
  @moduledoc false

  use Mix.Project

  @version "0.1.0-beta.2"
  @source_url "https://github.com/elixir-gettext/expo"

  def project do
    [
      app: :expo,
      version: @version,
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      description: description(),
      dialyzer:
        [list_unused_filters: true, plt_add_apps: [:mix]] ++
          if (System.get_env("DIALYZER_PLT_PRIV") || "false") in ["1", "true"] do
            [plt_file: {:no_warn, "priv/plts/dialyzer.plt"}]
          else
            []
          end,
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        "coveralls.json": :test,
        "coveralls.post": :test,
        "coveralls.xml": :test
      ],
      package: package()
    ]
  end

  defp package do
    %{
      licenses: ["Apache-2.0"],
      maintainers: ["Jonatan Männchen"],
      links: %{"GitHub" => @source_url}
    }
  end

  defp description do
    """
    Low Level Gettext (.po / .pot / .mo file writer / parser).
    """
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp docs do
    [
      source_url: @source_url,
      source_ref: "v" <> @version
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_parsec, "~> 1.2", runtime: false},
      {:ex_doc, ">= 0.0.0", only: [:dev], runtime: false},
      {:excoveralls, "~> 0.5", only: [:test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:credo, "~> 1.0", only: [:dev], runtime: false}
    ]
  end
end
