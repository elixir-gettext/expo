defmodule Expo.Po do
  @moduledoc """
  `.po` / `.pot` file handler
  """

  alias Expo.Translations

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
  Parse `.po` file

  ### Examples

      iex> Expo.Po.parse(\"""
      ...> msgid "foo"
      ...> msgstr "bar"
      ...> \""")
      {:ok, %Expo.Translations{
        headers: [],
        translations: [
          %Expo.Translation.Singular{
            comments: [],
            msgctxt: nil,
            extracted_comments: [],
            flags: [],
            msgid: ["foo"],
            msgstr: ["bar"],
            previous_msgids: [],
            references: [],
            obsolete: false
          }
        ]
      }}
  """
  @spec parse(content :: binary()) ::
          {:ok, Translations.t()}
          | {:error,
             :invalid_file
             | :invalid_header
             | {:unsupported_version, major :: non_neg_integer(), minor :: non_neg_integer()}}
  defdelegate parse(content), to: Expo.Po.Parser
end
