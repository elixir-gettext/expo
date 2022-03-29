defmodule Expo.Parser.Mo do
  @moduledoc false

  alias Expo.Translation
  alias Expo.Translations

  @spec parse(content :: binary()) ::
          {:ok, Translations.t()}
          | {:error,
             :invalid_header
             | {:unsupported_version, major :: non_neg_integer(), minor :: non_neg_integer()}}
  def parse(content) do
    with {:ok, {endian, header}} <- parse_header(binary_part(content, 0, 28)),
         :ok <-
           check_version(header.file_format_revision_major, header.file_format_revision_minor),
         translations <- parse_translations(endian, header, content),
         {headers, translations} <- extract_meta_headers(translations) do
      %Translations{translations: translations, headers: headers}
    end
  end

  defp parse_header(header_binary)

  defp parse_header(
         <<0xDE120495::size(4)-unit(8),
           file_format_revision_major::little-unsigned-integer-size(2)-unit(8),
           file_format_revision_minor::little-unsigned-integer-size(2)-unit(8),
           number_of_strings::little-unsigned-integer-size(4)-unit(8),
           offset_of_table_with_original_strings::little-unsigned-integer-size(4)-unit(8),
           offset_of_table_with_translation_strings::little-unsigned-integer-size(4)-unit(8),
           _size_of_hashing_table::little-unsigned-integer-size(4)-unit(8),
           _offset_of_hashing_table::little-unsigned-integer-size(4)-unit(8)>>
       ),
       do:
         {:ok,
          {:little,
           %{
             file_format_revision_major: file_format_revision_major,
             file_format_revision_minor: file_format_revision_minor,
             number_of_strings: number_of_strings,
             offset_of_table_with_original_strings: offset_of_table_with_original_strings,
             offset_of_table_with_translation_strings: offset_of_table_with_translation_strings
           }}}

  defp parse_header(
         <<0x950412DE::32, file_format_revision_major::big-unsigned-integer-size(2)-unit(8),
           file_format_revision_minor::big-unsigned-integer-size(2)-unit(8),
           number_of_strings::big-unsigned-integer-size(4)-unit(8),
           offset_of_table_with_original_strings::big-unsigned-integer-size(4)-unit(8),
           offset_of_table_with_translation_strings::big-unsigned-integer-size(4)-unit(8),
           _size_of_hashing_table::big-unsigned-integer-size(4)-unit(8),
           _offset_of_hashing_table::big-unsigned-integer-size(4)-unit(8)>>
       ),
       do:
         {:ok,
          {:big,
           %{
             file_format_revision_major: file_format_revision_major,
             file_format_revision_minor: file_format_revision_minor,
             number_of_strings: number_of_strings,
             offset_of_table_with_original_strings: offset_of_table_with_original_strings,
             offset_of_table_with_translation_strings: offset_of_table_with_translation_strings
           }}}

  defp parse_header(_header_binary), do: {:error, :invalid_header}

  defp check_version(major, minor)
  # Not checking minor since they must be BC compatible
  defp check_version(0, _minor), do: :ok
  defp check_version(major, minor), do: {:unsupported_version, major, minor}

  defp parse_translations(endian, header, content) do
    [
      header.offset_of_table_with_original_strings,
      header.offset_of_table_with_translation_strings
    ]
    |> Enum.map(&read_table(endian, content, &1, header.number_of_strings))
    |> zip_with(&to_translation/1)
  end

  defp read_table(endian, content, start_offset, number_of_elements),
    do:
      endian
      |> read_table_headers(binary_part(content, start_offset, number_of_elements * 2 * 4), [])
      |> Enum.map(&read_table_cell(content, &1))

  defp read_table_headers(endian, table_header, acc)

  defp read_table_headers(
         :big,
         <<cell_offset::big-unsigned-integer-size(4)-unit(8),
           cell_length::big-unsigned-integer-size(4)-unit(8), rest::binary>>,
         acc
       ),
       do: read_table_headers(:big, rest, [{cell_offset, cell_length} | acc])

  defp read_table_headers(
         :little,
         <<cell_length::little-unsigned-integer-size(4)-unit(8),
           cell_offset::little-unsigned-integer-size(4)-unit(8), rest::binary>>,
         acc
       ),
       do: read_table_headers(:little, rest, [{cell_offset, cell_length} | acc])

  defp read_table_headers(_endian, <<>>, acc), do: Enum.reverse(acc)

  defp read_table_cell(content, position)
  defp read_table_cell(content, {offset, length}), do: binary_part(content, offset, length)

  defp to_translation([msgid, msgstr]) do
    {attrs, translation_type} = msg_id_to_translation_attrs(msgid)

    attrs =
      case translation_type do
        Translation.Singular ->
          Map.merge(attrs, %{msgstr: msgstr})

        Translation.Plural ->
          msgstr =
            for {msgstr, index} <- Enum.with_index(String.split(msgstr, <<0>>)),
                into: %{},
                do: {index, msgstr}

          Map.merge(attrs, %{msgstr: msgstr})
      end

    struct!(translation_type, attrs)
  end

  defp msg_id_to_translation_attrs(msgid) do
    {attrs, msgid} =
      case String.split(msgid, <<4::utf8>>, parts: 2) do
        [msgid] -> {%{}, msgid}
        [context, msgid] -> {%{context: context}, msgid}
      end

    case String.split(msgid, <<0>>, parts: 2) do
      [msgid] ->
        {Map.merge(attrs, %{msgid: msgid}), Translation.Singular}

      [msgid, msgid_plural] ->
        {Map.merge(attrs, %{msgid: msgid, msgid_plural: msgid_plural}), Translation.Plural}
    end
  end

  defp extract_meta_headers(translations) do
    [meta_translations, translations] = Enum.chunk_by(translations, &match?(%{msgid: ""}, &1))

    {Enum.flat_map(meta_translations, &parse_meta_headers(&1.msgstr)), translations}
  end

  defp parse_meta_headers(headers),
    do: headers |> String.split("\n", trim: true) |> Enum.map(&parse_meta_header/1)

  defp parse_meta_header(header),
    do: header |> String.split(":", parts: 2, trim: true) |> Enum.map(&String.trim/1)

  # TODO: Remove when requiring at least Elixir 1.12
  if function_exported?(Enum, :zip_with, 2) do
    defp zip_with(lists, mapper), do: Enum.zip_with(lists, mapper)
  else
    defp zip_with(lists, mapper),
      do: lists |> Enum.zip() |> Enum.map(fn {left, right} -> mapper.([left, right]) end)
  end
end
