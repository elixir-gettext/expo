defmodule Expo.Translation.Plural do
  @moduledoc """
  Struct for plural translations
  """

  alias Expo.Translation

  @type t :: %__MODULE__{
          msgid: Translation.msgid(),
          msgid_plural: [Translation.msgid()],
          msgstr: %{required(non_neg_integer()) => Translation.msgstr()},
          context: Translation.msgctx() | nil
        }

  @enforce_keys [:msgid, :msgid_plural, :msgstr]
  defstruct [:msgid, :msgid_plural, :msgstr, context: nil]
end
