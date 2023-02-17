defmodule Expo.Message.Singular do
  @moduledoc """
  Struct for non-plural messages.

  For example:

      ```
      msgid "Hello"
      msgstr ""
      ```

  All fields in this struct are public except for `:__meta__`. The `:flags` and `:references`
  fields are defined as lists of lists in order to represent **lines** in the original file. For
  example, this message:

      ```
      #, flag1, flag2
      #, flag3
      #: a.ex:1
      #: b.ex:2 c.ex:3
      msgid "Hello"
      msgstr ""
      ```

  would have:

    * `flags: [["flag1", "flag2"], ["flag3"]]`
    * `references: [["a.ex:1"], ["b.ex:2", "c.ex:3"]]`

  You can use `Expo.Message.has_flag?/2` to make it easier to check whether a message
  has a given flag.
  """

  alias Expo.Message
  alias Expo.Util

  @type block :: :msgid | :msgstr | :msgctxt

  @opaque meta :: %{optional(:source_line) => %{block() => non_neg_integer()}}

  @type t :: %__MODULE__{
          msgid: Message.msgid(),
          msgstr: Message.msgstr(),
          msgctxt: Message.msgctxt() | nil,
          comments: [String.t()],
          extracted_comments: [String.t()],
          flags: [[String.t()]],
          previous_messages: [Message.t()],
          references: [[file :: String.t() | {file :: String.t(), line :: pos_integer()}]],
          obsolete: boolean(),
          __meta__: meta()
        }

  @enforce_keys [:msgid]
  @derive {Inspect, except: [:__meta__]}
  defstruct [
    :msgid,
    msgstr: [""],
    msgctxt: nil,
    comments: [],
    extracted_comments: [],
    flags: [],
    previous_messages: [],
    references: [],
    obsolete: false,
    __meta__: %{}
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
  @spec rebalance(t()) :: t()
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

  @doc """
  Get the source line number of the message.

  ## Examples

      iex> %Expo.Messages{messages: [message]} = Expo.PO.parse_string!(\"""
      ...> msgid "foo"
      ...> msgstr "bar"
      ...> \""")
      iex> Expo.Message.Singular.source_line_number(message, :msgid)
      1

  """
  @spec source_line_number(t(), block(), default) :: non_neg_integer() | default
        when default: term()
  def source_line_number(%__MODULE__{__meta__: meta} = _message, block, default \\ nil) do
    meta[:source_line][block] || default
  end
end
