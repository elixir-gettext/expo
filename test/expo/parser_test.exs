defmodule Expo.ParserTest do
  use ExUnit.Case, async: true

  alias Expo.Message
  alias Expo.Messages
  alias Expo.PO
  alias Expo.PO.SyntaxError

  describe "singular messages" do
    test "with single strings" do
      assert [%Message.Singular{msgid: ["hel", "l", "o"], msgstr: ["ciao"]} = message] =
               parse("""
               msgid "hel" "l"
               "o"
               msgstr "ciao"
               """)

      assert Message.source_line_number(message, :msgstr) == 3
    end

    test "with multiple concatenated strings" do
      assert [
               %Message.Singular{msgid: ["hello", " world"], msgstr: ["ciao", " mondo"]}
             ] =
               parse("""
               msgid "hello" " world"
               msgstr "ciao" " mondo"
               """)
    end

    test "with multiple messages" do
      assert [
               %Message.Singular{msgid: ["hello"], msgstr: ["ciao"]},
               %Message.Singular{msgid: ["word"], msgstr: ["parola"]}
             ] =
               parse("""
               msgid "hello"
               msgstr "ciao"
               msgid "word"
               msgstr "parola"
               """)
    end

    test "with unicode characters in the strings" do
      assert [%Message.Singular{msgid: ["føø"], msgstr: ["bårπ"]}] =
               parse("""
               msgid "føø"
               msgstr "bårπ"
               """)
    end
  end

  describe "plural messages" do
    test "with single strings" do
      assert [
               %Message.Plural{
                 msgid: ["foo"],
                 msgid_plural: ["foos"],
                 msgstr: %{0 => ["bar"], 1 => ["bars"], 2 => ["barres"]}
               } = message
             ] =
               parse("""
               msgid "foo"
               msgid_plural "foos"
               msgstr[0] "bar"
               msgstr[1] "bars"
               msgstr[2] "barres"
               """)

      assert Message.source_line_number(message, {:msgstr, 2}) == 5
    end

    test "with multiple concatenated strings" do
      assert [
               %Message.Plural{
                 msgid: ["foo", "bar"],
                 msgid_plural: ["foos", "bars", "bazzes"],
                 msgstr: %{0 => ["bar", "bar"], 1 => ["bars", "bars"], 2 => ["barres", "barres"]}
               } = message
             ] =
               parse("""
               msgid "foo" "bar"
               msgid_plural "foos" "bars"
                 "bazzes"
               msgstr[0] "bar" "bar"
               msgstr[1] "bars" "bars"
               msgstr[2] "barres" "barres"
               """)

      assert Message.source_line_number(message, {:msgstr, 2}) == 6
    end
  end

  describe "#| (previous) comments" do
    test "with singular message" do
      assert [
               %Message.Singular{
                 msgid: ["", "foo\n", "bar\n", "baz\n"],
                 msgstr: ["bar"],
                 previous_messages: [%Message.Singular{msgid: ["", "fo\n", "bar\n", "baz\n"]}],
                 comments: [],
                 flags: [["fuzzy"]],
                 references: [[{"reference", 7}]]
               },
               %Message.Singular{
                 msgid: ["hello dude"],
                 msgstr: ["ciao"],
                 previous_messages: [
                   %Message.Plural{
                     msgid: ["holla amigo"],
                     msgid_plural: ["holla amigos"]
                   }
                 ]
               }
             ] =
               parse(~S"""
               #: reference:7
               #, fuzzy
               #| msgid ""
               #| "fo\n"
               #| "bar\n"
               #| "baz\n"
               msgid ""
               "foo\n"
               "bar\n"
               "baz\n"
               msgstr "bar"

               #| msgid "holla amigo"
               #| msgid_plural "holla amigos"
               msgid "hello dude"
               msgstr "ciao"
               """)
    end

    test "with plural message" do
      assert [
               %Message.Plural{
                 msgid: ["new"],
                 msgid_plural: ["news"],
                 msgstr: %{0 => ["translated"]},
                 previous_messages: [%Message.Plural{msgid: ["old"], msgid_plural: ["olds"]}]
               }
             ] =
               parse(~S"""
               #: reference:8
               #| msgid "old"
               #| msgid_plural "olds"
               msgid "new"
               msgid_plural "news"
               msgstr[0] "translated"
               """)
    end

    test "with singular message with previous msgctxt" do
      assert [
               %Message.Singular{
                 msgctxt: ["context"],
                 msgid: ["untranslated-string"],
                 msgstr: ["translated-string"],
                 previous_messages: [
                   %Message.Singular{
                     msgctxt: ["previous-context"],
                     msgid: ["previous-untranslated-string"]
                   }
                 ]
               }
             ] =
               parse(~S"""
               #| msgctxt "previous-context"
               #| msgid "previous-untranslated-string"
               msgctxt "context"
               msgid "untranslated-string"
               msgstr "translated-string"
               """)
    end

    test "with plural message with previous msgctxt" do
      assert [
               %Message.Plural{
                 msgctxt: ["context"],
                 msgid: ["untranslated-string"],
                 msgid_plural: ["untranslated-strings"],
                 msgstr: %{0 => ["translated-string"]},
                 previous_messages: [
                   %Message.Plural{
                     msgctxt: ["previous-context"],
                     msgid: ["previous-untranslated-string"],
                     msgid_plural: ["previous-untranslated-strings"]
                   }
                 ]
               }
             ] =
               parse(~S"""
               #| msgctxt "previous-context"
               #| msgid "previous-untranslated-string"
               #| msgid_plural "previous-untranslated-strings"
               msgctxt "context"
               msgid "untranslated-string"
               msgid_plural "untranslated-strings"
               msgstr[0] "translated-string"
               """)
    end
  end

  describe "generic comments" do
    test "are associated with messages" do
      assert [
               %Message.Singular{
                 msgid: ["foo"],
                 msgstr: ["bar"],
                 comments: [" This is a message", " Ah, another comment!"],
                 extracted_comments: [" An extracted comment"],
                 references: [[{"lib/foo.ex", 32}]]
               }
             ] =
               parse("""
               # This is a message
               #: lib/foo.ex:32
               # Ah, another comment!
               #. An extracted comment
               msgid "foo"
               msgstr "bar"
               """)
    end

    test "always belong to the next message" do
      assert [
               %Message.Singular{msgid: ["a"], msgstr: ["b"]},
               %Message.Singular{msgid: ["c"], msgstr: ["d"], comments: [" Comment"]}
             ] =
               parse("""
               msgid "a"
               msgstr "b"
               # Comment
               msgid "c"
               msgstr "d"
               """)
    end

    test "can't be placed between 'msgid' and 'msgstr'" do
      assert %SyntaxError{reason: "syntax error before: \"# Comment\"", line: 2} =
               parse_error("""
               msgid "foo"
               # Comment
               msgstr "bar"
               """)

      assert %SyntaxError{reason: "syntax error before: \"# Comment\"", line: 3} =
               parse_error("""
               msgid "foo"
               msgid_plural "foo"
               # Comment
               msgstr[0] "bar"
               """)
    end
  end

  defp parse(string) do
    assert {:ok, %Messages{messages: messages}} = PO.parse_string(string)
    messages
  end

  defp parse_error(string) do
    assert {:error, %SyntaxError{} = error} = PO.parse_string(string)
    error
  end
end
