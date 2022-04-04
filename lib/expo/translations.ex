defmodule Expo.Translations do
  @moduledoc """
  Translation List Struct for mo / po files
  """

  alias Expo.Parser.Util
  alias Expo.Translation

  @type t :: %__MODULE__{
          headers: [String.t()],
          top_comments: [[String.t()]],
          translations: [Translation.t()]
        }

  @enforce_keys [:translations]
  defstruct headers: [], translations: [], top_comments: []

  @doc """
  Rebalances all strings

  * All headers (see `Expo.Translation.Singular.rebalance/1` / `Expo.Translation.Plural.rebalance/1`)
  * Put one string per newline of `headers` and add one empty line at start

  ### Examples

      iex> Expo.Translations.rebalance(%Expo.Translations{
      ...>   headers: ["", "hello", "\\n", "", "world", ""],
      ...>   translations: [%Expo.Translation.Singular{
      ...>     msgid: ["", "hello", "\\n", "", "world", ""],
      ...>     msgstr: ["", "hello", "\\n", "", "world", ""]
      ...>   }]
      ...> })
      %Expo.Translations{
        headers: ["", "hello\\n", "world"],
        translations: [%Expo.Translation.Singular{
          msgid: ["hello\\n", "world"],
          msgstr: ["hello\\n", "world"]
        }]
      }

  """
  @spec rebalance(translation :: t()) :: t()
  def rebalance(
        %__MODULE__{headers: headers, translations: all_translations, top_comments: top_comments} =
          translations
      ) do
    {headers, top_comments, all_translations} =
      headers
      |> Util.inject_meta_headers(top_comments, all_translations)
      |> Enum.map(fn %struct{} = translation -> struct.rebalance(translation) end)
      |> Util.extract_meta_headers()

    headers =
      case headers do
        [] -> []
        headers -> ["" | headers]
      end

    %__MODULE__{
      translations
      | headers: headers,
        top_comments: top_comments,
        translations: all_translations
    }
  end
end
