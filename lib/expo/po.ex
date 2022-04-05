defmodule Expo.Po do
  @moduledoc """
  `.po` / `.pot` file handler
  """

  alias Expo.Po.DuplicateTranslationsError
  alias Expo.Po.Parser
  alias Expo.Po.SyntaxError
  alias Expo.Translations

  @type parse_error ::
          {:error,
           {:parse_error, message :: String.t(), context :: String.t(), line :: pos_integer()}}
  @type duplicate_translations_error ::
          {:error,
           {:duplicate_translations,
            [{message :: String.t(), new_line :: pos_integer(), old_line :: pos_integer()}]}}
  @type file_error :: {:error, File.posix()}

  @doc """
  Dumps a `Expo.Translations` struct as iodata.

  This function dumps a `Expo.Translations` struct (representing a PO file) as iodata,
  which can later be written to a file or converted to a string with
  `IO.iodata_to_binary/1`.

  ## Examples

  After running the following code:

      iodata = Expo.Po.compose %Expo.Translations{
        headers: ["Last-Translator: Jane Doe"],
        translations: [
          %Expo.Translation.Singular{msgid: ["foo"], msgstr: ["bar"], comments: "A comment"}
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
  @spec compose(translations :: Translations.t()) :: iodata()
  defdelegate compose(content), to: Expo.Po.Composer

  @doc """
  Parses a string into a `Expo.Translations` struct.

  This function parses a given `str` into a `Expo.Translations` struct.
  It returns `{:ok, po}` if there are no errors,
  otherwise `{:error, line, reason}`.

  ## Examples

      iex> {:ok, po} = Expo.Po.parse_string \"""
      ...> msgid "foo"
      ...> msgstr "bar"
      ...> \"""
      iex> [t] = po.translations
      iex> t.msgid
      ["foo"]
      iex> t.msgstr
      ["bar"]
      iex> po.headers
      []

      iex> Expo.Po.parse_string "foo"
      {:error, {:parse_error, "expected msgid followed by strings while processing plural translation inside singular translation or plural translation", "foo", 1}}

  """
  @spec parse_string(content :: binary()) ::
          {:ok, Translations.t()}
          | parse_error()
          | duplicate_translations_error()
  def parse_string(content) do
    Parser.parse(content)
  end

  @doc """
  Parses a string into a `Expo.Po` struct, raising an exception if there are
  any errors.

  Works exactly like `parse_string/1`, but returns a `Expo.Po` struct
  if there are no errors or raises a `Expo.Po.SyntaxError` error if there
  are.

  ## Examples

      iex> po = Expo.Po.parse_string! \"""
      ...> msgid "foo"
      ...> msgstr "bar"
      ...> \"""
      iex> [t] = po.translations
      iex> t.msgid
      ["foo"]
      iex> t.msgstr
      ["bar"]
      iex> po.headers
      []

      iex> Expo.Po.parse_string!("msgid")
      ** (Expo.Po.SyntaxError) 1: expected whitespace while processing msgid followed by strings inside plural translation inside singular translation or plural translation

      iex> Expo.Po.parse_string!(\"""
      ...> msgid "test"
      ...> msgstr ""
      ...>
      ...> msgid "test"
      ...> msgstr ""
      ...> \""")
      ** (Expo.Po.DuplicateTranslationsError) 4: found duplicate on line 4 for msgid: 'test'

  """
  @spec parse_string!(content :: String.t()) :: Translations.t() | no_return
  def parse_string!(str) do
    case parse_string(str) do
      {:ok, parsed} ->
        parsed

      {:error, {:parse_error, reason, context, line}} ->
        raise SyntaxError, line: line, reason: reason, context: context

      {:error, {:duplicate_translations, duplicates}} ->
        raise DuplicateTranslationsError, duplicates: duplicates
    end
  end

  @doc """
  Parses the contents of a file into a `Expo.Po` struct.

  This function works similarly to `parse_string/1` except that it takes a file
  and parses the contents of that file. It can return:

    * `{:ok, po}`
    * `{:error, line, reason}` if there is an error with the contents of the
      `.po` file (for example, a syntax error)
    * `{:error, reason}` if there is an error with reading the file (this error
      is one of the errors that can be returned by `File.read/1`)

  ## Examples

      {:ok, po} = Expo.Po.parse_file "translations.po"
      po.file
      #=> "translations.po"

      Expo.Po.parse_file "nonexistent"
      #=> {:error, :enoent}

  """
  @spec parse_file(path :: Path.t()) ::
          {:ok, Translations.t()}
          | parse_error()
          | duplicate_translations_error()
          | file_error()
  def parse_file(path) do
    with {:ok, contents} <- File.read(path),
         {:ok, po} <- Parser.parse(contents, file: path) do
      {:ok, %{po | file: path}}
    end
  end

  @doc """
  Parses the contents of a file into a `Expo.Po` struct, raising if there
  are any errors.

  Works like `parse_file/1`, except that it raises a `Expo.Po.SyntaxError`
  exception if there's a syntax error in the file or a `File.Error` error if
  there's an error with reading the file.

  ## Examples

      Expo.Po.parse_file! "nonexistent.po"
      #=> ** (File.Error) could not parse "nonexistent.po": no such file or directory

  """
  @spec parse_file!(Path.t()) :: Translations.t() | no_return
  def parse_file!(path) do
    case parse_file(path) do
      {:ok, parsed} ->
        parsed

      {:error, {:parse_error, reason, context, line}} ->
        raise SyntaxError, line: line, reason: reason, file: path, context: context

      {:error, {:duplicate_translations, duplicates}} ->
        raise DuplicateTranslationsError, duplicates: duplicates, file: path

      {:error, reason} ->
        raise File.Error, reason: reason, action: "parse", path: path
    end
  end
end
