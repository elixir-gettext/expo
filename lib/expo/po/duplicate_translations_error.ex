defmodule Expo.PO.DuplicateMessagesError do
  @moduledoc """
  An error raised when duplicate messages are detected.
  """

  alias Expo.Message
  alias Expo.Messages

  @type t :: %__MODULE__{
          file: Path.t() | nil,
          duplicates: [
            {message :: Message.t(), error_message :: String.t(), line :: pos_integer,
             original_line: pos_integer}
          ],
          catalogue: Messages.t()
        }

  defexception [:file, :duplicates, :catalogue]

  @impl Exception
  def message(%__MODULE__{file: file, duplicates: duplicates}) do
    file = if file, do: Path.relative_to_cwd(file)

    prefix = if file, do: [file, ":"], else: []

    fix_description =
      if file,
        do: ["Run mix expo.msguniq ", file, " to merge the duplicates"],
        else: "Run mix expo.msguniq with the input file to merge the duplicates"

    IO.iodata_to_binary([
      Enum.map(duplicates, fn {_message, error_message, new_line, _old_line} ->
        [prefix, Integer.to_string(new_line), ": ", error_message]
      end),
      "\n",
      fix_description
    ])
  end
end
