defmodule Expo.Parser do
  @moduledoc """
  Parser Behaviour
  """

  alias Expo.Translations

  @callback parse(content :: binary()) :: {:ok, Translations.t()} | {:error, term}
end
