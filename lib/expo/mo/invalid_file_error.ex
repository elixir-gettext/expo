defmodule Expo.MO.InvalidFileError do
  @moduledoc """
  An error raised when the content does not follow the MO file structure.
  """

  defexception [:message]

  @impl Exception
  def exception(opts) do
    reason = "invalid file"

    msg =
      if file = opts[:file] do
        file = Path.relative_to_cwd(file)
        "#{file}: #{reason}"
      else
        reason
      end

    %__MODULE__{message: msg}
  end
end
