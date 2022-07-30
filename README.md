# Expo

[![.github/workflows/branch_main.yml](https://github.com/elixir-gettext/expo/actions/workflows/branch_main.yml/badge.svg)](https://github.com/elixir-gettext/expo/actions/workflows/branch_main.yml)
[![Coverage Status](https://coveralls.io/repos/github/elixir-gettext/expo/badge.svg?branch=main)](https://coveralls.io/github/elixir-gettext/expo?branch=main)
[![Module Version](https://img.shields.io/hexpm/v/expo.svg)](https://hex.pm/packages/expo)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)][docs]
[![License](https://img.shields.io/hexpm/l/expo.svg)](https://github.com/elixir-gettext/expo/blob/master/LICENSE)

Low-level [GNU gettext][gettext] file handling (for `.po`, `.pot`, and `.mo`
files), including writing and parsing.

See [the documentation][docs].

For a full Gettext integration, see the [Gettext library][elixir-gettext].

## Installation

The package can be installed by adding `expo` to your list of
dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:expo, "~> 0.1.0"}
  ]
end
```

[docs]: https://hexdocs.pm/expo
[elixir-gettext]: https://github.com/elixir-gettext/gettext
[gettext]: https://www.gnu.org/software/gettext/
