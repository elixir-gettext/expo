defmodule Expo.Parser.PoTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Expo.Parser.Po

  doctest Po

  @example :expo |> Application.app_dir("priv/test/example.po") |> File.read!()

  describe "parses .po file" do
    test "works" do
      assert %Expo.Translations{
               headers: [
                 ["Project-Id-Version", "Project"],
                 ["POT-Creation-Date", ""],
                 ["PO-Revision-Date", ""],
                 ["Last-Translator", ""],
                 ["Language-Team", "Language Team"],
                 ["Language", "en"],
                 ["MIME-Version", "1.0"],
                 ["Content-Type", "text/plain; charset=UTF-8"],
                 ["Content-Transfer-Encoding", "8bit"],
                 ["Plural-Forms", "nplurals=2; plural=(n != 1);"],
                 ["X-Generator", "Poedit 3.0.1"],
                 ["X-Poedit-SourceCharset", "UTF-8"]
               ],
               translations: [
                 %Expo.Translation.Singular{
                   msgctx: nil,
                   msgid: "foo",
                   msgstr: "bar",
                   comments: ["This is a translation", "Ah, another comment!"],
                   extracted_comments: ["An extracted comment"],
                   flags: MapSet.new(["flag1", "flag2"]),
                   previous_msgids: ["previous-untranslated-string"],
                   references: ["lib/foo.ex:32"]
                 },
                 %Expo.Translation.Plural{
                   msgctx: nil,
                   msgid: "{count} New Notification",
                   msgid_plural: "{count} New Notifications",
                   msgstr: %{0 => "{count} Nuova notifica", 1 => "{count} Nuove notifiche"},
                   comments: [],
                   extracted_comments: [],
                   flags: MapSet.new([]),
                   previous_msgids: [],
                   references: []
                 }
               ],
               obsolete_translations: [
                 %Expo.Translation.Singular{
                   comments: [],
                   msgctx: nil,
                   extracted_comments: [],
                   flags: MapSet.new([]),
                   msgid: "hello",
                   msgstr: "ciao",
                   previous_msgids: [],
                   references: []
                 },
                 %Expo.Translation.Plural{
                   comments: [],
                   msgctx: nil,
                   extracted_comments: [],
                   flags: MapSet.new([]),
                   msgid: "{count} Test",
                   msgid_plural: "{count} Tests",
                   msgstr: %{0 => "{count} Test", 1 => "{count} Tests"},
                   previous_msgids: [],
                   references: []
                 }
               ]
             } == Po.parse(@example)
    end
  end
end
