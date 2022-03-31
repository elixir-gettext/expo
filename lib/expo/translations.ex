defmodule Expo.Translations do
  @moduledoc """
  Translation List Struct for mo / po files
  """

  alias Expo.Translation

  @type t :: %__MODULE__{
          headers: [String.t()],
          top_comments: [[String.t()]],
          translations: [Translation.t()]
        }

  @enforce_keys [:translations]
  defstruct headers: [], translations: [], top_comments: []
end
