defmodule Expo.MessageTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Expo.Message

  doctest Message

  describe "key/1" do
    test "singular" do
      assert {"", "foo"} = Message.key(%Message.Singular{msgid: ["foo"], msgstr: []})

      assert {"ctxt", "foo"} =
               Message.key(%Message.Singular{msgctxt: "ctxt", msgid: ["foo"], msgstr: []})
    end

    test "plural" do
      assert {"", {"foo", "foos"}} =
               Message.key(%Message.Plural{
                 msgid: ["foo"],
                 msgid_plural: ["foos"],
                 msgstr: %{}
               })

      assert {"ctxt", {"foo", "foos"}} =
               Message.key(%Message.Plural{
                 msgctxt: "ctxt",
                 msgid: ["foo"],
                 msgid_plural: ["foos"],
                 msgstr: %{}
               })
    end
  end

  describe "same?/2" do
    test "same" do
      t1 = %Message.Singular{msgid: ["foo"], msgstr: []}
      t2 = %Message.Singular{msgid: ["", "foo"], msgstr: []}
      assert Message.same?(t1, t2)
    end

    test "different" do
      t1 = %Message.Singular{msgid: ["foo"], msgstr: []}
      t2 = %Message.Singular{msgid: ["bar"], msgstr: []}
      refute Message.same?(t1, t2)
    end
  end

  describe "has_flag?/2" do
    test "works" do
      singular = %Message.Singular{
        msgid: [],
        msgstr: [],
        flags: [["one", "oneplushalf"], [], ["two"]]
      }

      plural = %Message.Plural{
        msgid: [],
        msgid_plural: [],
        msgstr: %{},
        flags: [["one", "oneplushalf"], [], ["two"]]
      }

      assert Message.has_flag?(singular, "one")
      assert Message.has_flag?(singular, "oneplushalf")
      refute Message.has_flag?(singular, "three")

      assert Message.has_flag?(plural, "one")
      assert Message.has_flag?(plural, "oneplushalf")
      refute Message.has_flag?(plural, "three")
    end
  end

  describe "append_flag/2" do
    test "works" do
      singular_empty = %Message.Singular{msgid: [], msgstr: []}

      singular_multiline = %Message.Singular{
        singular_empty
        | flags: [["one", "oneplushalf"], [], ["two"]]
      }

      singular_oneline = %Message.Singular{
        singular_empty
        | flags: [["one", "oneplushalf", "two"]]
      }

      plural = %Message.Plural{
        msgid: [],
        msgid_plural: [],
        msgstr: %{}
      }

      assert %Message.Singular{flags: [["one", "oneplushalf"], [], ["two"]]} =
               Message.append_flag(singular_multiline, "one")

      assert %Message.Singular{flags: [["one", "oneplushalf"], [], ["two"], ["three"]]} =
               Message.append_flag(singular_multiline, "three")

      assert %Message.Singular{flags: [["one", "oneplushalf", "two"]]} =
               Message.append_flag(singular_oneline, "one")

      assert %Message.Singular{flags: [["one", "oneplushalf", "two", "three"]]} =
               Message.append_flag(singular_oneline, "three")

      assert %Message.Singular{flags: [["one"]]} = Message.append_flag(singular_empty, "one")

      assert %Message.Plural{flags: [["one"]]} = Message.append_flag(plural, "one")
    end
  end
end
