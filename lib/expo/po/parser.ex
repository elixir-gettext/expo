# credo:disable-for-this-file Credo.Check.Refactor.PipeChainStart
defmodule Expo.Po.Parser do
  @moduledoc false

  import NimbleParsec

  alias Expo.Message
  alias Expo.Messages
  alias Expo.Po
  alias Expo.Util

  @bom <<0xEF, 0xBB, 0xBF>>

  newline = ascii_char([?\n]) |> label("newline") |> ignore()

  optional_whitespace =
    ascii_char([?\s, ?\n, ?\r, ?\t])
    |> times(min: 0)
    |> label("whitespace")
    |> ignore()

  optional_whitespace_no_nl =
    ascii_char([?\s, ?\r, ?\t])
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

  string_line =
    optional_whitespace_no_nl
    |> concat(string)
    |> concat(optional_whitespace_no_nl)
    |> repeat()

  strings =
    string_line
    |> repeat(concat(newline, string_line))
    |> label("at least one string")

  [
    msgctxt,
    obsolete_msgctxt,
    msgid,
    obsolete_msgid,
    previous_msgid,
    obsolete_previous_msgid,
    msgid_plural,
    obsolete_msgid_plural,
    previous_msgid_plural,
    obsolete_previous_msgid_plural,
    msgstr,
    obsolete_msgstr
  ] =
    for {tag, {label, keyword, prepend, strings}} <- [
          msgctxt: {"msgctxt", "msgctxt", empty(), strings},
          msgctxt: {"obsolete msgctxt", "msgctxt", string("#~"), strings},
          msgid: {"msgid", "msgid", empty(), strings},
          msgid: {"obsolete msgid", "msgid", string("#~"), strings},
          msgid: {"previous msgid", "msgid", string("#|"), strings},
          msgid: {"obsolete & previous msgid", "msgid", string("#~|"), strings},
          msgid_plural: {"msgid_plural", "msgid_plural", empty(), strings},
          msgid_plural: {"obsolete msgid_plural", "msgid_plural", string("#~"), strings},
          msgid_plural: {"previous msgid_plural", "msgid_plural", string("#|"), strings},
          msgid_plural:
            {"obsolete & previous msgid_plural", "msgid_plural", string("#~|"), strings},
          msgstr: {"msgstr", "msgstr", empty(), strings},
          msgstr: {"obsolete msgstr", "msgstr", string("#~"), strings}
        ] do
      prepend
      |> concat(optional(whitespace_no_nl))
      |> concat(string(keyword))
      |> concat(whitespace_no_nl)
      |> ignore()
      |> concat(strings)
      |> tag(tag)
      |> label("#{label} followed by strings")
    end

  comment_content =
    repeat(utf8_char(not: ?\n))
    |> concat(newline)
    |> reduce(:to_string)

  [comment, extracted_comment] =
    for {tag, start} <- [
          comment: lookahead_not(string("#"), utf8_char([?., ?:, ?,, ?|, ?~])),
          extracted_comment: string("#.")
        ] do
      start
      |> ignore()
      |> concat(comment_content)
      |> unwrap_and_tag(tag)
      |> label(Atom.to_string(tag))
    end

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

  message_meta =
    choice([
      comment,
      extracted_comment,
      reference,
      flag,
      tag(tag(concat(previous_msgid, previous_msgid_plural), Message.Plural), :previous_messages),
      tag(tag(previous_msgid, Message.Singular), :previous_messages),
      tag(
        tag(concat(obsolete_previous_msgid, obsolete_previous_msgid_plural), Message.Plural),
        :previous_messages
      ),
      tag(tag(obsolete_previous_msgid, Message.Singular), :previous_messages)
    ])

  plural_form =
    ignore(string("["))
    |> integer(min: 1)
    |> ignore(string("]"))
    |> label("plural form (like [0])")

  [msgstr_with_plural_form, obsolete_msgstr_with_plural_form] =
    for prefix <- [empty(), string("#~")] do
      prefix
      |> concat(optional(whitespace_no_nl))
      |> concat(ignore(string("msgstr")))
      |> concat(plural_form)
      |> concat(whitespace_no_nl)
      |> concat(strings)
      |> reduce(:make_plural_form)
      |> unwrap_and_tag(:msgstr)
    end

  message_base =
    repeat(message_meta)
    |> optional(msgctxt)
    |> post_traverse(:attach_line_number)
    |> concat(msgid)

  obsolete_message_base =
    repeat(message_meta)
    |> optional(obsolete_msgctxt)
    |> post_traverse(:attach_line_number)
    |> concat(obsolete_msgid)

  singular_message =
    message_base
    |> concat(msgstr)
    |> tag(Message.Singular)
    |> reduce(:make_message)

  obsolete_singular_message =
    obsolete_message_base
    |> concat(obsolete_msgstr)
    |> tag(Message.Singular)
    |> reduce(:make_message)

  plural_message =
    message_base
    |> concat(msgid_plural)
    |> times(msgstr_with_plural_form, min: 1)
    |> tag(Message.Plural)
    |> reduce(:make_message)

  obsolete_plural_message =
    obsolete_message_base
    |> concat(obsolete_msgid_plural)
    |> times(obsolete_msgstr_with_plural_form, min: 1)
    |> tag(Message.Plural)
    |> reduce(:make_message)

  message =
    [obsolete_singular_message, obsolete_plural_message, singular_message, plural_message]
    |> choice()
    |> label("message")

  po_entry =
    optional_whitespace
    |> concat(message)
    |> concat(optional_whitespace)
    |> post_traverse(:register_duplicates)

  defparsecp :po_file,
             times(po_entry, min: 1)
             |> post_traverse(:make_messages)
             |> unwrap_and_tag(:messages)
             |> eos()

  @spec parse(content :: String.t(), opts :: Po.parse_options()) ::
          {:ok, Messages.t()}
          | {:error,
             {:parse_error, message :: String.t(), offending_content :: String.t(),
              line :: pos_integer()}
             | {:duplicate_messages,
                [{message :: String.t(), new_line :: pos_integer(), old_line :: pos_integer()}]}}
  def parse(content, opts) do
    content = prune_bom(content, Keyword.get(opts, :file, "nofile"))

    case po_file(content, context: %{detected_duplicates: [], file: Keyword.get(opts, :file)}) do
      {:ok, [{:messages, messages}], "", %{detected_duplicates: []}, _line, _offset} ->
        {:ok, messages}

      {:ok, _result, "", %{detected_duplicates: [_head | _rest] = detected_duplicates}, _line,
       _offset} ->
        {:error,
         {:duplicate_messages,
          detected_duplicates
          |> Enum.map(fn
            {message, new_line, old_line} ->
              {build_duplicated_error_message(message, new_line), new_line, old_line}
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

  defp make_messages(rest, messages, context, _line, _offset) do
    {headers, top_comments, messages} = messages |> Enum.reverse() |> Util.extract_meta_headers()

    tokens = %Messages{
      messages: messages,
      headers: headers,
      top_comments: top_comments,
      file: context[:file]
    }

    {rest, [tokens], context}
  end

  defp make_message(tokens) do
    {[{type, type_attrs}], attrs} = Keyword.split(tokens, [Message.Singular, Message.Plural])

    attrs =
      [attrs, type_attrs]
      |> Enum.concat()
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.map(&make_message_attribute(type, elem(&1, 0), elem(&1, 1)))

    struct!(type, attrs)
  end

  defp make_message_attribute(type, key, value)

  defp make_message_attribute(_type, :msgid, [value]), do: {:msgid, value}
  defp make_message_attribute(_type, :msgctxt, [value]), do: {:msgctxt, value}

  defp make_message_attribute(Message.Plural, :msgid_plural, [value]),
    do: {:msgid_plural, value}

  defp make_message_attribute(Message.Singular, :msgstr, [value]), do: {:msgstr, value}

  defp make_message_attribute(Message.Plural, :msgstr, value),
    do: {:msgstr, Map.new(value, fn {key, values} -> {key, values} end)}

  defp make_message_attribute(_type, :comment, value), do: {:comments, value}

  defp make_message_attribute(_type, :extracted_comment, value),
    do: {:extracted_comments, value}

  defp make_message_attribute(_type, :flag, value), do: {:flags, value}

  defp make_message_attribute(_type, :reference, value), do: {:references, value}

  defp make_message_attribute(_type, :previous_messages, value),
    do: {:previous_messages, Enum.map(value, &make_message/1)}

  defp remove_empty_flags(tokens), do: Enum.reject(tokens, &match?("", &1))

  defp attach_line_number(rest, args, context, {line, _line_offset}, _offset),
    do: {rest, args, Map.put(context, :entry_line_number, line)}

  defp register_duplicates(
         rest,
         [%{} = message] = args,
         %{entry_line_number: new_line} = context,
         _line,
         _offset
       ) do
    key = Message.key(message)

    context =
      case context[:duplicate_key_line_mapping][key] do
        nil ->
          context

        old_line ->
          Map.update!(context, :detected_duplicates, &[{message, new_line, old_line} | &1])
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

  defp build_duplicated_error_message(%Message.Singular{} = message, new_line) do
    id = IO.iodata_to_binary(message.msgid)

    "found duplicate on line #{new_line} for msgid: '#{id}'"
  end

  defp build_duplicated_error_message(%Message.Plural{} = message, new_line) do
    id = IO.iodata_to_binary(message.msgid)
    idp = IO.iodata_to_binary(message.msgid_plural)
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
