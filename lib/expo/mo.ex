defmodule Expo.MO do
  @moduledoc """
  File handling for MO (`.mo`) files.
  """

  alias Expo.Messages
  alias Expo.MO.{InvalidFileError, Parser, UnsupportedVersionError}

  @type compose_options :: [
          {:endianness, :little | :big},
          {:use_fuzzy, boolean()},
          {:statistics, boolean()}
        ]

  @type parse_options :: [{:file, Path.t()}]

  @type invalid_file_error :: {:error, :invalid_file}
  @type unsupported_version_error ::
          {:error, {:unsupported_version, major :: non_neg_integer(), minor :: non_neg_integer()}}
  @type file_error :: {:error, File.posix()}

  @doc """
  Composes a MO (`.mo`) file from the given `messages`.

  ### Examples

      iex> %Expo.Messages{
      ...>   headers: ["Last-Translator: Jane Doe"],
      ...>   messages: [
      ...>     %Expo.Message.Singular{msgid: ["foo"], msgstr: ["bar"], comments: "A comment"}
      ...>   ]
      ...> }
      ...> |> Expo.MO.compose()
      ...> |> IO.iodata_to_binary()
      <<222, 18, 4, 149, 0, 0, 0, 0, 2, 0, 0, 0, 28, 0, 0, 0, 44, 0, 0, 0, 0, 0, 0, 0,
        60, 0, 0, 0, 0, 0, 0, 0, 60, 0, 0, 0, 3, 0, 0, 0, 61, 0, 0, 0, 25, 0, 0, 0,
        65, 0, 0, 0, 3, 0, 0, 0, 91, 0, 0, 0, 0, 102, 111, 111, 0, 76, 97, 115, 116,
        45, 84, 114, 97, 110, 115, 108, 97, 116, 111, 114, 58, 32, 74, 97, 110, 101,
        32, 68, 111, 101, 0, 98, 97, 114, 0>>

  """
  @spec compose(Messages.t(), compose_options()) :: iodata()
  defdelegate compose(messages, options \\ []), to: Expo.MO.Composer

  @doc """
  Parses the given `binary` as an MO file.

  ### Examples

      iex> Expo.MO.parse_binary(<<
      ...>   0xDE120495::size(4)-unit(8),
      ...>   0::little-unsigned-integer-size(2)-unit(8),
      ...>   0::little-unsigned-integer-size(2)-unit(8),
      ...>   0::little-unsigned-integer-size(4)-unit(8),
      ...>   28::little-unsigned-integer-size(4)-unit(8),
      ...>   28::little-unsigned-integer-size(4)-unit(8),
      ...>   28::little-unsigned-integer-size(4)-unit(8),
      ...>   0::little-unsigned-integer-size(4)-unit(8)
      ...> >>)
      {:ok, %Expo.Messages{headers: [], messages: []}}

  """
  @spec parse_binary(binary(), parse_options()) ::
          {:ok, Messages.t()}
          | invalid_file_error()
          | unsupported_version_error()
  def parse_binary(binary, options \\ []), do: Parser.parse(binary, options)

  @doc """
  Parses a string into a `Expo.Messages` struct, raising an exception if there are
  any errors.

  Works exactly like `parse_binary/1`, but returns a `Expo.Messages` struct
  if there are no errors or raises an exception if there are.

  If the version of the MO file is not supported, it raises a
  `Expo.MO.UnsupportedVersionError`.

  ## Examples

      iex> Expo.MO.parse_binary!(<<
      ...>   0xDE120495::size(4)-unit(8),
      ...>   0::little-unsigned-integer-size(2)-unit(8),
      ...>   0::little-unsigned-integer-size(2)-unit(8),
      ...>   0::little-unsigned-integer-size(4)-unit(8),
      ...>   28::little-unsigned-integer-size(4)-unit(8),
      ...>   28::little-unsigned-integer-size(4)-unit(8),
      ...>   28::little-unsigned-integer-size(4)-unit(8),
      ...>   0::little-unsigned-integer-size(4)-unit(8)
      ...> >>)
      %Expo.Messages{headers: [], messages: []}

      iex> Expo.MO.parse_binary!("invalid")
      ** (Expo.MO.InvalidFileError) invalid file

  """
  @spec parse_binary!(binary(), parse_options()) :: Messages.t()
  def parse_binary!(binary, options \\ []) do
    case parse_binary(binary, options) do
      {:ok, parsed} ->
        parsed

      {:error, :invalid_file} ->
        error_options =
          case options[:file] do
            nil -> []
            path -> [file: path]
          end

        raise InvalidFileError, error_options

      {:error, {:unsupported_version, major, minor}} ->
        error_options = [major: major, minor: minor]

        error_options =
          case options[:file] do
            nil -> error_options
            path -> [{:file, path} | error_options]
          end

        raise UnsupportedVersionError, error_options
    end
  end

  @doc """
  Parses the contents of the given file into a `Expo.Messages` struct.

  This function works similarly to `parse_binary/1` except that it takes a file
  and parses the contents of that file as an MO file. It can return:

    * `{:ok, po}` if the parsing is successful
    * `{:error, line, reason}` if there is an error with the contents of the
      `.mo` file (for example, a syntax error)
    * `{:error, reason}` if there is an error with reading the file (this error
      is one of the errors that can be returned by `File.read/1`)

  ## Examples

      {:ok, po} = Expo.MO.parse_file("messages.po")
      po.file
      #=> "messages.po"

      Expo.MO.parse_file("nonexistent")
      #=> {:error, :enoent}

  """
  @spec parse_file(Path.t(), parse_options()) ::
          {:ok, Messages.t()}
          | invalid_file_error()
          | unsupported_version_error()
          | file_error()
  def parse_file(path, options \\ []) when is_list(options) do
    with {:ok, contents} <- File.read(path),
         {:ok, po} <- Parser.parse(contents, Keyword.put_new(options, :file, path)) do
      {:ok, %{po | file: path}}
    end
  end

  @doc """
  Parses the contents of a file into a `Expo.Messages` struct, raising if there
  are any errors.

  Works like `parse_file/1`, except that it raises an
  exception if there's an error with parsing the file or a `File.Error` error if
  there's an error with reading the file.

  ## Examples

      Expo.MO.parse_file!("nonexistent.po")
      #=> ** (File.Error) could not parse "nonexistent.po": no such file or directory

  """
  @spec parse_file!(Path.t(), parse_options()) :: Messages.t()
  def parse_file!(path, options \\ []) do
    case parse_file(path, options) do
      {:ok, parsed} ->
        parsed

      {:error, :invalid_file} ->
        raise InvalidFileError, file: path

      {:error, {:unsupported_version, major, minor}} ->
        raise UnsupportedVersionError,
          major: major,
          minor: minor,
          file: Keyword.get(options, :file, path)

      {:error, reason} ->
        raise File.Error, reason: reason, action: "parse", path: Keyword.get(options, :file, path)
    end
  end
end
