defmodule Expo.Translation.Plural do
  @moduledoc """
  Struct for plural translations
  """

  alias Expo.Translation

  @type t :: %__MODULE__{
          msgid: Translation.msgid(),
          msgid_plural: [Translation.msgid()],
          msgstr: %{required(non_neg_integer()) => Translation.msgstr()},
          msgctx: Translation.msgctx() | nil,
          comments: [String.t()],
          extracted_comments: [String.t()],
          flags: MapSet.t(String.t()),
          previous_msgids: [String.t()],
          references: [String.t()]
        }

  @enforce_keys [:msgid, :msgid_plural, :msgstr]
  defstruct [
    :msgid,
    :msgid_plural,
    :msgstr,
    msgctx: nil,
    comments: [],
    extracted_comments: [],
    flags: MapSet.new(),
    previous_msgids: [],
    references: []
  ]
end
