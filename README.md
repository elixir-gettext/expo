# Expo

[![hex.pm badge](https://img.shields.io/badge/Package%20on%20hex.pm-informational)](https://hex.pm/packages/expo)
[![Documentation badge](https://img.shields.io/badge/Documentation-ff69b4)][docs]
[![.github/workflows/branch_main.yml](https://github.com/elixir-gettext/expo/actions/workflows/branch_main.yml/badge.svg)](https://github.com/elixir-gettext/expo/actions/workflows/branch_main.yml)
[![Coverage Status](https://coveralls.io/repos/github/elixir-gettext/expo/badge.svg?branch=main)](https://coveralls.io/github/elixir-gettext/expo?branch=main)

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

## License

Copyright 2022 JOSHMARTIN GmbH

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at:

  > <http://www.apache.org/licenses/LICENSE-2.0>

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

[docs]: https://hexdocs.pm/expo
[elixir-gettext]: https://github.com/elixir-gettext/gettext
[gettext]: https://www.gnu.org/software/gettext/
