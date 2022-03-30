# credo:disable-for-this-file Credo.Check.Refactor.PipeChainStart
defmodule Expo.Parser.Po do
  @moduledoc """
  `.po` / `.pot` file parser
  """

  @behaviour Expo.Parser

  # Code copied and adapted from:
  # https://github.com/elixir-gettext/gettext/blob/d9faa55e67657f923f7f57dbf209ce36ec50f947/lib/gettext/nimble_parser.ex

  import NimbleParsec

  alias Expo.Parser.Util
  alias Expo.Translation
  alias Expo.Translations

  defcombinatorp :newline, ascii_char([?\n]) |> label("newline") |> ignore()

  defcombinatorp :optional_whitespace,
                 ascii_char([?\s, ?\n, ?\r, ?\t])
                 |> times(min: 0)
                 |> label("whitespace")
                 |> ignore()

  defcombinatorp :whitespace_no_nl,
                 ascii_char([?\s, ?\r, ?\t])
                 |> times(min: 1)
                 |> label("whitespace")
                 |> ignore()

  defcombinatorp :double_quote, ascii_char([?"]) |> label("double quote") |> ignore()

  defcombinatorp :escaped_char,
                 choice([
                   replace(string(~S(\n)), ?\n),
                   replace(string(~S(\t)), ?\t),
                   replace(string(~S(\r)), ?\r),
                   replace(string(~S(\")), ?\"),
                   replace(string(~S(\\)), ?\\)
                 ])

  defcombinatorp :string,
                 parsec(:double_quote)
                 |> repeat(choice([parsec(:escaped_char), utf8_char(not: ?", not: ?\n)]))
                 |> label(lookahead_not(parsec(:newline)), "newline inside string")
                 |> concat(parsec(:double_quote))
                 |> reduce(:to_string)

  defcombinatorp :strings,
                 parsec(:string)
                 |> concat(parsec(:optional_whitespace))
                 |> times(min: 1)
                 |> label("at least one string")

  for keyword <- [:msgctxt, :msgid, :msgid_plural, :msgstr] do
    defcombinatorp keyword,
                   ignore(concat(string(Atom.to_string(keyword)), parsec(:whitespace_no_nl)))
                   |> concat(parsec(:strings))
                   |> tag(keyword)
                   |> label("#{keyword} followed by strings")
  end

  defcombinatorp :comment,
                 ignore(
                   optional(parsec(:whitespace_no_nl))
                   |> string("#")
                   |> lookahead_not(
                     choice([
                       string("."),
                       string(":"),
                       string(","),
                       string("| msgid"),
                       string("~")
                     ])
                   )
                   |> concat(parsec(:whitespace_no_nl))
                 )
                 |> repeat(utf8_char(not: ?\n))
                 |> concat(parsec(:newline))
                 |> reduce(:to_string)
                 |> tag(:comment)
                 |> label("comment")

  for {meta_type, character} <- [
        extracted_comment: ".",
        reference: ":",
        flag: ",",
        previous_msgid: "| msgid"
      ] do
    defcombinatorp meta_type,
                   ignore(
                     optional(parsec(:whitespace_no_nl))
                     |> string("#")
                     |> string(character)
                     |> concat(parsec(:whitespace_no_nl))
                   )
                   |> repeat(utf8_char(not: ?\n))
                   |> concat(parsec(:newline))
                   |> reduce(:to_string)
                   |> tag(meta_type)
                   |> label(Atom.to_string(meta_type))
  end

  defcombinatorp :translation_meta,
                 choice([
                   parsec(:comment),
                   parsec(:extracted_comment),
                   parsec(:reference),
                   parsec(:flag),
                   parsec(:previous_msgid)
                 ])

  defcombinatorp :plural_form,
                 ignore(string("["))
                 |> integer(min: 1)
                 |> ignore(string("]"))
                 |> label("plural form (like [0])")

  defcombinatorp :msgstr_with_plural_form,
                 ignore(string("msgstr"))
                 |> concat(parsec(:plural_form))
                 |> concat(parsec(:whitespace_no_nl))
                 |> concat(parsec(:strings))
                 |> reduce(:make_plural_form)
                 |> tag(:msgstr)

  defcombinatorp :singular_translation,
                 repeat(parsec(:translation_meta))
                 |> ignore(optional(parsec(:msgctxt)))
                 |> concat(parsec(:msgid))
                 |> concat(parsec(:msgstr))
                 |> reduce({:make_translation, [Translation.Singular]})
                 |> tag(:singular_translation)
                 |> label("translation")

  defcombinatorp :obsolete_prefix, ignore(concat(string("#~"), parsec(:whitespace_no_nl)))

  defcombinatorp :obsolete_singular_translation,
                 repeat(parsec(:translation_meta))
                 |> ignore(optional(parsec(:msgctxt)))
                 |> concat(parsec(:obsolete_prefix))
                 |> concat(parsec(:msgid))
                 |> concat(parsec(:obsolete_prefix))
                 |> concat(parsec(:msgstr))
                 |> reduce({:make_translation, [Translation.Singular]})
                 |> tag(:obsolete_singular_translation)
                 |> label("obsolete translation")

  defcombinatorp :plural_translation,
                 repeat(parsec(:translation_meta))
                 |> ignore(optional(parsec(:msgctxt)))
                 |> concat(parsec(:msgid))
                 |> concat(parsec(:msgid_plural))
                 |> times(parsec(:msgstr_with_plural_form), min: 1)
                 |> reduce({:make_translation, [Translation.Plural]})
                 |> tag(:plural_translation)
                 |> label("plural translation")

  defcombinatorp :obsolete_plural_translation,
                 repeat(parsec(:translation_meta))
                 |> ignore(optional(parsec(:msgctxt)))
                 |> concat(parsec(:obsolete_prefix))
                 |> concat(parsec(:msgid))
                 |> concat(parsec(:obsolete_prefix))
                 |> concat(parsec(:msgid_plural))
                 |> times(
                   concat(parsec(:obsolete_prefix), parsec(:msgstr_with_plural_form)),
                   min: 1
                 )
                 |> reduce({:make_translation, [Translation.Plural]})
                 |> tag(:obsolete_singular_translation)
                 |> label("obsolete plural translation")

  defcombinatorp :translation,
                 choice([
                   parsec(:singular_translation),
                   parsec(:plural_translation),
                   parsec(:obsolete_singular_translation),
                   parsec(:obsolete_plural_translation)
                 ])

  defparsecp :po_file,
             times(parsec(:translation), min: 1) |> parsec(:optional_whitespace) |> eos()

  @doc """
  Parse `.po` file

  ### Examples

      iex> Expo.Parser.Po.parse(\"""
      ...> msgid "foo"
      ...> msgstr "bar"
      ...> \""")
      %Expo.Translations{
        headers: [],
        obsolete_translations: [],
        translations: [
          %Expo.Translation.Singular{
            comments: [],
            msgctx: nil,
            extracted_comments: [],
            flags: MapSet.new([]),
            msgid: "foo",
            msgstr: "bar",
            previous_msgids: [],
            references: []
          }
        ]
      }
  """
  @impl Expo.Parser
  def parse(content) do
    case po_file(content) do
      {:ok, translations, "", _context, _line, _offset} ->
        {obsolete, translations} = filter_obsolete_translations(translations)

        {headers, translations} = Util.extract_meta_headers(translations)

        %Translations{
          translations: translations,
          obsolete_translations: obsolete,
          headers: headers
        }

      {:error, message, offending_content, _context, {line, offset}, offset} ->
        {:error, {:parse_error, message, offending_content, line, offset}}
    end
  end

  defp make_plural_form([plural_form | strings]), do: {plural_form, strings}

  defp make_translation(tokens, type) do
    struct!(
      type,
      tokens
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.map(fn {key, values} ->
        {key, Enum.flat_map(values, & &1)}
      end)
      |> Enum.map(&make_translation_attribute(type, elem(&1, 0), elem(&1, 1)))
    )
  end

  defp make_translation_attribute(type, key, value)
  defp make_translation_attribute(_type, :msgid, value), do: {:msgid, Enum.join(value, "")}

  defp make_translation_attribute(Translation.Plural, :msgid_plural, value),
    do: {:msgid_plural, Enum.join(value, "")}

  defp make_translation_attribute(Translation.Singular, :msgstr, value),
    do: {:msgstr, Enum.join(value, "")}

  defp make_translation_attribute(Translation.Plural, :msgstr, value),
    do: {:msgstr, Map.new(value, fn {key, values} -> {key, Enum.join(values, "")} end)}

  defp make_translation_attribute(_type, :comment, value), do: {:comments, value}

  defp make_translation_attribute(_type, :extracted_comment, value),
    do: {:extracted_comments, value}

  defp make_translation_attribute(_type, :flag, value),
    do:
      {:flags,
       value |> Enum.flat_map(&String.split(&1, ",")) |> Enum.map(&String.trim/1) |> MapSet.new()}

  defp make_translation_attribute(_type, :previous_msgid, value),
    do: {:previous_msgids, value}

  defp make_translation_attribute(_type, :reference, value),
    do: {:references, value}

  defp filter_obsolete_translations(translations) do
    {obsolete, translations} =
      translations
      |> Enum.chunk_by(
        &match?(
          {type, _translation}
          when type in [:obsolete_singular_translation, :obsolete_plural_translation],
          &1
        )
      )
      |> case do
        [translations] -> {[], translations}
        [translations, obsolete] -> {obsolete, translations}
        [] -> {[], []}
      end

    {obsolete |> Keyword.values() |> List.flatten(),
     translations |> Keyword.values() |> List.flatten()}
  end
end
