defmodule Expo.Po do
  @moduledoc """
  `.po` / `.pot` file handler
  """

  alias Expo.Messages
  alias Expo.Po.DuplicateMessagesError
  alias Expo.Po.Parser
  alias Expo.Po.SyntaxError

  @type parse_options :: [{:file, Path.t()}]

  @type parse_error ::
          {:error,
           {:parse_error, message :: String.t(), context :: String.t(), line :: pos_integer()}}
  @type duplicate_messages_error ::
          {:error,
           {:duplicate_messages,
            [{message :: String.t(), new_line :: pos_integer(), old_line :: pos_integer()}]}}
  @type file_error :: {:error, File.posix()}

  @doc """
  Dumps a `Expo.Messages` struct as iodata.

  This function dumps a `Expo.Messages` struct (representing a PO file) as iodata,
  which can later be written to a file or converted to a string with
  `IO.iodata_to_binary/1`.

  ## Examples

  After running the following code:

      iodata = Expo.Po.compose %Expo.Messages{
        headers: ["Last-Translator: Jane Doe"],
        messages: [
          %Expo.Message.Singular{msgid: ["foo"], msgstr: ["bar"], comments: "A comment"}
        ]
      }

      File.write!("/tmp/test.po", iodata)

  the `/tmp/test.po` file would look like this:

      msgid ""
      msgstr ""
      "Last-Translator: Jane Doe"

      # A comment
      msgid "foo"
      msgstr "bar"

  """
  @spec compose(messages :: Messages.t()) :: iodata()
  defdelegate compose(content), to: Expo.Po.Composer

  @doc """
  Parses a string into a `Expo.Messages` struct.

  This function parses a given `str` into a `Expo.Messages` struct.
  It returns `{:ok, po}` if there are no errors,
  otherwise `{:error, line, reason}`.

  ## Examples

      iex> {:ok, po} = Expo.Po.parse_string \"""
      ...> msgid "foo"
      ...> msgstr "bar"
      ...> \"""
      iex> [t] = po.messages
      iex> t.msgid
      ["foo"]
      iex> t.msgstr
      ["bar"]
      iex> po.headers
      []

      iex> Expo.Po.parse_string "foo"
      {:error, {:parse_error, "expected msgid followed by strings while processing message", "foo", 1}}

  """
  @spec parse_string(content :: binary(), opts :: parse_options()) ::
          {:ok, Messages.t()}
          | parse_error()
          | duplicate_messages_error()
  def parse_string(content, opts \\ []) do
    Parser.parse(content, opts)
  end

  @doc """
  Parses a string into a `Expo.Messages` struct, raising an exception if there are
  any errors.

  Works exactly like `parse_string/1`, but returns a `Expo.Messages` struct
  if there are no errors or raises a `Expo.Po.SyntaxError` error if there
  are.

  ## Examples

      iex> po = Expo.Po.parse_string! \"""
      ...> msgid "foo"
      ...> msgstr "bar"
      ...> \"""
      iex> [t] = po.messages
      iex> t.msgid
      ["foo"]
      iex> t.msgstr
      ["bar"]
      iex> po.headers
      []

      iex> Expo.Po.parse_string!("msgid")
      ** (Expo.Po.SyntaxError) 1: expected whitespace while processing msgid followed by strings inside message

      iex> Expo.Po.parse_string!(\"""
      ...> msgid "test"
      ...> msgstr ""
      ...>
      ...> msgid "test"
      ...> msgstr ""
      ...> \""")
      ** (Expo.Po.DuplicateMessagesError) 4: found duplicate on line 4 for msgid: 'test'

  """
  @spec parse_string!(content :: String.t(), opts :: parse_options()) ::
          Messages.t() | no_return
  def parse_string!(str, opts \\ []) do
    case parse_string(str, opts) do
      {:ok, parsed} ->
        parsed

      {:error, {:parse_error, reason, context, line}} ->
        options = [line: line, reason: reason, context: context]

        options =
          case opts[:file] do
            nil -> options
            path -> [{:file, path} | options]
          end

        raise SyntaxError, options

      {:error, {:duplicate_messages, duplicates}} ->
        options = [duplicates: duplicates]

        options =
          case opts[:file] do
            nil -> options
            path -> [{:file, path} | options]
          end

        raise DuplicateMessagesError, options
    end
  end

  @doc """
  Parses the contents of a file into a `Expo.Messages` struct.

  This function works similarly to `parse_string/1` except that it takes a file
  and parses the contents of that file. It can return:

    * `{:ok, po}`
    * `{:error, line, reason}` if there is an error with the contents of the
      `.po` file (for example, a syntax error)
    * `{:error, reason}` if there is an error with reading the file (this error
      is one of the errors that can be returned by `File.read/1`)

  ## Examples

      {:ok, po} = Expo.Po.parse_file "messages.po"
      po.file
      #=> "messages.po"

      Expo.Po.parse_file "nonexistent"
      #=> {:error, :enoent}

  """
  @spec parse_file(path :: Path.t(), opts :: parse_options()) ::
          {:ok, Messages.t()}
          | parse_error()
          | duplicate_messages_error()
          | file_error()
  def parse_file(path, opts \\ []) do
    with {:ok, contents} <- File.read(path) do
      Parser.parse(contents, Keyword.put_new(opts, :file, path))
    end
  end

  @doc """
  Parses the contents of a file into a `Expo.Messages` struct, raising if there
  are any errors.

  Works like `parse_file/1`, except that it raises a `Expo.Po.SyntaxError`
  exception if there's a syntax error in the file or a `File.Error` error if
  there's an error with reading the file.

  ## Examples

      Expo.Po.parse_file! "nonexistent.po"
      #=> ** (File.Error) could not parse "nonexistent.po": no such file or directory

  """
  @spec parse_file!(Path.t(), opts :: parse_options()) :: Messages.t() | no_return
  def parse_file!(path, opts \\ []) do
    case parse_file(path, opts) do
      {:ok, parsed} ->
        parsed

      {:error, {:parse_error, reason, context, line}} ->
        raise SyntaxError, line: line, reason: reason, file: path, context: context

      {:error, {:duplicate_messages, duplicates}} ->
        raise DuplicateMessagesError,
          duplicates: duplicates,
          file: Keyword.get(opts, :file, path)

      {:error, reason} ->
        raise File.Error, reason: reason, action: "parse", path: Keyword.get(opts, :file, path)
    end
  end
end
