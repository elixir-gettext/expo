defmodule Expo.Translation do
  @moduledoc """
  Translation Structs
  """

  alias Expo.Translation.Plural
  alias Expo.Translation.Singular

  @type msgid :: [String.t()]
  @type msgstr :: [String.t()]
  @type msgctxt :: String.t()

  @type t :: Singular.t() | Plural.t()
end
