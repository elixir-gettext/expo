defmodule Expo.Translation.Plural do
  @moduledoc """
  Struct for plural translations
  """

  alias Expo.Parser.Util
  alias Expo.Translation

  @type t :: %__MODULE__{
          msgid: Translation.msgid(),
          msgid_plural: [Translation.msgid()],
          msgstr: %{required(non_neg_integer()) => Translation.msgstr()},
          msgctxt: Translation.msgctxt() | nil,
          comments: [String.t()],
          extracted_comments: [String.t()],
          flags: [[String.t()]],
          previous_msgids: [[String.t()]],
          references: [[file :: String.t() | {file :: String.t(), line :: pos_integer()}]],
          obsolete: boolean()
        }

  @enforce_keys [:msgid, :msgid_plural, :msgstr]
  defstruct [
    :msgid,
    :msgid_plural,
    :msgstr,
    msgctxt: nil,
    comments: [],
    extracted_comments: [],
    flags: [],
    previous_msgids: [],
    references: [],
    obsolete: false
  ]

  @doc false
  @spec key(t()) :: {String.t() | nil, String.t(), String.t()}
  def key(%__MODULE__{msgctxt: msgctxt, msgid: msgid, msgid_plural: msgid_plural} = _translation),
    do:
      {IO.iodata_to_binary(msgctxt || []), IO.iodata_to_binary(msgid),
       IO.iodata_to_binary(msgid_plural)}

  @doc """
  Rebalances all strings

  * Put one string per newline of `msgid` / `msgid_plural` / `msgstr`
  * Put all flags onto one line
  * Put all references onto a separate line

  ### Examples

      iex> Expo.Translation.Plural.rebalance(%Expo.Translation.Plural{
      ...>   msgid: ["", "hello", "\\n", "", "world", ""],
      ...>   msgid_plural: ["", "hello", "\\n", "", "world", ""],
      ...>   msgstr: %{0 => ["", "hello", "\\n", "", "world", ""]},
      ...>   flags: [["one", "two"], ["three"]],
      ...>   references: [[{"one", 1}, {"two", 2}], ["three"]]
      ...> })
      %Plural{
        msgid: ["hello\\n", "world"],
        msgid_plural: ["hello\\n", "world"],
        msgstr: %{0 => ["hello\\n", "world"]},
        flags: [["one", "two", "three"]],
        references: [[{"one", 1}], [{"two", 2}], ["three"]]
      }

  """
  @spec rebalance(translation :: t()) :: t()
  def rebalance(
        %__MODULE__{
          msgid: msgid,
          msgid_plural: msgid_plural,
          msgstr: msgstr,
          flags: flags,
          references: references
        } = translation
      ) do
    flags =
      case List.flatten(flags) do
        [] -> []
        flags -> [flags]
      end

    %__MODULE__{
      translation
      | msgid: Util.rebalance_strings(msgid),
        msgid_plural: Util.rebalance_strings(msgid_plural),
        msgstr:
          Map.new(msgstr, fn {index, strings} -> {index, Util.rebalance_strings(strings)} end),
        flags: flags,
        references: references |> List.flatten() |> Enum.map(&List.wrap/1)
    }
  end
end
