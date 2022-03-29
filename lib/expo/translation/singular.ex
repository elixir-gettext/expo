defmodule Expo.Translation.Singular do
  @moduledoc """
  Struct for non-plural translations
  """

  alias Expo.Translation

  @type t :: %__MODULE__{
          msgid: Translation.msgid(),
          msgstr: Translation.msgstr(),
          context: Translation.msgctx() | nil
        }

  @enforce_keys [:msgid, :msgstr]
  defstruct [:msgid, :msgstr, context: nil]
end
