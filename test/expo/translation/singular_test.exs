defmodule Expo.Translation.SingularTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Expo.Translation.Singular

  doctest Singular

  describe "rebalance/1" do
    test "rebalances string" do
      assert %Singular{msgid: ["hello\n", "world"]} =
               Singular.rebalance(%Singular{
                 msgid: ["", "hello", "\n", "", "world", ""],
                 msgstr: []
               })

      assert %Singular{msgstr: ["hello\n", "world"]} =
               Singular.rebalance(%Singular{
                 msgid: [],
                 msgstr: ["", "hello", "\n", "", "world", ""]
               })
    end

    test "puts each flag onto the same line" do
      assert %Singular{flags: [["one", "two", "three"]]} =
               Singular.rebalance(%Singular{
                 msgid: [],
                 msgstr: [],
                 flags: [["one", "two"], ["three"]]
               })
    end

    test "puts each reference onto a new line" do
      assert %Singular{references: [[{"one", 1}], [{"two", 2}], ["three"]]} =
               Singular.rebalance(%Singular{
                 msgid: [],
                 msgstr: [],
                 references: [[{"one", 1}, {"two", 2}], ["three"]]
               })
    end
  end
end
