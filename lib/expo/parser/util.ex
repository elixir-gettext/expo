defmodule Expo.Parser.Util do
  @moduledoc false

  alias Expo.Translation

  @spec extract_meta_headers(translations :: [Translation.t()]) ::
          {[String.t()], [[String.t()]], [Translation.t()]}
  def extract_meta_headers(translations)

  def extract_meta_headers([
        %Translation.Singular{msgid: [""], msgstr: msgstr, comments: comments} | translations
      ]),
      do: {msgstr, comments, translations}

  def extract_meta_headers(translations), do: {[], [], translations}

  @spec inject_meta_headers(
          headers :: [String.t()],
          comments :: [[String.t()]],
          translations :: [Translation.t()]
        ) :: [Translation.t()]
  def inject_meta_headers(headers, comments, translations)
  def inject_meta_headers([], [], translations), do: translations

  def inject_meta_headers(headers, comments, translations) do
    [
      %Translation.Singular{msgid: [""], msgstr: headers, comments: comments}
      | translations
    ]
  end
end
