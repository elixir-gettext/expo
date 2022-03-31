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
                   string(Atom.to_string(keyword))
                   |> concat(parsec(:whitespace_no_nl))
                   |> ignore()
                   |> concat(parsec(:strings))
                   |> tag(keyword)
                   |> label("#{keyword} followed by strings")
  end

  defcombinatorp :comment_content,
                 repeat(utf8_char(not: ?\n))
                 |> concat(parsec(:newline))
                 |> reduce(:to_string)

  defcombinatorp :comment,
                 string("#")
                 |> lookahead_not(utf8_char([?., ?:, ?,, ?|, ?~]))
                 |> concat(optional(parsec(:whitespace_no_nl)))
                 |> ignore()
                 |> concat(parsec(:comment_content))
                 |> unwrap_and_tag(:comment)
                 |> label("comment")

  defcombinatorp :extracted_comment,
                 string("#.")
                 |> lookahead_not(utf8_char([?., ?:, ?,, ?|, ?~]))
                 |> concat(optional(parsec(:whitespace_no_nl)))
                 |> ignore()
                 |> concat(parsec(:comment_content))
                 |> unwrap_and_tag(:extracted_comment)
                 |> label("extracted_comment")

  defcombinatorp :previous_msgid,
                 string("#|")
                 |> parsec(:whitespace_no_nl)
                 |> ignore()
                 |> parsec(:msgid)
                 |> unwrap_and_tag(:previous_msgid)
                 |> label("previous_msgid")

  defcombinatorp :flag_content,
                 optional(parsec(:whitespace_no_nl))
                 |> concat(utf8_char(not: ?\n, not: ?,) |> repeat() |> reduce(:to_string))
                 |> concat(optional(parsec(:whitespace_no_nl)))

  defcombinatorp :flag,
                 string("#")
                 |> ignore()
                 |> times(
                   string(",")
                   |> ignore()
                   |> parsec(:flag_content),
                   min: 1
                 )
                 |> concat(parsec(:newline))
                 |> reduce(:remove_empty_flags)
                 |> unwrap_and_tag(:flag)
                 |> label("flag")

  defcombinatorp :reference_entry_line,
                 string(":")
                 |> ignore()
                 |> concat(unwrap_and_tag(integer(min: 1), :line))

  defcombinatorp :reference_entry_file,
                 choice([
                   utf8_char(not: ?\n, not: ?,, not: ?:),
                   lookahead_not(string(":"), integer(min: 1))
                 ])
                 |> times(min: 1)
                 |> reduce(:to_string)
                 |> unwrap_and_tag(:file)

  defcombinatorp :reference_entry,
                 optional(parsec(:whitespace_no_nl))
                 |> concat(parsec(:reference_entry_file))
                 |> concat(optional(parsec(:reference_entry_line)))
                 |> concat(
                   ignore(choice([string(","), string(" "), lookahead(parsec(:newline))]))
                 )
                 |> reduce(:make_reference)

  defcombinatorp :reference,
                 string("#:")
                 |> ignore()
                 |> times(parsec(:reference_entry), min: 1)
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
                 |> concat(parsec(:whitespace_no_nl))
                 |> concat(parsec(:strings))
                 |> reduce(:make_plural_form)
                 |> unwrap_and_tag(:msgstr)

  defcombinatorp :obsolete_prefix,
                 string("#~") |> concat(parsec(:whitespace_no_nl)) |> ignore() |> tag(:obsolete)

  defcombinatorp :singular_translation,
                 optional(parsec(:obsolete_prefix))
                 |> concat(parsec(:msgstr))
                 |> tag(Translation.Singular)
                 |> label("translation")

  defcombinatorp :plural_translation,
                 optional(parsec(:obsolete_prefix))
                 |> concat(parsec(:msgid_plural))
                 |> times(parsec(:msgstr_with_plural_form), min: 1)
                 |> tag(Translation.Plural)
                 |> label("plural translation")

  defcombinatorp :translation,
                 repeat(parsec(:translation_meta))
                 |> concat(optional(parsec(:obsolete_prefix)))
                 |> optional(parsec(:msgctxt))
                 |> concat(optional(parsec(:obsolete_prefix)))
                 |> post_traverse(:attach_line_number)
                 |> concat(parsec(:msgid))
                 |> concat(choice([parsec(:singular_translation), parsec(:plural_translation)]))
                 |> reduce(:make_translation)
                 |> label("translation")

  defcombinatorp :po_entry,
                 parsec(:optional_whitespace)
                 |> concat(parsec(:translation))
                 |> concat(parsec(:optional_whitespace))
                 |> post_traverse(:register_duplicates)

  defparsecp :po_file,
             times(parsec(:po_entry), min: 1)
             |> reduce(:make_translations)
             |> unwrap_and_tag(:translations)
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
            obsolete: false
          }
        ]
      }}
  """
  @impl Expo.Parser
  def parse(content) do
    case po_file(content, context: %{detected_duplicates: []}) do
      {:ok, [{:translations, translations}], "", %{detected_duplicates: []}, _line, _offset} ->
        {:ok, translations}

      {:ok, _result, "", %{detected_duplicates: [_head | _rest] = detected_duplicates}, _line,
       _offset} ->
        {:error,
         {:duplicate_translation,
          detected_duplicates
          |> Enum.map(fn
            {translation, new_line, old_line} ->
              {build_duplicated_error_message(translation, new_line), new_line, old_line}
          end)
          |> Enum.reverse()}}

      {:error, message, offending_content, _context, {line, _offset_line}, _offset} ->
        {:error, {:parse_error, message, offending_content, line}}
    end
  end

  defp make_plural_form([plural_form | strings]), do: {plural_form, strings}

  defp make_reference(tokens) do
    case Keyword.fetch(tokens, :line) do
      {:ok, line} -> {Keyword.fetch!(tokens, :file), line}
      :error -> Keyword.fetch!(tokens, :file)
    end
  end

  defp make_translations(translations) do
    {headers, top_comments, translations} = Util.extract_meta_headers(translations)

    %Translations{translations: translations, headers: headers, top_comments: top_comments}
  end

  defp make_translation(tokens) do
    {[{type, type_attrs}], attrs} =
      Keyword.split(tokens, [Translation.Singular, Translation.Plural])

    attrs =
      [attrs, type_attrs]
      |> Enum.concat()
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.map(&make_translation_attribute(type, elem(&1, 0), elem(&1, 1)))

    struct!(type, attrs)
  end

  defp make_translation_attribute(type, key, value)

  defp make_translation_attribute(_type, :msgid, [value]), do: {:msgid, value}
  defp make_translation_attribute(_type, :msgctxt, [value]), do: {:msgctxt, value}

  defp make_translation_attribute(Translation.Plural, :msgid_plural, [value]),
    do: {:msgid_plural, value}

  defp make_translation_attribute(Translation.Singular, :msgstr, [value]), do: {:msgstr, value}

  defp make_translation_attribute(Translation.Plural, :msgstr, value),
    do: {:msgstr, Map.new(value, fn {key, values} -> {key, values} end)}

  defp make_translation_attribute(_type, :comment, value), do: {:comments, value}

  defp make_translation_attribute(_type, :extracted_comment, value),
    do: {:extracted_comments, value}

  defp make_translation_attribute(_type, :flag, value), do: {:flags, value}

  defp make_translation_attribute(_type, :previous_msgid, value),
    do: {:previous_msgids, Keyword.values(value)}

  defp make_translation_attribute(_type, :reference, value), do: {:references, value}
  defp make_translation_attribute(_type, :obsolete, _value), do: {:obsolete, true}

  defp remove_empty_flags(tokens), do: Enum.reject(tokens, &match?("", &1))

  defp attach_line_number(rest, args, context, {line, _line_offset}, _offset),
    do: {rest, args, Map.put(context, :entry_line_number, line)}

  defp register_duplicates(
         rest,
         [%struct{} = translation] = args,
         %{entry_line_number: new_line} = context,
         _line,
         _offset
       ) do
    key = struct.key(translation)

    context =
      case context[:duplicate_key_line_mapping][key] do
        nil ->
          context

        old_line ->
          Map.update!(context, :detected_duplicates, &[{translation, new_line, old_line} | &1])
      end

    context =
      Map.update(
        context,
        :duplicate_key_line_mapping,
        %{key => new_line},
        &Map.put_new(&1, key, new_line)
      )

    {rest, args, context}
  end

  defp build_duplicated_error_message(%Translation.Singular{} = translation, new_line) do
    id = IO.iodata_to_binary(translation.msgid)

    "found duplicate on line #{new_line} for msgid: '#{id}'"
  end

  defp build_duplicated_error_message(%Translation.Plural{} = translation, new_line) do
    id = IO.iodata_to_binary(translation.msgid)
    idp = IO.iodata_to_binary(translation.msgid_plural)
    "found duplicate on line #{new_line} for msgid: '#{id}' and msgid_plural: '#{idp}'"
  end
end
