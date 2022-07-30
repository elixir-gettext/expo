defmodule Expo.PO.Tokenizer do
  @moduledoc false

  # This module is responsible for turning a chunk of text (a string) into a
  # list of tokens. For what "token" means, see the docs for `tokenize/1`.

  @type line :: pos_integer

  @type token ::
          {:str_lines, line, [binary]}
          | {:plural_form, line, non_neg_integer}
          | {:msgid, line}
          | {:msgid_plural, line}
          | {:msgstr, line}
          | {:msgctxt, line}
          | {:comment, line, binary}
          | {:obsolete, line}
          | {:previous, line}
          | {:eof, line}

  # In this list of keywords *the order matters* because a function clause is
  # generated for each keyword, and keywords have to be followed by whitespace.
  # `msgid_plural` would cause an error if it didn't come before `msgid`.
  # Also note that the `msgstr` keyword is missing here since it can be also
  # followed by a plural form (for example, `[1]`).
  @string_keywords ~w(
    msgid_plural
    msgid
    msgctxt
  )

  @whitespace [?\n, ?\t, ?\r, ?\s]
  @whitespace_no_nl [?\t, ?\r, ?\s]
  @escapable_chars [?", ?n, ?t, ?r, ?\\]

  @doc """
  Converts a string into a list of tokens.

  A "token" is a tuple formed by:

    * the `:str` tag or a keyword tag (like `:msgid`)
    * the line the token is at
    * the value of the token if the token has a value (for example, a `:str`
      token will have the contents of the string as a value)

  Some examples of tokens are:

    * `{:msgid, 33}`
    * `{:str, 6, "foo"}`

  """
  @spec tokenize(binary) :: {:ok, [token]} | {:error, pos_integer, binary}
  def tokenize(str) do
    tokenize_line(str)
  end

  # Converts the first line in `str` into a list of tokens and then moves on to
  # the next line.
  @spec tokenize_line(binary, pos_integer, line_prefix :: String.t(), [token]) ::
          {:ok, [token]} | {:error, pos_integer, binary}
  defp tokenize_line(str, line \\ 1, line_prefix \\ "", acc \\ [])

  # End of file.
  defp tokenize_line(<<>>, line, _line_prefix, acc) do
    tokens =
      Enum.reduce(acc, [{:"$end", line}], fn
        {:str_lines, line, strings}, acc -> [{:str_lines, line, Enum.reverse(strings)} | acc]
        token, acc -> [token | acc]
      end)

    {:ok, tokens}
  end

  # Go to the next line.
  defp tokenize_line(<<?\n, rest::binary>>, line, _line_prefix, acc) do
    tokenize_line(rest, line + 1, "", acc)
  end

  # Obsolete
  defp tokenize_line(<<?#, ?~, rest::binary>>, line, "", acc) do
    tokenize_line(rest, line, "#~", [{:obsolete, line} | acc])
  end

  # Previous
  defp tokenize_line(<<?#, ?|, rest::binary>>, line, "", acc) do
    tokenize_line(rest, line, "#|", [{:previous, line} | acc])
  end

  # Skip whitespace.
  defp tokenize_line(<<char, rest::binary>>, line, line_prefix, acc)
       when char in @whitespace_no_nl do
    tokenize_line(rest, line, line_prefix, acc)
  end

  # Keywords.
  for kw <- @string_keywords do
    defp tokenize_line(unquote(kw) <> <<char, rest::binary>>, line, line_prefix, acc)
         when char in @whitespace do
      acc = [{unquote(String.to_existing_atom(kw)), line} | acc]
      tokenize_line(rest, line, line_prefix, acc)
    end

    defp tokenize_line(unquote(kw) <> _rest, line, _line_prefix, _acc) do
      {:error, line, "no space after '#{unquote(kw)}'"}
    end
  end

  # Comments.
  defp tokenize_line(<<?#, _rest::binary>> = rest, line, "", acc) do
    {contents, rest} = to_eol_or_eof(rest, "")
    acc = [{:comment, line, contents} | acc]
    tokenize_line(rest, line, "", acc)
  end

  # `msgstr`.
  defp tokenize_line("msgstr[" <> <<rest::binary>>, line, line_prefix, acc) do
    case tokenize_plural_form(rest, "") do
      {:ok, plural_form, rest} ->
        # The order of the :plural_form and :msgstr tokens is inverted since
        # the `acc` array of tokens will be reversed at the end.
        acc = [{:plural_form, line, plural_form}, {:msgstr, line} | acc]
        tokenize_line(rest, line, line_prefix, acc)

      {:error, reason} ->
        {:error, line, reason}
    end
  end

  defp tokenize_line("msgstr" <> <<char, rest::binary>>, line, line_prefix, acc)
       when char in @whitespace do
    acc = [{:msgstr, line} | acc]
    tokenize_line(rest, line, line_prefix, acc)
  end

  defp tokenize_line("msgstr" <> _rest, line, _line_prefix, _acc) do
    {:error, line, "no space after 'msgstr'"}
  end

  # String.
  defp tokenize_line(<<?", rest::binary>>, line, line_prefix, acc) do
    case tokenize_string(rest, "") do
      {:ok, string, rest} ->
        tokenize_line(rest, line, line_prefix, add_str_lines(line, string, acc))

      {:error, reason} ->
        {:error, line, reason}
    end
  end

  # Unknown keyword.
  # At this point, there has to be a syntax error. Here, since the first byte is
  # a letter (we don't take care of unicode ot fancy stuff, just ASCII letters),
  # we assume there's an unknown keyword. We parse it with a regex
  # (`next_word/1`) so that the error message is informative.
  defp tokenize_line(<<letter, _rest::binary>> = binary, line, _line_prefix, _acc)
       when letter in ?a..?z or letter in ?A..?Z do
    {:error, line, "unknown keyword '#{next_word(binary)}'"}
  end

  # Unknown token.
  # Last resort: this is just a plain unexpected token. We take the first
  # Unicode char of the given binary and build an informative error message
  # (with the codepoint of the char).
  defp tokenize_line(binary, line, _line_prefix, _acc) when is_binary(binary) do
    # To get the first Unicode char, we convert to char list first.
    [char | _] = String.to_charlist(binary)
    msg = :io_lib.format('unexpected token: "~ts" (codepoint U+~4.16.0B)', [[char], char])
    {:error, line, :unicode.characters_to_binary(msg)}
  end

  @obsolete_keywords ~w(msgid msgid_plural msgctxt msgstr)a

  defp add_str_lines(line, string, [{:str_lines, line, strings} | acc]) do
    [{:str_lines, line, [string | strings]} | acc]
  end

  defp add_str_lines(_line, string, [
         {:str_lines, line, strings},
         {keyword, _keyword_line} = keyword_token | acc
       ])
       when keyword in @obsolete_keywords do
    [{:str_lines, line, [string | strings]}, keyword_token | acc]
  end

  # strings after msgid msgid_plural msgctxt msgstr (singular)
  defp add_str_lines(_line, string, [
         {modifier, _new_modifier_line},
         {:str_lines, line, strings},
         {keyword, _keyword_line} = keyword_token,
         {modifier, _old_modifier_line} = modifier_token | acc
       ])
       when modifier in [:obsolete, :previous] and keyword in @obsolete_keywords do
    [{:str_lines, line, [string | strings]}, keyword_token, modifier_token | acc]
  end

  # strings after msgstr (plural)
  defp add_str_lines(_line, string, [
         {modifier, _new_modifier_line},
         {:str_lines, line, strings},
         {:plural_form, _plural_form_line, _plural_form} = plural_form_token,
         {:msgstr, _keyword_line} = keyword_token,
         {modifier, _old_modifier_line} = modifier_token | acc
       ])
       when modifier in [:obsolete, :previous] do
    [
      {:str_lines, line, [string | strings]},
      plural_form_token,
      keyword_token,
      modifier_token | acc
    ]
  end

  defp add_str_lines(line, string, acc) do
    [{:str_lines, line, [string]} | acc]
  end

  # Parses the double-quotes-delimited string `str` into a single string. Note
  # that `str` doesn't start with a double quote (since that was needed to
  # identify the start of a string). Note that the rest of the original string
  # doesn't include the closing double quote.
  @spec tokenize_string(binary, binary) :: {:ok, binary, binary} | {:error, binary}
  defp tokenize_string(str, acc)

  defp tokenize_string(<<?", rest::binary>>, acc), do: {:ok, acc, rest}

  defp tokenize_string(<<?\\, char, rest::binary>>, acc)
       when char in @escapable_chars,
       do: tokenize_string(rest, <<acc::binary, escape_char(char)>>)

  defp tokenize_string(<<?\\, _char, _rest::binary>>, _acc),
    do: {:error, "unsupported escape code"}

  defp tokenize_string(<<?\n, _rest::binary>>, _acc), do: {:error, "newline in string"}

  defp tokenize_string(<<char, rest::binary>>, acc),
    do: tokenize_string(rest, <<acc::binary, char>>)

  defp tokenize_string(<<>>, _acc), do: {:error, "missing token \""}

  @spec tokenize_plural_form(binary, binary) :: {:ok, non_neg_integer, binary} | {:error, binary}
  defp tokenize_plural_form(<<digit, rest::binary>>, acc) when digit in '0123456789' do
    tokenize_plural_form(rest, <<acc::binary, digit>>)
  end

  defp tokenize_plural_form(<<?], char, rest::binary>>, acc)
       when char in @whitespace and acc != <<>> do
    {:ok, String.to_integer(acc), rest}
  end

  defp tokenize_plural_form(<<?], _rest::binary>>, acc) when acc != <<>> do
    {:error, "missing space after 'msgstr[#{acc}]'"}
  end

  defp tokenize_plural_form(_binary, _acc) do
    {:error, "invalid plural form"}
  end

  @spec escape_char(char) :: char
  defp escape_char(?n), do: ?\n
  defp escape_char(?t), do: ?\t
  defp escape_char(?r), do: ?\r
  defp escape_char(?"), do: ?"
  defp escape_char(?\\), do: ?\\

  @spec to_eol_or_eof(binary, binary) :: {binary, binary}
  defp to_eol_or_eof(<<?\n, _rest::binary>> = rest, acc), do: {acc, rest}
  defp to_eol_or_eof(<<>>, acc), do: {acc, ""}
  defp to_eol_or_eof(<<char, rest::binary>>, acc), do: to_eol_or_eof(rest, <<acc::binary, char>>)

  @spec next_word(binary) :: binary
  defp next_word(binary), do: List.first(Regex.run(~r/\w+/u, binary))
end
