defmodule Expo.MoTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Expo.Mo
  alias Expo.Translation
  alias Expo.Translations

  doctest Mo

  describe "compose/2" do
    for {endianness, start} <- [
          big: <<0x950412DE::size(4)-unit(8)>>,
          little: <<0xDE120495::size(4)-unit(8)>>
        ] do
      test "#{endianness} encodes" do
        translations = %Translations{
          headers: [
            "Plural-Forms: nplurals=2; plural=(n != 1);\nX-Poedit-SourceCharset: UTF-8\n"
          ],
          translations: [
            %Translation.Singular{msgctxt: nil, msgid: ["foo"], msgstr: ["bar"]},
            %Translation.Singular{msgctxt: "ctx", msgid: ["foo"], msgstr: ["bar"]},
            %Translation.Plural{
              msgctxt: nil,
              msgid: ["foo"],
              msgid_plural: ["foos"],
              msgstr: %{0 => ["bar"], 1 => ["bars"]}
            },
            %Translation.Plural{
              msgctxt: "ctx",
              msgid: ["foo"],
              msgid_plural: ["foos"],
              msgstr: %{0 => ["bar"], 1 => ["bars"]}
            }
          ]
        }

        assert <<unquote(start), _rest::binary>> =
                 mo =
                 translations
                 |> Mo.compose(endianness: unquote(endianness))
                 |> IO.iodata_to_binary()

        assert {:ok, translations} == Mo.parse(mo)
      end

      test "#{endianness} encodes unicode correctly" do
        file = Application.app_dir(:expo, "priv/test/mo/#{unquote(endianness)}/unicode.mo")

        translations = %Translations{
          headers: [
            "MIME-Version: 1.0\nContent-Type: text/plain; charset=UTF-8\nContent-Transfer-Encoding: 8bit\n"
          ],
          translations: [%Translation.Singular{msgid: ["føø"], msgstr: ["bårπ"]}]
        }

        encoded =
          translations
          |> Mo.compose(endianness: unquote(endianness))
          |> IO.iodata_to_binary()

        assert encoded == File.read!(file)
      end
    end

    test "does not encode obsolete translations" do
      translations = %Translations{
        translations: [
          %Translation.Singular{msgctxt: nil, msgid: ["foo"], msgstr: ["bar"], obsolete: true}
        ]
      }

      assert {:ok, %Translations{translations: []}} =
               translations |> Mo.compose() |> IO.iodata_to_binary() |> Mo.parse()
    end
  end

  describe "parse/1" do
    for endianness <- [:big, :little] do
      test "#{endianness} parses headers" do
        file = Application.app_dir(:expo, "priv/test/mo/#{unquote(endianness)}/headers.mo")
        assert {:ok, parsed} = Mo.parse(File.read!(file))

        assert %Translations{
                 headers: [
                   "Project-Id-Version: \nPO-Revision-Date: \nLast-Translator: \nLanguage-Team: \nLanguage: de\nMIME-Version: 1.0\nContent-Type: text/plain; charset=UTF-8\nContent-Transfer-Encoding: 8bit\nPlural-Forms: nplurals=2; plural=(n != 1);\nX-Generator: Poedit 3.0.1\n"
                 ],
                 top_comments: [],
                 translations: []
               } = parsed
      end

      test "#{endianness} parses singular translation" do
        file = Application.app_dir(:expo, "priv/test/mo/#{unquote(endianness)}/singular.mo")
        assert {:ok, parsed} = Mo.parse(File.read!(file))

        assert %Translations{
                 headers: [],
                 top_comments: [],
                 translations: [
                   %Translation.Singular{
                     comments: [],
                     extracted_comments: [],
                     flags: [],
                     msgctxt: nil,
                     msgid: ["foo"],
                     msgstr: ["bar"],
                     obsolete: false,
                     previous_msgids: [],
                     references: []
                   }
                 ]
               } = parsed
      end

      test "#{endianness} parses singular with msgctxt translation" do
        file =
          Application.app_dir(:expo, "priv/test/mo/#{unquote(endianness)}/singular-msgctxt.mo")

        assert {:ok, parsed} = Mo.parse(File.read!(file))

        assert %Translations{
                 headers: [],
                 top_comments: [],
                 translations: [
                   %Translation.Singular{
                     comments: [],
                     extracted_comments: [],
                     flags: [],
                     msgctxt: "ctxt",
                     msgid: ["foo"],
                     msgstr: ["bar"],
                     obsolete: false,
                     previous_msgids: [],
                     references: []
                   }
                 ]
               } = parsed
      end

      test "#{endianness} parses plural translation" do
        file = Application.app_dir(:expo, "priv/test/mo/#{unquote(endianness)}/plural.mo")
        assert {:ok, parsed} = Mo.parse(File.read!(file))

        assert %Translations{
                 headers: [],
                 top_comments: [],
                 translations: [
                   %Translation.Plural{
                     comments: [],
                     extracted_comments: [],
                     flags: [],
                     msgctxt: nil,
                     msgid: ["foo"],
                     msgstr: %{0 => ["bar"], 1 => ["bars"]},
                     obsolete: false,
                     previous_msgids: [],
                     references: [],
                     msgid_plural: ["foos"]
                   }
                 ]
               } = parsed
      end

      test "#{endianness} parses plural with msgctxt translation" do
        file = Application.app_dir(:expo, "priv/test/mo/#{unquote(endianness)}/plural-msgctxt.mo")
        assert {:ok, parsed} = Mo.parse(File.read!(file))

        assert %Translations{
                 headers: [],
                 top_comments: [],
                 translations: [
                   %Translation.Plural{
                     comments: [],
                     extracted_comments: [],
                     flags: [],
                     msgctxt: "ctxt",
                     msgid: ["foo"],
                     msgstr: %{0 => ["bar"], 1 => ["bars"]},
                     obsolete: false,
                     previous_msgids: [],
                     references: [],
                     msgid_plural: ["foos"]
                   }
                 ]
               } = parsed
      end

      test "#{endianness} parses empty mo" do
        file = Application.app_dir(:expo, "priv/test/mo/#{unquote(endianness)}/empty.mo")
        assert {:ok, parsed} = Mo.parse(File.read!(file))

        assert %Translations{
                 headers: [],
                 top_comments: [],
                 translations: []
               } = parsed
      end

      test "#{endianness} parses mo with hash table" do
        file = Application.app_dir(:expo, "priv/test/mo/#{unquote(endianness)}/hash-table.mo")
        assert {:ok, parsed} = Mo.parse(File.read!(file))

        assert %Translations{
                 translations: [%Translation.Singular{msgid: ["foo"]}]
               } = parsed
      end

      test "#{endianness} parses unicode translations" do
        file = Application.app_dir(:expo, "priv/test/mo/#{unquote(endianness)}/unicode.mo")
        assert {:ok, parsed} = Mo.parse(File.read!(file))

        assert %Translations{
                 headers: [
                   "MIME-Version: 1.0\nContent-Type: text/plain; charset=UTF-8\nContent-Transfer-Encoding: 8bit\n"
                 ],
                 translations: [%Translation.Singular{msgid: ["føø"], msgstr: ["bårπ"]}]
               } = parsed
      end
    end

    test "does not parse with invalid header" do
      assert {:error, :invalid_file} = Mo.parse(<<0>>)
      assert {:error, :invalid_header} = Mo.parse(<<0::unit(8)-size(32)>>)

      assert {:error, {:unsupported_version, 1, 0}} =
               Mo.parse(
                 <<0xDE120495::size(4)-unit(8), 1::little-unsigned-integer-size(2)-unit(8),
                   0::little-unsigned-integer-size(2)-unit(8),
                   0::little-unsigned-integer-size(4)-unit(8),
                   28::little-unsigned-integer-size(4)-unit(8),
                   28::little-unsigned-integer-size(4)-unit(8),
                   28::little-unsigned-integer-size(4)-unit(8),
                   0::little-unsigned-integer-size(4)-unit(8)>>
               )
    end
  end
end
