defmodule Expo.Po.SyntaxError do
  @moduledoc """
  An error raised when the syntax in a PO file (a file ending in `.po`) isn't
  correct.
  """

  defexception [:message]

  @impl Exception
  def exception(opts) do
    line = Keyword.fetch!(opts, :line)
    reason = Keyword.fetch!(opts, :reason)

    msg =
      if file = opts[:file] do
        file = Path.relative_to_cwd(file)
        "#{file}:#{line}: #{reason}"
      else
        "#{line}: #{reason}"
      end

    %__MODULE__{message: msg}
  end
end
