defmodule Expo.Translation.Plural do
  @moduledoc """
  Struct for plural translations
  """

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

  @spec key(t()) :: {String.t() | nil, String.t(), String.t()}
  def key(%__MODULE__{msgctxt: msgctxt, msgid: msgid, msgid_plural: msgid_plural} = _translation),
    do:
      {IO.iodata_to_binary(msgctxt || []), IO.iodata_to_binary(msgid),
       IO.iodata_to_binary(msgid_plural)}
end
