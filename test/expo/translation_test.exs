defmodule Expo.TranslationTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Expo.Translation

  doctest Translation

  describe "key/1" do
    test "singular" do
      assert {"", "foo"} = Translation.key(%Translation.Singular{msgid: ["foo"], msgstr: []})

      assert {"ctxt", "foo"} =
               Translation.key(%Translation.Singular{msgctxt: "ctxt", msgid: ["foo"], msgstr: []})
    end

    test "plural" do
      assert {"", {"foo", "foos"}} =
               Translation.key(%Translation.Plural{
                 msgid: ["foo"],
                 msgid_plural: ["foos"],
                 msgstr: %{}
               })

      assert {"ctxt", {"foo", "foos"}} =
               Translation.key(%Translation.Plural{
                 msgctxt: "ctxt",
                 msgid: ["foo"],
                 msgid_plural: ["foos"],
                 msgstr: %{}
               })
    end
  end

  describe "same?/2" do
    test "same" do
      t1 = %Translation.Singular{msgid: ["foo"], msgstr: []}
      t2 = %Translation.Singular{msgid: ["", "foo"], msgstr: []}
      assert Translation.same?(t1, t2)
    end

    test "different" do
      t1 = %Translation.Singular{msgid: ["foo"], msgstr: []}
      t2 = %Translation.Singular{msgid: ["bar"], msgstr: []}
      refute Translation.same?(t1, t2)
    end
  end

  describe "has_flag?/2" do
    test "works" do
      singular = %Translation.Singular{
        msgid: [],
        msgstr: [],
        flags: [["one", "oneplushalf"], [], ["two"]]
      }

      plural = %Translation.Plural{
        msgid: [],
        msgid_plural: [],
        msgstr: %{},
        flags: [["one", "oneplushalf"], [], ["two"]]
      }

      assert Translation.has_flag?(singular, "one")
      assert Translation.has_flag?(singular, "oneplushalf")
      refute Translation.has_flag?(singular, "three")

      assert Translation.has_flag?(plural, "one")
      assert Translation.has_flag?(plural, "oneplushalf")
      refute Translation.has_flag?(plural, "three")
    end
  end

  describe "append_flag/2" do
    test "works" do
      singular_empty = %Translation.Singular{msgid: [], msgstr: []}

      singular_multiline = %Translation.Singular{
        singular_empty
        | flags: [["one", "oneplushalf"], [], ["two"]]
      }

      singular_oneline = %Translation.Singular{
        singular_empty
        | flags: [["one", "oneplushalf", "two"]]
      }

      plural = %Translation.Plural{
        msgid: [],
        msgid_plural: [],
        msgstr: %{}
      }

      assert %Translation.Singular{flags: [["one", "oneplushalf"], [], ["two"]]} =
               Translation.append_flag(singular_multiline, "one")

      assert %Translation.Singular{flags: [["one", "oneplushalf"], [], ["two"], ["three"]]} =
               Translation.append_flag(singular_multiline, "three")

      assert %Translation.Singular{flags: [["one", "oneplushalf", "two"]]} =
               Translation.append_flag(singular_oneline, "one")

      assert %Translation.Singular{flags: [["one", "oneplushalf", "two", "three"]]} =
               Translation.append_flag(singular_oneline, "three")

      assert %Translation.Singular{flags: [["one"]]} =
               Translation.append_flag(singular_empty, "one")

      assert %Translation.Plural{flags: [["one"]]} = Translation.append_flag(plural, "one")
    end
  end
end
