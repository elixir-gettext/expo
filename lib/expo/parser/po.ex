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

  newline = ascii_char([?\n]) |> label("newline") |> ignore()

  optional_whitespace =
    ascii_char([?\s, ?\n, ?\r, ?\t])
    |> times(min: 0)
    |> label("whitespace")
    |> ignore()

  whitespace_no_nl =
    ascii_char([?\s, ?\r, ?\t])
    |> times(min: 1)
    |> label("whitespace")
    |> ignore()

  double_quote = ascii_char([?"]) |> label("double quote") |> ignore()

  escaped_char =
    choice([
      replace(string(~S(\n)), ?\n),
      replace(string(~S(\t)), ?\t),
      replace(string(~S(\r)), ?\r),
      replace(string(~S(\")), ?\"),
      replace(string(~S(\\)), ?\\)
    ])

  string =
    double_quote
    |> repeat(choice([escaped_char, utf8_char(not: ?", not: ?\n)]))
    |> label(lookahead_not(newline), "newline inside string")
    |> concat(double_quote)
    |> reduce(:to_string)

  strings =
    string
    |> concat(optional_whitespace)
    |> times(min: 1)
    |> label("at least one string")

  [msgctxt, msgid, msgid_plural, msgstr] =
    for keyword <- [:msgctxt, :msgid, :msgid_plural, :msgstr] do
      string(Atom.to_string(keyword))
      |> concat(whitespace_no_nl)
      |> ignore()
      |> concat(strings)
      |> tag(keyword)
      |> label("#{keyword} followed by strings")
    end

  comment_content =
    repeat(utf8_char(not: ?\n))
    |> concat(newline)
    |> reduce(:to_string)

  comment =
    string("#")
    |> lookahead_not(utf8_char([?., ?:, ?,, ?|, ?~]))
    |> concat(optional(whitespace_no_nl))
    |> ignore()
    |> concat(comment_content)
    |> unwrap_and_tag(:comment)
    |> label("comment")

  extracted_comment =
    string("#.")
    |> lookahead_not(utf8_char([?., ?:, ?,, ?|, ?~]))
    |> concat(optional(whitespace_no_nl))
    |> ignore()
    |> concat(comment_content)
    |> unwrap_and_tag(:extracted_comment)
    |> label("extracted_comment")

  previous_msgid =
    string("#|")
    |> concat(whitespace_no_nl)
    |> ignore()
    |> concat(msgid)
    |> unwrap_and_tag(:previous_msgid)
    |> label("previous_msgid")

  flag_content =
    optional(whitespace_no_nl)
    |> concat(utf8_char(not: ?\n, not: ?,) |> repeat() |> reduce(:to_string))
    |> concat(optional(whitespace_no_nl))

  flag =
    ignore(string("#"))
    |> times(
      string(",")
      |> ignore()
      |> concat(flag_content),
      min: 1
    )
    |> concat(newline)
    |> reduce(:remove_empty_flags)
    |> unwrap_and_tag(:flag)
    |> label("flag")

  reference_entry_line =
    string(":")
    |> ignore()
    |> concat(unwrap_and_tag(integer(min: 1), :line))

  reference_entry_file =
    choice([
      utf8_char(not: ?\n, not: ?,, not: ?:),
      lookahead_not(string(":"), integer(min: 1))
    ])
    |> times(min: 1)
    |> reduce(:to_string)
    |> unwrap_and_tag(:file)

  reference_entry =
    optional(whitespace_no_nl)
    |> concat(reference_entry_file)
    |> concat(optional(reference_entry_line))
    |> concat(ignore(choice([string(","), string(" "), lookahead(newline)])))
    |> reduce(:make_reference)

  reference =
    string("#:")
    |> ignore()
    |> times(reference_entry, min: 1)
    |> concat(newline)
    |> tag(:reference)
    |> label("reference")

  translation_meta =
    choice([
      comment,
      extracted_comment,
      reference,
      flag,
      previous_msgid
    ])

  plural_form =
    ignore(string("["))
    |> integer(min: 1)
    |> ignore(string("]"))
    |> label("plural form (like [0])")

  obsolete_prefix = string("#~") |> concat(whitespace_no_nl) |> ignore() |> tag(:obsolete)

  msgstr_with_plural_form =
    ignore(optional(obsolete_prefix))
    |> concat(ignore(string("msgstr")))
    |> concat(plural_form)
    |> concat(whitespace_no_nl)
    |> concat(strings)
    |> reduce(:make_plural_form)
    |> unwrap_and_tag(:msgstr)

  singular_translation =
    optional(obsolete_prefix)
    |> concat(msgstr)
    |> tag(Translation.Singular)
    |> label("translation")

  plural_translation =
    optional(obsolete_prefix)
    |> concat(msgid_plural)
    |> times(msgstr_with_plural_form, min: 1)
    |> tag(Translation.Plural)
    |> label("plural translation")

  translation =
    repeat(translation_meta)
    |> concat(optional(obsolete_prefix))
    |> optional(msgctxt)
    |> concat(optional(obsolete_prefix))
    |> post_traverse(:attach_line_number)
    |> concat(msgid)
    |> concat(choice([singular_translation, plural_translation]))
    |> reduce(:make_translation)
    |> label("translation")

  po_entry =
    optional_whitespace
    |> concat(translation)
    |> concat(optional_whitespace)
    |> post_traverse(:register_duplicates)

  defparsecp :po_file,
             repeat(
               choice([
                 po_entry,
                 comment
               ])
             )
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

  defp make_translations(tokens) do
    translations = Enum.reject(tokens, &match?({:comment, _comment}, &1))

    root_top_comments =
      tokens |> Enum.filter(&match?({:comment, _comment}, &1)) |> Keyword.values()

    {headers, top_comments, translations} = Util.extract_meta_headers(translations)

    %Translations{
      translations: translations,
      headers: headers,
      top_comments: root_top_comments ++ top_comments
    }
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
