defmodule Expo.Mo do
  @moduledoc """
  `.mo` file handler
  """

  alias Expo.Messages
  alias Expo.Mo.InvalidFileError
  alias Expo.Mo.Parser
  alias Expo.Mo.UnsupportedVersionError

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
  Composes a `.mo` file from messages

  ### Examples

      iex> %Expo.Messages{
      ...>   headers: ["Last-Translator: Jane Doe"],
      ...>   messages: [
      ...>     %Expo.Message.Singular{msgid: ["foo"], msgstr: ["bar"], comments: "A comment"}
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
  @spec compose(messages :: Messages.t(), opts :: compose_options()) :: iodata()
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
      {:ok, %Expo.Messages{headers: [], messages: []}}

  """
  @spec parse_binary(content :: binary(), opts :: parse_options()) ::
          {:ok, Messages.t()}
          | invalid_file_error()
          | unsupported_version_error()
  def parse_binary(content, opts \\ []), do: Parser.parse(content, opts)

  @doc """
  Parses a string into a `Expo.Messages` struct, raising an exception if there are
  any errors.

  Works exactly like `parse_binary/1`, but returns a `Expo.Messages` struct
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
      %Expo.Messages{headers: [], messages: []}

      iex> Expo.Mo.parse_binary!("invalid")
      ** (Expo.Mo.InvalidFileError) invalid file

  """
  @spec parse_binary!(content :: binary(), options :: parse_options()) ::
          Messages.t() | no_return
  def parse_binary!(str, opts \\ []) do
    case parse_binary(str, opts) do
      {:ok, parsed} ->
        parsed

      {:error, :invalid_file} ->
        options =
          case opts[:file] do
            nil -> []
            path -> [file: path]
          end

        raise InvalidFileError, options

      {:error, {:unsupported_version, major, minor}} ->
        options = [major: major, minor: minor]

        options =
          case opts[:file] do
            nil -> options
            path -> [{:file, path} | options]
          end

        raise UnsupportedVersionError, options
    end
  end

  @doc """
  Parses the contents of a file into a `Expo.Messages` struct.

  This function works similarly to `parse_binary/1` except that it takes a file
  and parses the contents of that file. It can return:

    * `{:ok, po}`
    * `{:error, line, reason}` if there is an error with the contents of the
      `.po` file (for example, a syntax error)
    * `{:error, reason}` if there is an error with reading the file (this error
      is one of the errors that can be returned by `File.read/1`)

  ## Examples

      {:ok, po} = Expo.Mo.parse_file "messages.po"
      po.file
      #=> "messages.po"

      Expo.Mo.parse_file "nonexistent"
      #=> {:error, :enoent}

  """
  @spec parse_file(path :: Path.t(), opts :: parse_options()) ::
          {:ok, Messages.t()}
          | invalid_file_error()
          | unsupported_version_error()
          | file_error()
  def parse_file(path, opts \\ []) do
    with {:ok, contents} <- File.read(path),
         {:ok, po} <- Parser.parse(contents, Keyword.put_new(opts, :file, path)) do
      {:ok, %{po | file: path}}
    end
  end

  @doc """
  Parses the contents of a file into a `Expo.Messages` struct, raising if there
  are any errors.

  Works like `parse_file/1`, except that it raises a `Expo.Mo.SyntaxError`
  exception if there's a syntax error in the file or a `File.Error` error if
  there's an error with reading the file.

  ## Examples

      Expo.Mo.parse_file! "nonexistent.po"
      #=> ** (File.Error) could not parse "nonexistent.po": no such file or directory

  """
  @spec parse_file!(Path.t(), opts :: parse_options()) :: Messages.t() | no_return
  def parse_file!(path, opts \\ []) do
    case parse_file(path, opts) do
      {:ok, parsed} ->
        parsed

      {:error, :invalid_file} ->
        raise InvalidFileError, file: path

      {:error, {:unsupported_version, major, minor}} ->
        raise UnsupportedVersionError,
          major: major,
          minor: minor,
          file: Keyword.get(opts, :file, path)

      {:error, reason} ->
        raise File.Error, reason: reason, action: "parse", path: Keyword.get(opts, :file, path)
    end
  end
end
