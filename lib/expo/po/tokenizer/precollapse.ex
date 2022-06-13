defmodule Expo.Po.Tokenizer.Precollapse do
  @moduledoc false

  alias Expo.Po.Tokenizer

  @spec precollapse_strings(tokens :: [Tokenizer.token()]) :: [
          Tokenizer.token() | {:str_lines, Tokenizer.line(), [[String.t()]]}
        ]
  def precollapse_strings(tokens) do
    tokens
    |> precollapse_strings_on_same_line([])
    |> precollapse_multiple_string_lines([])
  end

  # Collapse multiple strings into one if they are on the same line
  #
  # [{:str, 1, "1"}, {:str, 1, "2"}] => [{:strs, 1, ["1", "2"]}]
  # [{:str, 1, "1"}, {:str, 2, "2"}] => [{:strs, 1, ["1"]}, {:strs, 2, ["2"]}]
  defp precollapse_strings_on_same_line(next_tokens, acc)

  defp precollapse_strings_on_same_line([{:str, line, new_content} | rest], [
         {:strs, line, old_content} | acc
       ]),
       do:
         precollapse_strings_on_same_line(rest, [{:strs, line, [new_content | old_content]} | acc])

  defp precollapse_strings_on_same_line([{:str, line, content} | rest], acc),
    do: precollapse_strings_on_same_line(rest, [{:strs, line, [content]} | acc])

  defp precollapse_strings_on_same_line([token | rest], acc),
    do: precollapse_strings_on_same_line(rest, [token | acc])

  defp precollapse_strings_on_same_line([], acc),
    do:
      acc
      |> Enum.map(&reverse_strings/1)
      |> Enum.reverse()

  # Collapse multiple String Lines into one if the same modifiers apply
  defp precollapse_multiple_string_lines(next_tokens, acc)

  for modifier <- [:obsolete, :previous], keyword <- [:msgid, :msgid_plural, :msgctxt, :msgstr] do
    defp precollapse_multiple_string_lines(
           [{unquote(modifier), _new_modifier_line}, {:strs, _new_line, new_content} | rest],
           [
             {:str_lines, old_line, old_content},
             {unquote(keyword), _keyword_line} = keyword_token,
             {unquote(modifier), _old_modifier_line} = modifier_token | acc
           ]
         ) do
      precollapse_multiple_string_lines(rest, [
        {:str_lines, old_line, old_content ++ new_content},
        keyword_token,
        modifier_token | acc
      ])
    end
  end

  for keyword <- [:msgid, :msgid_plural, :msgctxt, :msgstr] do
    defp precollapse_multiple_string_lines(
           [{:strs, _new_line, new_content} | rest],
           [
             {:str_lines, old_line, old_content},
             {unquote(keyword), _keyword_line} = keyword_token | acc
           ]
         ) do
      precollapse_multiple_string_lines(rest, [
        {:str_lines, old_line, old_content ++ new_content},
        keyword_token | acc
      ])
    end
  end

  defp precollapse_multiple_string_lines([{:strs, line, content} | rest], acc) do
    precollapse_multiple_string_lines(rest, [{:str_lines, line, content} | acc])
  end

  defp precollapse_multiple_string_lines([token | rest], acc),
    do: precollapse_multiple_string_lines(rest, [token | acc])

  defp precollapse_multiple_string_lines([], acc),
    do: Enum.reverse(acc)

  defp reverse_strings(token)
  defp reverse_strings({:strs, line, content}), do: {:strs, line, Enum.reverse(content)}
  defp reverse_strings(token), do: token
end
