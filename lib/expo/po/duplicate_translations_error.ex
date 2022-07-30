defmodule Expo.PO.DuplicateMessagesError do
  @moduledoc """
  An error raised when duplicate messages are detected.
  """

  defexception [:message]

  defp location(file, line)
  defp location(nil, line), do: "#{line}"
  defp location(file, line), do: "#{Path.relative_to_cwd(file)}:#{line}"

  @impl Exception
  def exception(opts) do
    file = Keyword.get(opts, :file)

    message =
      opts
      |> Keyword.fetch!(:duplicates)
      |> Enum.map(fn {message, new_line, _old_line} ->
        "#{location(file, new_line)}: #{message}"
      end)
      |> Enum.join("\n")

    %__MODULE__{message: message}
  end
end
