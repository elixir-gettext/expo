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

  @spec rebalance_strings(string :: iodata()) :: iodata()
  def rebalance_strings(strings),
    do: strings |> IO.iodata_to_binary() |> split_at_newline()

  defp split_at_newline(subject, acc_string \\ "", acc_list \\ [])
  defp split_at_newline(<<>>, acc_string, acc_list), do: Enum.reverse([acc_string | acc_list])

  defp split_at_newline(<<?\n, rest::binary>>, acc_string, acc_list),
    do: split_at_newline(rest, "", [acc_string <> "\n" | acc_list])

  defp split_at_newline(<<character::utf8, rest::binary>>, acc_string, acc_list),
    do: split_at_newline(rest, <<acc_string::binary, character::utf8>>, acc_list)
end
