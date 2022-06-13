defmodule Expo.Message.Singular do
  @moduledoc """
  Struct for non-plural messages
  """

  alias Expo.Message
  alias Expo.Util

  @type t :: %__MODULE__{
          msgid: Message.msgid(),
          msgstr: Message.msgstr(),
          msgctxt: Message.msgctxt() | nil,
          comments: [String.t()],
          extracted_comments: [String.t()],
          flags: [[String.t()]],
          previous_messages: [Message.t()],
          references: [[file :: String.t() | {file :: String.t(), line :: pos_integer()}]],
          obsolete: boolean()
        }

  @enforce_keys [:msgid]
  defstruct [
    :msgid,
    msgstr: [],
    msgctxt: nil,
    comments: [],
    extracted_comments: [],
    flags: [],
    previous_messages: [],
    references: [],
    obsolete: false
  ]

  @spec key(t()) :: {String.t(), String.t()}
  def key(%__MODULE__{msgctxt: msgctxt, msgid: msgid} = _message),
    do: {IO.iodata_to_binary(msgctxt || []), IO.iodata_to_binary(msgid)}

  @doc """
  Rebalances all strings

  * Put one string per newline of `msgid` / `msgstr`
  * Put all flags onto one line
  * Put all references onto a separate line

  ### Examples

      iex> Expo.Message.Singular.rebalance(%Expo.Message.Singular{
      ...>   msgid: ["", "hello", "\\n", "", "world", ""],
      ...>   msgstr: ["", "hello", "\\n", "", "world", ""],
      ...>   flags: [["one", "two"], ["three"]],
      ...>   references: [[{"one", 1}, {"two", 2}], ["three"]]
      ...> })
      %Singular{
        msgid: ["hello\\n", "world"],
        msgstr: ["hello\\n", "world"],
        flags: [["one", "two", "three"]],
        references: [[{"one", 1}], [{"two", 2}], ["three"]]
      }

  """
  @spec rebalance(message :: t()) :: t()
  def rebalance(
        %__MODULE__{
          msgid: msgid,
          msgstr: msgstr,
          flags: flags,
          references: references
        } = message
      ) do
    flags =
      case List.flatten(flags) do
        [] -> []
        flags -> [flags]
      end

    %__MODULE__{
      message
      | msgid: Util.rebalance_strings(msgid),
        msgstr: Util.rebalance_strings(msgstr),
        flags: flags,
        references: references |> List.flatten() |> Enum.map(&List.wrap/1)
    }
  end
end
