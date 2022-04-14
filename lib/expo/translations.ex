defmodule Expo.Translations do
  @moduledoc """
  Translation List Struct for mo / po files
  """

  alias Expo.Translation
  alias Expo.Util

  @type t :: %__MODULE__{
          headers: [String.t()],
          top_comments: [[String.t()]],
          translations: [Translation.t()],
          file: nil | Path.t()
        }

  @enforce_keys [:translations]
  defstruct headers: [], translations: [], top_comments: [], file: nil

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

  @doc """
  Get Header by name (case insensitive)

  ### Examples

      iex> translations = %Expo.Translations{headers: ["Language: en_US\\n"], translations: []}
      iex> Expo.Translations.get_header(translations, "language")
      ["en_US"]

      iex> translations = %Expo.Translations{headers: ["Language: en_US\\n"], translations: []}
      iex> Expo.Translations.get_header(translations, "invalid")
      []

  """
  @spec get_header(translations :: t(), header_name :: String.t()) :: [String.t()]
  def get_header(%__MODULE__{headers: headers}, header_name) do
    header_name_match = Regex.escape(header_name)
    escaped_newline = Regex.escape("\\\n")

    ~r/
      # Start of line
      ^
      # Header Name
      (?<header>
        #{header_name_match}
      ):
      # Ignore Whitespace
      \s
      (?<content>
        (
          # Allow an escaped newline in content
          #{escaped_newline}
          |
          # Allow everything except a newline in content
          [^\n]
        )*
      )
      # Header must end with newline or end of string
      (\n|\z)
    /imx
    |> Regex.scan(IO.iodata_to_binary(headers), capture: ["content"])
    |> Enum.map(fn [content] -> content end)
  end

  @doc """
  Finds a given translation in a list of translations.

  Equality between translations is checked using `Expo.Translation.same?/2`.
  """
  def find(translations, search_translation)

  @spec find(translations :: [Translation.t()], search_translation :: Translation.t()) ::
          Translation.t() | nil
  def find(translations, search_translation) when is_list(translations),
    do: Enum.find(translations, &Translation.same?(&1, search_translation))

  @spec find(translations :: t(), search_translation :: Translation.t()) ::
          Translation.t() | nil
  def find(%__MODULE__{translations: translations}, search_translation),
    do: find(translations, search_translation)
end
