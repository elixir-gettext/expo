defmodule Expo.PluralForms.SyntaxError do
  @moduledoc """
  An error raised when the syntax in a Plural Forms String isn't correct.
  """

  defexception [:message]

  @impl Exception
  def exception(opts) do
    line = Keyword.fetch!(opts, :line)
    offset = Keyword.fetch!(opts, :offset)
    reason = Keyword.fetch!(opts, :reason)

    msg = "#{line}:#{offset} #{reason}"

    %__MODULE__{message: msg}
  end
end
