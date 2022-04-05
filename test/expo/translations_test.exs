defmodule Expo.TranslationsTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Expo.Translation
  alias Expo.Translations

  doctest Translations

  describe "rebalance/1" do
    test "rebalances headers" do
      assert %Translations{headers: ["", "hello\n", "world"]} =
               Translations.rebalance(%Translations{
                 headers: ["hello\n", "world"],
                 translations: []
               })

      assert %Translations{headers: []} =
               Translations.rebalance(%Translations{
                 headers: [],
                 translations: []
               })
    end

    test "rebalances translations" do
      assert %Translations{translations: [%Translation.Singular{msgid: ["hello\n", "world"]}]} =
               Translations.rebalance(%Translations{
                 headers: [],
                 translations: [
                   %Translation.Singular{
                     msgid: ["", "hello", "\n", "", "world", ""],
                     msgstr: []
                   }
                 ]
               })
    end
  end

  describe "get_header/2" do
    test "gets single line header case insensitive" do
      assert Translations.get_header(
               %Translations{headers: ["Language: en_US\n"], translations: []},
               "language"
             ) == ["en_US"]
    end

    test "gets multi line header case insensitive" do
      assert Translations.get_header(
               %Translations{
                 headers: [
                   ~S"""
                   Plural-Forms: nplurals=6; \
                     plural=n==0 ? 0 : n==1 ? 1 : n==2 ? 2 : n%100>=3 && n%100<=10 ? 3 \
                     : n%100>=11 ? 4 : 5;
                   """
                 ],
                 translations: []
               },
               "plural-forms"
             ) == [
               String.trim(~S"""
               nplurals=6; \
                 plural=n==0 ? 0 : n==1 ? 1 : n==2 ? 2 : n%100>=3 && n%100<=10 ? 3 \
                 : n%100>=11 ? 4 : 5;
               """)
             ]
    end

    test "gets non existant header" do
      assert Translations.get_header(%Translations{headers: [], translations: []}, "language") ==
               []
    end

    test "gets multiple headers iwth same name" do
      assert Translations.get_header(
               %Translations{
                 headers: [
                   """
                   Translator: José
                   Translator: Jonatan
                   """
                 ],
                 translations: []
               },
               "translator"
             ) == ["José", "Jonatan"]
    end
  end
end
