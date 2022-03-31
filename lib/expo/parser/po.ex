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
                   |> post_traverse(:attach_line_number)
                   |> concat(parsec(:strings))
                   |> tag(keyword)
                   |> label("#{keyword} followed by strings")
  end

  defcombinatorp :comment,
                 ignore(
                   optional(parsec(:whitespace_no_nl))
                   |> string("#")
                   |> lookahead_not(utf8_char([?., ?:, ?,, ?|, ?~]))
                   |> concat(optional(parsec(:whitespace_no_nl)))
                 )
                 |> repeat(utf8_char(not: ?\n))
                 |> concat(parsec(:newline))
                 |> reduce(:to_string)
                 |> unwrap_and_tag(:comment)
                 |> label("comment")

  for {meta_type, character} <- [
        extracted_comment: ".",
        previous_msgid: "| msgid"
      ] do
    defcombinatorp meta_type,
                   ignore(
                     optional(parsec(:whitespace_no_nl))
                     |> string("#")
                     |> string(character)
                     |> concat(optional(parsec(:whitespace_no_nl)))
                   )
                   |> repeat(utf8_char(not: ?\n))
                   |> concat(parsec(:newline))
                   |> reduce(:to_string)
                   |> unwrap_and_tag(meta_type)
                   |> label(Atom.to_string(meta_type))
  end

  defcombinatorp :flag,
                 ignore(
                   parsec(:whitespace_no_nl)
                   |> optional()
                   |> string("#")
                 )
                 |> times(
                   ignore(string(","))
                   |> concat(ignore(optional(parsec(:whitespace_no_nl))))
                   |> concat(utf8_char(not: ?\n, not: ?,) |> repeat() |> reduce(:to_string))
                   |> concat(ignore(optional(parsec(:whitespace_no_nl)))),
                   min: 1
                 )
                 |> concat(parsec(:newline))
                 |> reduce(:remove_empty_flags)
                 |> unwrap_and_tag(:flag)
                 |> label("flag")

  defcombinatorp :reference,
                 ignore(
                   parsec(:whitespace_no_nl)
                   |> optional()
                   |> string("#:")
                 )
                 |> times(
                   ignore(optional(parsec(:whitespace_no_nl)))
                   |> concat(
                     times(
                       choice([
                         utf8_char(not: ?\n, not: ?,, not: ?:),
                         lookahead_not(string(":"), integer(min: 1))
                       ]),
                       min: 1
                     )
                     |> reduce(:to_string)
                     |> unwrap_and_tag(:file)
                   )
                   |> concat(
                     optional(
                       string(":")
                       |> ignore()
                       |> concat(unwrap_and_tag(integer(min: 1), :line))
                     )
                   )
                   |> concat(
                     choice([
                       ignore(string(",")),
                       ignore(string(" ")),
                       lookahead(parsec(:newline))
                     ])
                   )
                   |> reduce(:make_reference),
                   min: 1
                 )
                 |> concat(parsec(:newline))
                 |> tag(:reference)
                 |> label("reference")

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
                 ignore(optional(parsec(:obsolete_prefix)))
                 |> concat(ignore(string("msgstr")))
                 |> concat(parsec(:plural_form))
                 |> concat(ignore(parsec(:whitespace_no_nl)))
                 |> concat(parsec(:strings))
                 |> reduce(:make_plural_form)
                 |> unwrap_and_tag(:msgstr)

  defcombinatorp :obsolete_prefix,
                 string("#~") |> concat(parsec(:whitespace_no_nl)) |> ignore() |> tag(:obsolete)

  defcombinatorp :singular_translation,
                 repeat(parsec(:translation_meta))
                 |> concat(optional(parsec(:obsolete_prefix)))
                 |> optional(parsec(:msgctxt))
                 |> concat(optional(parsec(:obsolete_prefix)))
                 |> concat(parsec(:msgid))
                 |> concat(optional(parsec(:obsolete_prefix)))
                 |> concat(parsec(:msgstr))
                 |> reduce({:make_translation, [Translation.Singular]})
                 |> label("translation")

  defcombinatorp :plural_translation,
                 repeat(parsec(:translation_meta))
                 |> concat(optional(parsec(:obsolete_prefix)))
                 |> optional(parsec(:msgctxt))
                 |> concat(optional(parsec(:obsolete_prefix)))
                 |> concat(parsec(:msgid))
                 |> concat(optional(parsec(:obsolete_prefix)))
                 |> concat(parsec(:msgid_plural))
                 |> times(parsec(:msgstr_with_plural_form), min: 1)
                 |> reduce({:make_translation, [Translation.Plural]})
                 |> label("plural translation")

  defcombinatorp :translation,
                 label(
                   choice([parsec(:singular_translation), parsec(:plural_translation)]),
                   "translation"
                 )

  defparsecp :po_file,
             parsec(:optional_whitespace)
             |> concat(times(parsec(:translation), min: 1))
             |> parsec(:optional_whitespace)
             |> eos()

  @doc """
  Parse `.po` file

  ### Examples

      iex> Expo.Parser.Po.parse(\"""
      ...> msgid "foo"
      ...> msgstr "bar"
      ...> \""")
      {:ok, %Expo.Translations{
        headers: [],
        translations: [
          %Expo.Translation.Singular{
            comments: [],
            msgctxt: nil,
            extracted_comments: [],
            flags: [],
            msgid: ["foo"],
            msgstr: ["bar"],
            previous_msgids: [],
            references: [],
            obsolete: false,
            meta: %Expo.Translation.Meta{msgctxt_source_line: nil, msgid_plural_source_line: nil, msgid_source_line: 1, msgstr_source_line: 2}
          }
        ]
      }}
  """
  @impl Expo.Parser
  def parse(content) do
    with {:ok, translations, "", _context, _line, _offset} <- po_file(content),
         {headers, top_comments, translations} <- Util.extract_meta_headers(translations),
         :ok <- check_for_duplicates(translations) do
      {:ok,
       %Translations{translations: translations, headers: headers, top_comments: top_comments}}
    else
      {:error, message, offending_content, _context, {line, _offset_line}, _offset} ->
        {:error, {:parse_error, message, offending_content, line}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp make_plural_form([plural_form | strings]), do: {plural_form, strings}

  defp make_reference(tokens) do
    case Keyword.fetch(tokens, :line) do
      {:ok, line} -> {Keyword.fetch!(tokens, :file), line}
      :error -> Keyword.fetch!(tokens, :file)
    end
  end

  defp make_translation(tokens, type) do
    attrs =
      tokens
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.flat_map(&make_translation_attribute(type, elem(&1, 0), elem(&1, 1)))

    meta =
      struct(
        Translation.Meta,
        attrs |> Enum.filter(&match?({:meta, _value}, &1)) |> Keyword.values()
      )

    attrs = [{:meta, meta} | Enum.reject(attrs, &match?({:meta, _value}, &1))]

    struct!(type, attrs)
  end

  defp make_translation_attribute(type, key, value)

  defp make_translation_attribute(_type, :msgid, [[{:source_line, source_line} | value]]),
    do: [{:msgid, value}, {:meta, {:msgid_source_line, source_line}}]

  defp make_translation_attribute(_type, :msgctxt, [[{:source_line, source_line} | value]]),
    do: [{:msgctxt, value}, {:meta, {:msgctxt_source_line, source_line}}]

  defp make_translation_attribute(Translation.Plural, :msgid_plural, [
         [{:source_line, source_line} | value]
       ]),
       do: [{:msgid_plural, value}, {:meta, {:msgid_plural_source_line, source_line}}]

  defp make_translation_attribute(Translation.Singular, :msgstr, [
         [{:source_line, source_line} | value]
       ]),
       do: [{:msgstr, value}, {:meta, {:msgstr_source_line, source_line}}]

  defp make_translation_attribute(Translation.Plural, :msgstr, value),
    do: [{:msgstr, Map.new(value, fn {key, values} -> {key, values} end)}]

  defp make_translation_attribute(_type, :comment, value), do: [{:comments, value}]

  defp make_translation_attribute(_type, :extracted_comment, value),
    do: [{:extracted_comments, value}]

  defp make_translation_attribute(_type, :flag, value),
    do: [{:flags, value}]

  defp make_translation_attribute(_type, :previous_msgid, value),
    do: [{:previous_msgids, value}]

  defp make_translation_attribute(_type, :reference, value),
    do: [{:references, value}]

  defp make_translation_attribute(_type, :obsolete, _value),
    do: [{:obsolete, true}]

  defp remove_empty_flags(tokens), do: Enum.reject(tokens, &match?("", &1))

  defp attach_line_number(rest, args, context, {line, _line_offset}, _offset),
    do: {rest, [{:source_line, line} | args], context}

  defp check_for_duplicates(translations, existing \\ %{})

  defp check_for_duplicates([%struct{} = translation | rest], existing) do
    key = struct.key(translation)

    case Map.fetch(existing, key) do
      {:ok, old_line} ->
        build_duplicated_error(translation, old_line)

      :error ->
        check_for_duplicates(rest, Map.put(existing, key, translation.meta.msgid_source_line))
    end
  end

  defp check_for_duplicates([], _existing) do
    :ok
  end

  defp build_duplicated_error(%Translation.Singular{} = translation, old_line) do
    id = IO.iodata_to_binary(translation.msgid)

    {:error,
     {:duplicate_translation, "found duplicate on line #{old_line} for msgid: '#{id}'",
      translation.meta.msgid_source_line}}
  end

  defp build_duplicated_error(%Translation.Plural{} = translation, old_line) do
    id = IO.iodata_to_binary(translation.msgid)
    idp = IO.iodata_to_binary(translation.msgid_plural)
    msg = "found duplicate on line #{old_line} for msgid: '#{id}' and msgid_plural: '#{idp}'"
    {:error, {:duplicate_translation, msg, translation.meta.msgid_source_line}}
  end
end
