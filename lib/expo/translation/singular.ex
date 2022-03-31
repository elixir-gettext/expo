defmodule Expo.Translation.Singular do
  @moduledoc """
  Struct for non-plural translations
  """

  alias Expo.Translation
  alias Expo.Translation.Meta

  @type t :: %__MODULE__{
          msgid: Translation.msgid(),
          msgstr: Translation.msgstr(),
          msgctxt: Translation.msgctxt() | nil,
          comments: [String.t()],
          extracted_comments: [String.t()],
          flags: [[String.t()]],
          previous_msgids: [String.t()],
          references: [String.t()],
          obsolete: boolean(),
          meta: Meta.t()
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
    obsolete: false,
    meta: %Meta{}
  ]

  @spec key(t()) :: {String.t() | nil, String.t()}
  def key(%__MODULE__{msgctxt: msgctxt, msgid: msgid} = _translation),
    do: {IO.iodata_to_binary(msgctxt || []), IO.iodata_to_binary(msgid)}
end
