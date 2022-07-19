defmodule Expo.Message do
  @moduledoc """
  Message Structs
  """

  alias Expo.Message.Plural
  alias Expo.Message.Singular

  @type msgid :: [String.t()]
  @type msgstr :: [String.t()]
  @type msgctxt :: String.t()

  @type t :: Singular.t() | Plural.t()

  @typedoc """
  key that can be used to identify a message
  """
  @opaque key ::
            {msgctxt :: String.t(),
             (msgid :: String.t()) | {msgid :: String.t(), msgid_plural :: String.t()}}

  @doc """
  Returns a "key" that can be used to identify a message.

  This function returns a "key" that can be used to uniquely identify a
  message assuming that no "same" messages exist; for what "same"
  means, look at the documentation for `same?/2`.

  The purpose of this function is to be used in situations where we'd like to
  group or sort messages but where we don't need the whole structs.

  ## Examples

      iex> t1 = %Expo.Message.Singular{msgid: ["foo"]}
      iex> t2 = %Expo.Message.Singular{msgid: ["", "foo"]}
      iex> Expo.Message.key(t1) == Expo.Message.key(t2)
      true

      iex> t1 = %Expo.Message.Singular{msgid: ["foo"]}
      iex> t2 = %Expo.Message.Singular{msgid: ["bar"]}
      iex> Expo.Message.key(t1) == Expo.Message.key(t2)
      false

  """
  @spec key(message :: t()) :: key()
  def key(message)
  def key(%Singular{} = message), do: Singular.key(message)
  def key(%Plural{} = message), do: Plural.key(message)

  @doc """
  Tells whether two messages are the same message according to their
  `msgid`.

  This function returns `true` if `message1` and `message2` are the same
  message, where "the same" means they have the same `msgid` or the same
  `msgid` and `msgid_plural`.

  ## Examples

      iex> t1 = %Expo.Message.Singular{msgid: ["foo"]}
      iex> t2 = %Expo.Message.Singular{msgid: ["", "foo"]}
      iex> Expo.Message.same?(t1, t2)
      true

      iex> t1 = %Expo.Message.Singular{msgid: ["foo"]}
      iex> t2 = %Expo.Message.Singular{msgid: ["bar"]}
      iex> Expo.Message.same?(t1, t2)
      false

  """
  @spec same?(message1 :: t(), message2 :: t()) :: boolean
  def same?(message1, message2), do: key(message1) == key(message2)

  @doc """
  Tells whether the given message has the flag specified

  ### Examples

      iex> Expo.Message.has_flag?(%Expo.Message.Singular{msgid: [], flags: [["foo"]]}, "foo")
      true

      iex> Expo.Message.has_flag?(%Expo.Message.Singular{msgid: [], flags: [["foo"]]}, "bar")
      false

  """
  @spec has_flag?(message :: t(), flag :: String.t()) :: boolean()
  def has_flag?(message, flag)
  def has_flag?(%Singular{flags: flags}, flag), do: flag in List.flatten(flags)
  def has_flag?(%Plural{flags: flags}, flag), do: flag in List.flatten(flags)

  @doc """
  Append flag to message

  Keeps the line formatting intact

  ### Examples

      iex> message = %Expo.Message.Singular{msgid: [], flags: []}
      iex> Expo.Message.append_flag(message, "foo")
      %Expo.Message.Singular{msgid: [], flags: [["foo"]]}
  """
  @spec append_flag(message :: t(), flag :: String.t()) :: t()
  def append_flag(message, flag)

  def append_flag(%Singular{flags: flags} = message, flag),
    do: %Singular{message | flags: _append_flag(flags, flag)}

  def append_flag(%Plural{flags: flags} = message, flag),
    do: %Plural{message | flags: _append_flag(flags, flag)}

  defp _append_flag(flags, flag) do
    if flag in List.flatten(flags) do
      flags
    else
      case flags do
        [] -> [[flag]]
        [flag_line] -> [flag_line ++ [flag]]
        _multiple_lines -> flags ++ [[flag]]
      end
    end
  end

  @doc """
  Get Source Line Number of statement

  ## Examples

      iex> %Expo.Messages{messages: [message]} = Expo.Po.parse_string!(\"""
      ...> msgid "foo"
      ...> msgstr "bar"
      ...> \""")
      iex> Expo.Message.source_line_number(message, :msgid)
      1

  """
  @spec source_line_number(message :: Singular.t(), block :: Singular.block(), default :: default) ::
          non_neg_integer() | default
        when default: term

  @spec source_line_number(message :: Plural.t(), block :: Plural.block(), default :: default) ::
          non_neg_integer() | default
        when default: term

  def source_line_number(message, block, default \\ nil)

  def source_line_number(%Singular{} = message, block, default),
    do: Singular.source_line_number(message, block, default)

  def source_line_number(%Plural{} = message, block, default),
    do: Plural.source_line_number(message, block, default)
end
