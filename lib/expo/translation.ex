defmodule Expo.Translation do
  @moduledoc """
  Translation Structs
  """

  alias Expo.Translation.Plural
  alias Expo.Translation.Singular

  @type msgid :: [String.t()]
  @type msgstr :: [String.t()]
  @type msgctxt :: String.t()

  @type t :: Singular.t() | Plural.t()

  @typedoc """
  key that can be used to identify a translation
  """
  @opaque key ::
            {msgctxt :: String.t(),
             (msgid :: String.t()) | {msgid :: String.t(), msgid_plural :: String.t()}}

  @doc """
  Returns a "key" that can be used to identify a translation.

  This function returns a "key" that can be used to uniquely identify a
  translation assuming that no "same" translations exist; for what "same"
  means, look at the documentation for `same?/2`.

  The purpose of this function is to be used in situations where we'd like to
  group or sort translations but where we don't need the whole structs.

  ## Examples

      iex> t1 = %Expo.Translation.Singular{msgid: ["foo"], msgstr: []}
      iex> t2 = %Expo.Translation.Singular{msgid: ["", "foo"], msgstr: []}
      iex> Expo.Translation.key(t1) == Expo.Translation.key(t2)
      true

      iex> t1 = %Expo.Translation.Singular{msgid: ["foo"], msgstr: []}
      iex> t2 = %Expo.Translation.Singular{msgid: ["bar"], msgstr: []}
      iex> Expo.Translation.key(t1) == Expo.Translation.key(t2)
      false

  """
  @spec key(translation :: t()) :: key()
  def key(translation)
  def key(%Singular{} = translation), do: Singular.key(translation)
  def key(%Plural{} = translation), do: Plural.key(translation)

  @doc """
  Tells whether two translations are the same translation according to their
  `msgid`.

  This function returns `true` if `translation1` and `translation2` are the same
  translation, where "the same" means they have the same `msgid` or the same
  `msgid` and `msgid_plural`.

  ## Examples

      iex> t1 = %Expo.Translation.Singular{msgid: ["foo"], msgstr: []}
      iex> t2 = %Expo.Translation.Singular{msgid: ["", "foo"], msgstr: []}
      iex> Expo.Translation.same?(t1, t2)
      true

      iex> t1 = %Expo.Translation.Singular{msgid: ["foo"], msgstr: []}
      iex> t2 = %Expo.Translation.Singular{msgid: ["bar"], msgstr: []}
      iex> Expo.Translation.same?(t1, t2)
      false

  """
  @spec same?(translation1 :: t(), translation2 :: t()) :: boolean
  def same?(translation1, translation2), do: key(translation1) == key(translation2)

  @doc """
  Tells whether the given translation has the flag specified

  ### Examples

      iex> Expo.Translation.has_flag?(%Expo.Translation.Singular{msgid: [], msgstr: [], flags: [["foo"]]}, "foo")
      true

      iex> Expo.Translation.has_flag?(%Expo.Translation.Singular{msgid: [], msgstr: [], flags: [["foo"]]}, "bar")
      false

  """
  @spec has_flag?(translation :: t(), flag :: String.t()) :: boolean()
  def has_flag?(translation, flag)
  def has_flag?(%Singular{flags: flags}, flag), do: flag in List.flatten(flags)
  def has_flag?(%Plural{flags: flags}, flag), do: flag in List.flatten(flags)

  @doc """
  Append flag to translation

  Keeps the line formatting intact

  ### Examples

      iex> translation = %Expo.Translation.Singular{msgid: [], msgstr: [], flags: []}
      iex> Expo.Translation.append_flag(translation, "foo")
      %Expo.Translation.Singular{msgid: [], msgstr: [], flags: [["foo"]]}
  """
  @spec append_flag(translation :: t(), flag :: String.t()) :: t()
  def append_flag(translation, flag)

  def append_flag(%Singular{flags: flags} = translation, flag),
    do: %Singular{translation | flags: _append_flag(flags, flag)}

  def append_flag(%Plural{flags: flags} = translation, flag),
    do: %Plural{translation | flags: _append_flag(flags, flag)}

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
end
