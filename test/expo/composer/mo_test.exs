defmodule Expo.Composer.MoTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Expo.Composer.Mo
  alias Expo.Parser.Mo, as: MoParser
  alias Expo.Translation
  alias Expo.Translations

  doctest Mo

  for {endianness, start} <- [
        big: <<0x950412DE::size(4)-unit(8)>>,
        little: <<0xDE120495::size(4)-unit(8)>>
      ] do
    describe "#{endianness}" do
      test "encodes" do
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

        assert {:ok, translations} == MoParser.parse(mo)
      end

      test "encodes unicode correctly" do
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
  end

  test "does not encode obsolete translations" do
    translations = %Translations{
      translations: [
        %Translation.Singular{msgctxt: nil, msgid: ["foo"], msgstr: ["bar"], obsolete: true}
      ]
    }

    assert {:ok, %Translations{translations: []}} =
             translations |> Mo.compose() |> IO.iodata_to_binary() |> MoParser.parse()
  end
end
