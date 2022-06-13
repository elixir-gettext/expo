defmodule Expo.Messages do
  @moduledoc """
  Message List Struct for mo / po files
  """

  alias Expo.Message
  alias Expo.Util

  @type t :: %__MODULE__{
          headers: [String.t()],
          top_comments: [[String.t()]],
          messages: [Message.t()],
          file: nil | Path.t()
        }

  @enforce_keys [:messages]
  defstruct headers: [], messages: [], top_comments: [], file: nil

  @doc """
  Rebalances all strings

  * All headers (see `Expo.Message.Singular.rebalance/1` / `Expo.Message.Plural.rebalance/1`)
  * Put one string per newline of `headers` and add one empty line at start

  ### Examples

      iex> Expo.Messages.rebalance(%Expo.Messages{
      ...>   headers: ["", "hello", "\\n", "", "world", ""],
      ...>   messages: [%Expo.Message.Singular{
      ...>     msgid: ["", "hello", "\\n", "", "world", ""],
      ...>     msgstr: ["", "hello", "\\n", "", "world", ""]
      ...>   }]
      ...> })
      %Expo.Messages{
        headers: ["", "hello\\n", "world"],
        messages: [%Expo.Message.Singular{
          msgid: ["hello\\n", "world"],
          msgstr: ["hello\\n", "world"]
        }]
      }

  """
  @spec rebalance(message :: t()) :: t()
  def rebalance(
        %__MODULE__{headers: headers, messages: all_messages, top_comments: top_comments} =
          messages
      ) do
    {headers, top_comments, all_messages} =
      headers
      |> Util.inject_meta_headers(top_comments, all_messages)
      |> Enum.map(fn %struct{} = message -> struct.rebalance(message) end)
      |> Util.extract_meta_headers()

    headers =
      case headers do
        [] -> []
        headers -> ["" | headers]
      end

    %__MODULE__{
      messages
      | headers: headers,
        top_comments: top_comments,
        messages: all_messages
    }
  end

  @doc """
  Get Header by name (case insensitive)

  ### Examples

      iex> messages = %Expo.Messages{headers: ["Language: en_US\\n"], messages: []}
      iex> Expo.Messages.get_header(messages, "language")
      ["en_US"]

      iex> messages = %Expo.Messages{headers: ["Language: en_US\\n"], messages: []}
      iex> Expo.Messages.get_header(messages, "invalid")
      []

  """
  @spec get_header(messages :: t(), header_name :: String.t()) :: [String.t()]
  def get_header(%__MODULE__{headers: headers}, header_name) do
    header_name_match = Regex.escape(header_name)
    escaped_newline = Regex.escape("\\\n")

    ~r/
      # Start of line
      ^
      # Header Name
      (?<header>
        #{header_name_match}
      ):
      # Ignore Whitespace
      \s
      (?<content>
        (
          # Allow an escaped newline in content
          #{escaped_newline}
          |
          # Allow everything except a newline in content
          [^\n]
        )*
      )
      # Header must end with newline or end of string
      (\n|\z)
    /imx
    |> Regex.scan(IO.iodata_to_binary(headers), capture: ["content"])
    |> Enum.map(fn [content] -> content end)
  end

  @doc """
  Finds a given message in a list of messages.

  Equality between messages is checked using `Expo.Message.same?/2`.
  """
  def find(messages, search_message)

  @spec find(messages :: [Message.t()], search_message :: Message.t()) ::
          Message.t() | nil
  def find(messages, search_message) when is_list(messages),
    do: Enum.find(messages, &Message.same?(&1, search_message))

  @spec find(messages :: t(), search_message :: Message.t()) ::
          Message.t() | nil
  def find(%__MODULE__{messages: messages}, search_message),
    do: find(messages, search_message)
end
