defmodule Expo.Parser.MoTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Expo.Parser.Mo

  doctest Mo

  @example :expo |> Application.app_dir("priv/test/example.mo") |> File.read!()

  describe "parses .mo file" do
    test "works" do
      assert %Expo.Translations{
               headers: [
                 ["Project-Id-Version", "Project"],
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
                 %Expo.Translation.Singular{msgctx: nil, msgid: "foo", msgstr: "bar"},
                 %Expo.Translation.Plural{
                   msgctx: nil,
                   msgid: "{count} New Notification",
                   msgid_plural: "{count} New Notifications",
                   msgstr: %{0 => "{count} Nuova notifica", 1 => "{count} Nuove notifiche"}
                 }
               ]
             } = Mo.parse(@example)
    end
  end
end
