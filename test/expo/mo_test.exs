defmodule Expo.MOTest do
  use ExUnit.Case, async: true

  alias Expo.{Message, Messages, MO}
  alias Expo.MO.{InvalidFileError, UnsupportedVersionError}

  doctest MO

  describe "compose/2" do
    for {endianness, start} <- [
          big: <<0x950412DE::size(4)-unit(8)>>,
          little: <<0xDE120495::size(4)-unit(8)>>
        ] do
      test "#{endianness} encodes" do
        messages = %Messages{
          headers: [
            "Plural-Forms: nplurals=2; plural=(n != 1);\nX-Poedit-SourceCharset: UTF-8\n"
          ],
          messages: [
            %Message.Singular{msgctxt: nil, msgid: ["foo"], msgstr: ["bar"]},
            %Message.Singular{msgctxt: "ctx", msgid: ["foo"], msgstr: ["bar"]},
            %Message.Plural{
              msgctxt: nil,
              msgid: ["foo"],
              msgid_plural: ["foos"],
              msgstr: %{0 => ["bar"], 1 => ["bars"]}
            },
            %Message.Plural{
              msgctxt: "ctx",
              msgid: ["foo"],
              msgid_plural: ["foos"],
              msgstr: %{0 => ["bar"], 1 => ["bars"]}
            }
          ]
        }

        assert <<unquote(start), _rest::binary>> =
                 mo =
                 messages
                 |> MO.compose(endianness: unquote(endianness))
                 |> IO.iodata_to_binary()

        assert {:ok, messages} == MO.parse_binary(mo)
      end

      test "#{endianness} encodes unicode correctly" do
        file = "test/fixtures/mo/#{unquote(endianness)}/unicode.mo"

        messages = %Messages{
          headers: [
            "MIME-Version: 1.0\nContent-Type: text/plain; charset=UTF-8\nContent-Transfer-Encoding: 8bit\n"
          ],
          messages: [%Message.Singular{msgid: ["føø"], msgstr: ["bårπ"]}]
        }

        encoded =
          messages
          |> MO.compose(endianness: unquote(endianness))
          |> IO.iodata_to_binary()

        assert encoded == File.read!(file)
      end
    end

    test "does not encode obsolete messages" do
      messages = %Messages{
        messages: [
          %Message.Singular{msgctxt: nil, msgid: ["foo"], msgstr: ["bar"], obsolete: true}
        ]
      }

      assert {:ok, %Messages{messages: []}} =
               messages |> MO.compose() |> IO.iodata_to_binary() |> MO.parse_binary()
    end

    test "does not encode fuzzy messages except when requested" do
      messages = %Messages{
        messages: [
          %Message.Singular{msgctxt: nil, msgid: ["foo"], msgstr: ["bar"], flags: [["fuzzy"]]}
        ]
      }

      assert {:ok, %Messages{messages: []}} =
               messages |> MO.compose() |> IO.iodata_to_binary() |> MO.parse_binary()

      assert {:ok, %Messages{messages: [_fuzzy]}} =
               messages
               |> MO.compose(use_fuzzy: true)
               |> IO.iodata_to_binary()
               |> MO.parse_binary()
    end

    test "does send statistics when requested" do
      messages = %Messages{
        messages: [
          %Message.Singular{msgctxt: nil, msgid: ["foo"], msgstr: ["bar"]}
        ]
      }

      MO.compose(messages, statistics: false)

      refute_receive {MO, :message_count, 1}

      MO.compose(messages, statistics: true)

      assert_receive {MO, :message_count, 1}
    end
  end

  describe "parse_binary/1" do
    for endianness <- [:big, :little] do
      test "#{endianness} parses headers" do
        file = "test/fixtures/mo/#{unquote(endianness)}/headers.mo"
        assert {:ok, parsed} = MO.parse_binary(File.read!(file))

        assert %Messages{
                 headers: [
                   "Project-Id-Version: \nPO-Revision-Date: \nLast-Translator: \nLanguage-Team: \nLanguage: de\nMIME-Version: 1.0\nContent-Type: text/plain; charset=UTF-8\nContent-Transfer-Encoding: 8bit\nPlural-Forms: nplurals=2; plural=(n != 1);\nX-Generator: Poedit 3.0.1\n"
                 ],
                 top_comments: [],
                 messages: []
               } = parsed
      end

      test "#{endianness} parses singular message" do
        file = "test/fixtures/mo/#{unquote(endianness)}/singular.mo"
        assert {:ok, parsed} = MO.parse_binary(File.read!(file))

        assert %Messages{
                 headers: [],
                 top_comments: [],
                 messages: [
                   %Message.Singular{
                     comments: [],
                     extracted_comments: [],
                     flags: [],
                     msgctxt: nil,
                     msgid: ["foo"],
                     msgstr: ["bar"],
                     obsolete: false,
                     previous_messages: [],
                     references: []
                   }
                 ]
               } = parsed
      end

      test "#{endianness} parses singular with msgctxt message" do
        file = "test/fixtures/mo/#{unquote(endianness)}/singular-msgctxt.mo"

        assert {:ok, parsed} = MO.parse_binary(File.read!(file))

        assert %Messages{
                 headers: [],
                 top_comments: [],
                 messages: [
                   %Message.Singular{
                     comments: [],
                     extracted_comments: [],
                     flags: [],
                     msgctxt: "ctxt",
                     msgid: ["foo"],
                     msgstr: ["bar"],
                     obsolete: false,
                     previous_messages: [],
                     references: []
                   }
                 ]
               } = parsed
      end

      test "#{endianness} parses plural message" do
        file = "test/fixtures/mo/#{unquote(endianness)}/plural.mo"
        assert {:ok, parsed} = MO.parse_binary(File.read!(file))

        assert %Messages{
                 headers: [],
                 top_comments: [],
                 messages: [
                   %Message.Plural{
                     comments: [],
                     extracted_comments: [],
                     flags: [],
                     msgctxt: nil,
                     msgid: ["foo"],
                     msgstr: %{0 => ["bar"], 1 => ["bars"]},
                     obsolete: false,
                     previous_messages: [],
                     references: [],
                     msgid_plural: ["foos"]
                   }
                 ]
               } = parsed
      end

      test "#{endianness} parses plural with msgctxt message" do
        file = "test/fixtures/mo/#{unquote(endianness)}/plural-msgctxt.mo"
        assert {:ok, parsed} = MO.parse_binary(File.read!(file))

        assert %Messages{
                 headers: [],
                 top_comments: [],
                 messages: [
                   %Message.Plural{
                     comments: [],
                     extracted_comments: [],
                     flags: [],
                     msgctxt: "ctxt",
                     msgid: ["foo"],
                     msgstr: %{0 => ["bar"], 1 => ["bars"]},
                     obsolete: false,
                     previous_messages: [],
                     references: [],
                     msgid_plural: ["foos"]
                   }
                 ]
               } = parsed
      end

      test "#{endianness} parses empty mo" do
        file = "test/fixtures/mo/#{unquote(endianness)}/empty.mo"
        assert {:ok, parsed} = MO.parse_binary(File.read!(file))

        assert %Messages{
                 headers: [],
                 top_comments: [],
                 messages: []
               } = parsed
      end

      test "#{endianness} parses mo with hash table" do
        file = "test/fixtures/mo/#{unquote(endianness)}/hash-table.mo"
        assert {:ok, parsed} = MO.parse_binary(File.read!(file))

        assert %Messages{
                 messages: [%Message.Singular{msgid: ["foo"]}]
               } = parsed
      end

      test "#{endianness} parses unicode messages" do
        file = "test/fixtures/mo/#{unquote(endianness)}/unicode.mo"
        assert {:ok, parsed} = MO.parse_binary(File.read!(file))

        assert %Messages{
                 headers: [
                   "MIME-Version: 1.0\nContent-Type: text/plain; charset=UTF-8\nContent-Transfer-Encoding: 8bit\n"
                 ],
                 messages: [%Message.Singular{msgid: ["føø"], msgstr: ["bårπ"]}]
               } = parsed
      end
    end

    test "does not parse with invalid header" do
      assert {:error, %InvalidFileError{file: nil}} = MO.parse_binary(<<0>>)
      assert {:error, %InvalidFileError{file: nil}} = MO.parse_binary(<<0::unit(8)-size(32)>>)

      assert {:error, %UnsupportedVersionError{major: 1, minor: 0}} =
               MO.parse_binary(
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

  describe "parse_binary!/1" do
    test "works" do
      file = "test/fixtures/mo/little/headers.mo"
      parsed = MO.parse_binary!(File.read!(file))

      assert %Messages{
               headers: [
                 "Project-Id-Version: \nPO-Revision-Date: \nLast-Translator: \nLanguage-Team: \nLanguage: de\nMIME-Version: 1.0\nContent-Type: text/plain; charset=UTF-8\nContent-Transfer-Encoding: 8bit\nPlural-Forms: nplurals=2; plural=(n != 1);\nX-Generator: Poedit 3.0.1\n"
               ],
               top_comments: [],
               messages: []
             } = parsed
    end

    test "raises for invalid file" do
      assert_raise InvalidFileError, "invalid file", fn ->
        MO.parse_binary!("invalid")
      end

      assert_raise InvalidFileError, "file: invalid file", fn ->
        MO.parse_binary!("invalid", file: "file")
      end
    end

    test "raises for unsupported version" do
      file = "test/fixtures/mo/unsupported_version.mo"

      assert_raise UnsupportedVersionError,
                   "invalid version, only ~> 0.0 is supported, 1.0 given",
                   fn ->
                     MO.parse_binary!(File.read!(file))
                   end

      assert_raise UnsupportedVersionError,
                   "file: invalid version, only ~> 0.0 is supported, 1.0 given",
                   fn ->
                     MO.parse_binary!(File.read!(file), file: "file")
                   end
    end
  end

  describe "parse_file/1" do
    test "works" do
      file = "test/fixtures/mo/little/headers.mo"
      assert {:ok, parsed} = MO.parse_file(file)

      assert %Messages{
               headers: [
                 "Project-Id-Version: \nPO-Revision-Date: \nLast-Translator: \nLanguage-Team: \nLanguage: de\nMIME-Version: 1.0\nContent-Type: text/plain; charset=UTF-8\nContent-Transfer-Encoding: 8bit\nPlural-Forms: nplurals=2; plural=(n != 1);\nX-Generator: Poedit 3.0.1\n"
               ],
               top_comments: [],
               messages: []
             } = parsed
    end

    test "returns an error with an invalid file" do
      file = "test/fixtures/po/bom.po"
      assert {:error, %InvalidFileError{file: ^file}} = MO.parse_file(file)
    end

    test "raises for unsupported version" do
      file = "test/fixtures/mo/unsupported_version.mo"

      assert {:error, %UnsupportedVersionError{major: 1, minor: 0, file: ^file}} =
               MO.parse_file(file)
    end

    test "missing file" do
      assert MO.parse_file("nonexistent") == {:error, :enoent}
    end
  end

  describe "parse_file!/1" do
    test "works" do
      file = "test/fixtures/mo/little/headers.mo"
      assert parsed = MO.parse_file!(file)

      assert %Messages{
               headers: [
                 "Project-Id-Version: \nPO-Revision-Date: \nLast-Translator: \nLanguage-Team: \nLanguage: de\nMIME-Version: 1.0\nContent-Type: text/plain; charset=UTF-8\nContent-Transfer-Encoding: 8bit\nPlural-Forms: nplurals=2; plural=(n != 1);\nX-Generator: Poedit 3.0.1\n"
               ],
               top_comments: [],
               messages: []
             } = parsed
    end

    test "raises for invalid file" do
      file = "test/fixtures/po/bom.po"

      assert_raise InvalidFileError, "test/fixtures/po/bom.po: invalid file", fn ->
        MO.parse_file!(file)
      end
    end

    test "raises for unsupported version" do
      file = "test/fixtures/mo/unsupported_version.mo"

      message =
        "test/fixtures/mo/unsupported_version.mo: invalid version, only ~> 0.0 is supported, 1.0 given"

      assert_raise UnsupportedVersionError, message, fn ->
        MO.parse_file!(file)
      end
    end

    test "missing file" do
      # We're using a regex because we want optional double quotes around the file
      # path: the error message (for File.read!/1) in Elixir v1.2 doesn't have
      # them, but it does in v1.3.
      msg = ~r/could not parse "?nonexistent"?: no such file or directory/

      assert_raise File.Error, msg, fn ->
        MO.parse_file!("nonexistent")
      end
    end
  end
end
