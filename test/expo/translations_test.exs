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
end
