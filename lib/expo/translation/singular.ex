defmodule Expo.Translation.Singular do
  @moduledoc """
  Struct for non-plural translations
  """

  alias Expo.Parser.Util
  alias Expo.Translation

  @type t :: %__MODULE__{
          msgid: Translation.msgid(),
          msgstr: Translation.msgstr(),
          msgctxt: Translation.msgctxt() | nil,
          comments: [String.t()],
          extracted_comments: [String.t()],
          flags: [[String.t()]],
          previous_msgids: [[String.t()]],
          references: [[file :: String.t() | {file :: String.t(), line :: pos_integer()}]],
          obsolete: boolean()
        }

  @enforce_keys [:msgid, :msgstr]
  defstruct [
    :msgid,
    :msgstr,
    msgctxt: nil,
    comments: [],
    extracted_comments: [],
    flags: [],
    previous_msgids: [],
    references: [],
    obsolete: false
  ]

  @spec key(t()) :: {String.t() | nil, String.t()}
  def key(%__MODULE__{msgctxt: msgctxt, msgid: msgid} = _translation),
    do: {IO.iodata_to_binary(msgctxt || []), IO.iodata_to_binary(msgid)}

  @doc """
  Rebalances all strings

  * Put one string per newline of `msgid` / `msgstr`
  * Put all flags onto one line
  * Put all references onto a separate line

  ### Examples

      iex> Expo.Translation.Singular.rebalance(%Expo.Translation.Singular{
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
  @spec rebalance(translation :: t()) :: t()
  def rebalance(
        %__MODULE__{
          msgid: msgid,
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
        msgstr: Util.rebalance_strings(msgstr),
        flags: flags,
        references: references |> List.flatten() |> Enum.map(&List.wrap/1)
    }
  end
end
