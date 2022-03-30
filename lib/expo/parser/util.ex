defmodule Expo.Parser.Util do
  @moduledoc false

  alias Expo.Translation
  alias Expo.Translations

  @spec extract_meta_headers(translations :: [Translation.t()]) ::
          {[Translations.header()], [Translation.t()]}
  def extract_meta_headers(translations) do
    case Enum.chunk_by(translations, &match?(%{msgid: ""}, &1)) do
      [meta_translations, translations] ->
        {Enum.flat_map(meta_translations, &parse_meta_headers(&1.msgstr)), translations}

      [translations] ->
        {[], translations}

      [] ->
        {[], []}
    end
  end

  defp parse_meta_headers(headers),
    do: headers |> String.split("\n", trim: true) |> Enum.map(&parse_meta_header/1)

  defp parse_meta_header(header),
    do: header |> String.split(":", parts: 2, trim: true) |> Enum.map(&String.trim/1)
end
