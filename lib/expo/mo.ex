defmodule Expo.Mo do
  @moduledoc """
  `.mo` file handler
  """

  alias Expo.Mo.InvalidFileError
  alias Expo.Mo.Parser
  alias Expo.Mo.UnsupportedVersionError
  alias Expo.Translations

  @type compose_opts :: [{:endianness, :little | :big}]

  @type invalid_file_error :: {:error, :invalid_file}
  @type unsupported_version_error ::
          {:error, {:unsupported_version, major :: non_neg_integer(), minor :: non_neg_integer()}}
  @type file_error :: {:error, File.posix()}

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

      iex> Expo.Mo.parse_binary(<<0xDE120495::size(4)-unit(8),
      ...>   0::little-unsigned-integer-size(2)-unit(8),
      ...>   0::little-unsigned-integer-size(2)-unit(8),
      ...>   0::little-unsigned-integer-size(4)-unit(8),
      ...>   28::little-unsigned-integer-size(4)-unit(8),
      ...>   28::little-unsigned-integer-size(4)-unit(8),
      ...>   28::little-unsigned-integer-size(4)-unit(8),
      ...>   0::little-unsigned-integer-size(4)-unit(8)>>)
      {:ok, %Expo.Translations{headers: [], translations: []}}

  """
  @spec parse_binary(content :: binary()) ::
          {:ok, Translations.t()}
          | invalid_file_error()
          | unsupported_version_error()
  def parse_binary(content), do: Parser.parse(content)

  @doc """
  Parses a string into a `Expo.Translations` struct, raising an exception if there are
  any errors.

  Works exactly like `parse_binary/1`, but returns a `Expo.Translations` struct
  if there are no errors or raises a `Expo.Mo.InvalidFileError` error if there
  are.

  If the version of the `.mo` file is not supported, a
  `Expo.Mo.UnsupportedVersionError` is raised.

  ## Examples

      iex> Expo.Mo.parse_binary!(<<0xDE120495::size(4)-unit(8),
      ...>   0::little-unsigned-integer-size(2)-unit(8),
      ...>   0::little-unsigned-integer-size(2)-unit(8),
      ...>   0::little-unsigned-integer-size(4)-unit(8),
      ...>   28::little-unsigned-integer-size(4)-unit(8),
      ...>   28::little-unsigned-integer-size(4)-unit(8),
      ...>   28::little-unsigned-integer-size(4)-unit(8),
      ...>   0::little-unsigned-integer-size(4)-unit(8)>>)
      %Expo.Translations{headers: [], translations: []}

      iex> Expo.Mo.parse_binary!("invalid")
      ** (Expo.Mo.InvalidFileError) invalid file

  """
  @spec parse_binary!(content :: binary()) :: Translations.t() | no_return
  def parse_binary!(str) do
    case parse_binary(str) do
      {:ok, parsed} ->
        parsed

      {:error, :invalid_file} ->
        raise InvalidFileError

      {:error, {:unsupported_version, major, minor}} ->
        raise UnsupportedVersionError, major: major, minor: minor
    end
  end

  @doc """
  Parses the contents of a file into a `Expo.Translations` struct.

  This function works similarly to `parse_binary/1` except that it takes a file
  and parses the contents of that file. It can return:

    * `{:ok, po}`
    * `{:error, line, reason}` if there is an error with the contents of the
      `.po` file (for example, a syntax error)
    * `{:error, reason}` if there is an error with reading the file (this error
      is one of the errors that can be returned by `File.read/1`)

  ## Examples

      {:ok, po} = Expo.Mo.parse_file "translations.po"
      po.file
      #=> "translations.po"

      Expo.Mo.parse_file "nonexistent"
      #=> {:error, :enoent}

  """
  @spec parse_file(path :: Path.t()) ::
          {:ok, Translations.t()}
          | invalid_file_error()
          | unsupported_version_error()
          | file_error()
  def parse_file(path) do
    with {:ok, contents} <- File.read(path),
         {:ok, po} <- Parser.parse(contents, file: path) do
      {:ok, %{po | file: path}}
    end
  end

  @doc """
  Parses the contents of a file into a `Expo.Translations` struct, raising if there
  are any errors.

  Works like `parse_file/1`, except that it raises a `Expo.Mo.SyntaxError`
  exception if there's a syntax error in the file or a `File.Error` error if
  there's an error with reading the file.

  ## Examples

      Expo.Mo.parse_file! "nonexistent.po"
      #=> ** (File.Error) could not parse "nonexistent.po": no such file or directory

  """
  @spec parse_file!(Path.t()) :: Translations.t() | no_return
  def parse_file!(path) do
    case parse_file(path) do
      {:ok, parsed} ->
        parsed

      {:error, :invalid_file} ->
        raise InvalidFileError, file: path

      {:error, {:unsupported_version, major, minor}} ->
        raise UnsupportedVersionError, major: major, minor: minor, file: path

      {:error, reason} ->
        raise File.Error, reason: reason, action: "parse", path: path
    end
  end
end
