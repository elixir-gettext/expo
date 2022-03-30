defmodule Expo.Translation.Singular do
  @moduledoc """
  Struct for non-plural translations
  """

  alias Expo.Translation

  @type t :: %__MODULE__{
          msgid: Translation.msgid(),
          msgstr: Translation.msgstr(),
          msgctx: Translation.msgctx() | nil,
          comments: [String.t()],
          extracted_comments: [String.t()],
          flags: MapSet.t(String.t()),
          previous_msgids: [String.t()],
          references: [String.t()]
        }

  @enforce_keys [:msgid, :msgstr]
  defstruct [
    :msgid,
    :msgstr,
    msgctx: nil,
    comments: [],
    extracted_comments: [],
    flags: MapSet.new(),
    previous_msgids: [],
    references: []
  ]
end
