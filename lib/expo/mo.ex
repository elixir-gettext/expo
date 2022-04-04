defmodule Expo.Mo do
  @moduledoc """
  `.mo` file handler
  """

  alias Expo.Translations

  @type compose_opts :: [{:endianness, :little | :big}]

  @doc """
  Composes a `.mo` file from translations

  ### Examples

      iex> %Expo.Translations{
      ...>   headers: ["Last-Translator: Jane Doe"],
      ...>   translations: [
      ...>     %Expo.Translation.Singular{msgid: ["foo"], msgstr: ["bar"], comments: "A comment"}
      ...>   ]
      ...> }
      ...> |> Expo.Mo.compose()
      ...> |> IO.iodata_to_binary()
      <<222, 18, 4, 149, 0, 0, 0, 0, 2, 0, 0, 0, 28, 0, 0, 0, 44, 0, 0, 0, 0, 0, 0, 0,
        60, 0, 0, 0, 0, 0, 0, 0, 60, 0, 0, 0, 3, 0, 0, 0, 61, 0, 0, 0, 25, 0, 0, 0,
        65, 0, 0, 0, 3, 0, 0, 0, 91, 0, 0, 0, 0, 102, 111, 111, 0, 76, 97, 115, 116,
        45, 84, 114, 97, 110, 115, 108, 97, 116, 111, 114, 58, 32, 74, 97, 110, 101,
        32, 68, 111, 101, 0, 98, 97, 114, 0>>

  """
  @spec compose(translations :: Translations.t(), opts :: compose_opts()) :: iodata()
  defdelegate compose(content, opts \\ []), to: Expo.Mo.Composer

  @doc """
  Parse `.mo` file

  ### Examples

      iex> Expo.Mo.parse(<<0xDE120495::size(4)-unit(8),
      ...>   0::little-unsigned-integer-size(2)-unit(8),
      ...>   0::little-unsigned-integer-size(2)-unit(8),
      ...>   0::little-unsigned-integer-size(4)-unit(8),
      ...>   28::little-unsigned-integer-size(4)-unit(8),
      ...>   28::little-unsigned-integer-size(4)-unit(8),
      ...>   28::little-unsigned-integer-size(4)-unit(8),
      ...>   0::little-unsigned-integer-size(4)-unit(8)>>)
      {:ok, %Expo.Translations{headers: [], translations: []}}

  """
  @spec parse(content :: binary()) ::
          {:ok, Translations.t()}
          | {:error,
             :invalid_file
             | :invalid_header
             | {:unsupported_version, major :: non_neg_integer(), minor :: non_neg_integer()}}
  defdelegate parse(content), to: Expo.Mo.Parser
end
