defmodule Expo.Mo.UnsupportedVersionError do
  @moduledoc """
  An error raised when the version of the mo file is not supported.
  """

  defexception [:message]

  @impl Exception
  def exception(opts) do
    major = Keyword.fetch!(opts, :major)
    minor = Keyword.fetch!(opts, :minor)

    reason = "invalid version, only ~> 0.0 is supported, #{major}.#{minor} given"

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
