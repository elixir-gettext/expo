# credo:disable-for-this-file Credo.Check.Refactor.PipeChainStart
defmodule Expo.Po.Parser do
  @moduledoc false

  import NimbleParsec

  alias Expo.Translation
  alias Expo.Translations
  alias Expo.Util

  @bom <<0xEF, 0xBB, 0xBF>>

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
    |> ignore()
    |> concat(comment_content)
    |> unwrap_and_tag(:comment)
    |> label("comment")

  extracted_comment =
    string("#.")
    |> lookahead_not(utf8_char([?., ?:, ?,, ?|, ?~]))
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

  translation_base =
    repeat(translation_meta)
    |> concat(optional(obsolete_prefix))
    |> optional(msgctxt)
    |> concat(optional(obsolete_prefix))
    |> post_traverse(:attach_line_number)
    |> concat(msgid)

  singular_translation =
    translation_base
    |> concat(optional(obsolete_prefix))
    |> concat(msgstr)
    |> tag(Translation.Singular)
    |> reduce(:make_translation)
    |> label("singular translation")

  plural_translation =
    translation_base
    |> concat(optional(obsolete_prefix))
    |> concat(msgid_plural)
    |> times(msgstr_with_plural_form, min: 1)
    |> tag(Translation.Plural)
    |> reduce(:make_translation)
    |> label("plural translation")

  translation = choice([singular_translation, plural_translation])

  po_entry =
    optional_whitespace
    |> concat(translation)
    |> concat(optional_whitespace)
    |> post_traverse(:register_duplicates)

  defparsecp :po_file,
             times(po_entry, min: 1)
             |> post_traverse(:make_translations)
             |> unwrap_and_tag(:translations)
             |> eos()

  @spec parse(content :: String.t(), opts :: Keyword.t()) ::
          {:ok, Translations.t()}
          | {:error,
             {:parse_error, message :: String.t(), offending_content :: String.t(),
              line :: pos_integer()}
             | {:duplicate_translations,
                [{message :: String.t(), new_line :: pos_integer(), old_line :: pos_integer()}]}}
  def parse(content, opts \\ []) do
    content = prune_bom(content, Keyword.get(opts, :file, "nofile"))

    case po_file(content, context: %{detected_duplicates: [], file: Keyword.get(opts, :file)}) do
      {:ok, [{:translations, translations}], "", %{detected_duplicates: []}, _line, _offset} ->
        {:ok, translations}

      {:ok, _result, "", %{detected_duplicates: [_head | _rest] = detected_duplicates}, _line,
       _offset} ->
        {:error,
         {:duplicate_translations,
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

  defp make_translations(rest, translations, context, _line, _offset) do
    {headers, top_comments, translations} =
      translations |> Enum.reverse() |> Util.extract_meta_headers()

    tokens = %Translations{
      translations: translations,
      headers: headers,
      top_comments: top_comments,
      file: context[:file]
    }

    {rest, [tokens], context}
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

  # This function removes a BOM byte sequence from the start of the given string
  # if this sequence is present. A BOM byte sequence
  # (https://en.wikipedia.org/wiki/Byte_order_mark) is a thing that Unicode uses
  # as a kind of metadata for a file; it's placed at the start of the file. GNU
  # Gettext blows up if it finds a BOM sequence at the start of a file (as you
  # can check with the `msgfmt` program); here, we don't blow up but we print a
  # warning saying the BOM is present and suggesting to remove it.
  #
  # Note that `file` is used to give a nicer warning in case the BOM is
  # present. This function is in fact called by both parse_string/1 and
  # parse_file/1. Since parse_file/1 relies on parse_string/1, in case
  # parse_file/1 is called this function is called twice but that's ok because
  # in case of BOM, parse_file/1 will remove it first and parse_string/1 won't
  # issue the warning again as its call to prune_bom/2 will be a no-op.
  defp prune_bom(str, file)

  defp prune_bom(@bom <> str, file) do
    file_or_string = if file == "nofile", do: "string", else: "file"

    warning =
      "#{file}: warning: the #{file_or_string} being parsed starts " <>
        "with a BOM byte sequence (#{inspect(@bom, binaries: :as_binaries)}). " <>
        "These bytes are ignored by Gettext but it's recommended to remove " <>
        "them. To know more about BOM, read https://en.wikipedia.org/wiki/Byte_order_mark."

    IO.puts(:stderr, warning)

    str
  end

  defp prune_bom(str, _file) when is_binary(str) do
    str
  end
end
