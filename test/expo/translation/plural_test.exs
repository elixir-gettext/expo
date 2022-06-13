defmodule Expo.Message.PluralTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Expo.Message.Plural

  doctest Plural

  describe "rebalance/1" do
    test "rebalances string" do
      assert %Plural{msgid: ["hello\n", "world"]} =
               Plural.rebalance(%Plural{
                 msgid: ["", "hello", "\n", "", "world", ""],
                 msgid_plural: [],
                 msgstr: %{}
               })

      assert %Plural{msgid_plural: ["hello\n", "world"]} =
               Plural.rebalance(%Plural{
                 msgid: [],
                 msgid_plural: ["", "hello", "\n", "", "world", ""],
                 msgstr: %{}
               })

      assert %Plural{msgstr: %{0 => ["hello\n", "world"]}} =
               Plural.rebalance(%Plural{
                 msgid: [],
                 msgid_plural: [],
                 msgstr: %{0 => ["", "hello", "\n", "", "world", ""]}
               })
    end

    test "puts each flag onto the same line" do
      assert %Plural{flags: [["one", "two", "three"]]} =
               Plural.rebalance(%Plural{
                 msgid: [],
                 msgid_plural: [],
                 msgstr: %{},
                 flags: [["one", "two"], ["three"]]
               })
    end

    test "puts each reference onto a new line" do
      assert %Plural{references: [[{"one", 1}], [{"two", 2}], ["three"]]} =
               Plural.rebalance(%Plural{
                 msgid: [],
                 msgid_plural: [],
                 msgstr: %{},
                 references: [[{"one", 1}, {"two", 2}], ["three"]]
               })
    end
  end
end
