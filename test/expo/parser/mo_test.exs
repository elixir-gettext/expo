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
                 "Project-Id-Version: Project\n",
                 "PO-Revision-Date: \n",
                 "Last-Translator: \n",
                 "Language-Team: Language Team\n",
                 "Language: en\n",
                 "MIME-Version: 1.0\n",
                 "Content-Type: text/plain; charset=UTF-8\n",
                 "Content-Transfer-Encoding: 8bit\n",
                 "Plural-Forms: nplurals=2; plural=(n != 1);\n",
                 "X-Generator: Poedit 3.0.1\n",
                 "X-Poedit-SourceCharset: UTF-8\n"
               ],
               translations: [
                 %Expo.Translation.Singular{msgctxt: nil, msgid: ["foo"], msgstr: ["bar"]},
                 %Expo.Translation.Plural{
                   msgctxt: nil,
                   msgid: ["{count} New Notification"],
                   msgid_plural: ["{count} New Notifications"],
                   msgstr: %{0 => ["{count} Nuova notifica"], 1 => ["{count} Nuove notifiche"]}
                 }
               ]
             } = Mo.parse(@example)
    end
  end
end
