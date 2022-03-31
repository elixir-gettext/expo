defmodule Expo.Parser.Util do
  @moduledoc false

  alias Expo.Translation

  @spec extract_meta_headers(translations :: [Translation.t()]) ::
          {[String.t()], [[String.t()]], [Translation.t()]}
  def extract_meta_headers(translations)

  def extract_meta_headers([
        %Translation.Singular{msgid: [""], msgstr: msgstr, comments: comments} | translations
      ]),
      do: {parse_meta_headers(msgstr), comments, translations}

  def extract_meta_headers(translations), do: {[], [], translations}

  defp parse_meta_headers(headers),
    do: headers |> Enum.join("") |> String.split("\n", trim: true) |> Enum.map(&"#{&1}\n")
end
