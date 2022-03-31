defmodule Expo.Translation.Meta do
  @moduledoc false

  @type t :: %__MODULE__{
          msgctxt_source_line: pos_integer() | nil,
          msgid_source_line: pos_integer() | nil,
          msgid_plural_source_line: pos_integer() | nil,
          msgstr_source_line: pos_integer() | nil
        }

  defstruct msgctxt_source_line: nil,
            msgid_source_line: nil,
            msgid_plural_source_line: nil,
            msgstr_source_line: nil
end
