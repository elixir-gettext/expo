defmodule Expo.Composer.PoTest do
  @moduledoc false

  # Tests taken & adapted from
  # https://github.com/elixir-gettext/gettext/blob/600e4630fb7db514d464f92e2069a138cf9c68a1/test/gettext/po_test.exs#L227

  use ExUnit.Case, async: true

  alias Expo.Composer.Po
  alias Expo.Translation
  alias Expo.Translations

  doctest Po

  test "single translation" do
    translations = %Translations{
      headers: [],
      translations: [
        %Translation.Singular{msgid: ["foo"], msgstr: ["bar"]}
      ]
    }

    assert IO.iodata_to_binary(Po.compose(translations)) == ~S"""
           msgid "foo"
           msgstr "bar"
           """
  end

  test "single plural translation" do
    translations = %Translations{
      headers: [],
      translations: [
        %Translation.Plural{
          msgid: ["one foo"],
          msgid_plural: ["%{count} foos"],
          msgstr: %{
            0 => ["one bar"],
            1 => ["%{count} bars"]
          }
        }
      ]
    }

    assert IO.iodata_to_binary(Po.compose(translations)) == ~S"""
           msgid "one foo"
           msgid_plural "%{count} foos"
           msgstr[0] "one bar"
           msgstr[1] "%{count} bars"
           """
  end

  test "multiple translations" do
    translations = %Translations{
      headers: [],
      translations: [
        %Translation.Singular{msgid: ["foo"], msgstr: ["bar"]},
        %Translation.Singular{msgid: ["baz"], msgstr: ["bong"]}
      ]
    }

    assert IO.iodata_to_binary(Po.compose(translations)) == ~S"""
           msgid "foo"
           msgstr "bar"

           msgid "baz"
           msgstr "bong"
           """
  end

  test "translation with comments" do
    translations = %Translations{
      headers: [],
      translations: [
        %Translation.Singular{
          msgid: ["foo"],
          msgstr: ["bar"],
          comments: ["comment", "another comment"]
        }
      ]
    }

    assert IO.iodata_to_binary(Po.compose(translations)) == ~S"""
           # comment
           # another comment
           msgid "foo"
           msgstr "bar"
           """
  end

  test "translation with extracted comments" do
    translations = %Translations{
      headers: [],
      translations: [
        %Translation.Singular{
          msgid: ["foo"],
          msgstr: ["bar"],
          extracted_comments: ["some comment", "another comment"]
        }
      ]
    }

    assert IO.iodata_to_binary(Po.compose(translations)) == ~S"""
           #. some comment
           #. another comment
           msgid "foo"
           msgstr "bar"
           """
  end

  test "references" do
    translations = %Translations{
      translations: [
        %Translation.Singular{
          msgid: ["foo"],
          msgstr: ["bar"],
          references: [[{"foo.ex", 1}, {"lib/bar.ex", 2}], ["file_without_line"]]
        },
        %Translation.Plural{
          msgid: ["foo"],
          msgid_plural: ["foos"],
          msgstr: %{0 => [""], 1 => [""]},
          references: [[{"lib/with spaces.ex", 1}, {"lib/with other spaces.ex", 2}]]
        }
      ]
    }

    assert IO.iodata_to_binary(Po.compose(translations)) == ~S"""
           #: foo.ex:1, lib/bar.ex:2
           #: file_without_line
           msgid "foo"
           msgstr "bar"

           #: lib/with spaces.ex:1, lib/with other spaces.ex:2
           msgid "foo"
           msgid_plural "foos"
           msgstr[0] ""
           msgstr[1] ""
           """
  end

  test "references are wrapped" do
    translations = %Translations{
      translations: [
        %Translation.Singular{
          msgid: ["foo"],
          msgstr: ["bar"],
          references: [
            [{String.duplicate("a", 30) <> ".ex", 1}],
            [{String.duplicate("b", 30) <> ".ex", 1}],
            [{String.duplicate("c", 30) <> ".ex", 1}]
          ]
        }
      ]
    }

    assert IO.iodata_to_binary(Po.compose(translations)) == ~S"""
           #: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.ex:1
           #: bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.ex:1
           #: cccccccccccccccccccccccccccccc.ex:1
           msgid "foo"
           msgstr "bar"
           """
  end

  test "flags" do
    translations = %Translations{
      translations: [
        %Translation.Singular{
          flags: [["bar", "baz", "foo"]],
          comments: ["other comment"],
          msgid: ["foo"],
          msgstr: ["bar"]
        }
      ]
    }

    assert IO.iodata_to_binary(Po.compose(translations)) == ~S"""
           # other comment
           #, bar, baz, foo
           msgid "foo"
           msgstr "bar"
           """
  end

  test "headers" do
    translations = %Translations{
      translations: [],
      headers: [
        "",
        "Content-Type: text/plain\n",
        "Project-Id-Version: xxx\n"
      ]
    }

    assert IO.iodata_to_binary(Po.compose(translations)) == ~S"""
           msgid ""
           msgstr ""
           "Content-Type: text/plain\n"
           "Project-Id-Version: xxx\n"
           """
  end

  test "multiple strings" do
    translations = %Translations{
      headers: [],
      translations: [
        %Translation.Singular{
          msgid: ["", "foo\n", "morefoo\n"],
          msgstr: ["bar", "baz\n", "bang"]
        },
        %Translation.Plural{
          msgid: ["a", "b"],
          msgid_plural: ["as", "bs"],
          msgstr: %{
            0 => ["c", "d"],
            1 => ["e", "f"]
          }
        }
      ]
    }

    assert IO.iodata_to_binary(Po.compose(translations)) == ~S"""
           msgid ""
           "foo\n"
           "morefoo\n"
           msgstr "bar"
           "baz\n"
           "bang"

           msgid "a"
           "b"
           msgid_plural "as"
           "bs"
           msgstr[0] "c"
           "d"
           msgstr[1] "e"
           "f"
           """
  end

  test "headers and multiple (plural) translations with comments" do
    translations = %Translations{
      translations: [
        %Translation.Singular{
          msgid: ["foo"],
          msgstr: ["bar"],
          comments: ["comment", "another comment"]
        },
        %Translation.Plural{
          msgid: ["a foo, %{name}"],
          msgid_plural: ["%{count} foos, %{name}"],
          msgstr: %{0 => ["a bar, %{name}"], 1 => ["%{count} bars, %{name}"]},
          comments: ["comment 1", "comment 2"]
        }
      ],
      headers: [
        "",
        "Project-Id-Version: 1\n",
        "Language: fooesque\n"
      ]
    }

    assert IO.iodata_to_binary(Po.compose(translations)) == ~S"""
           msgid ""
           msgstr ""
           "Project-Id-Version: 1\n"
           "Language: fooesque\n"

           # comment
           # another comment
           msgid "foo"
           msgstr "bar"

           # comment 1
           # comment 2
           msgid "a foo, %{name}"
           msgid_plural "%{count} foos, %{name}"
           msgstr[0] "a bar, %{name}"
           msgstr[1] "%{count} bars, %{name}"
           """
  end

  test "escaped characters in msgid/msgstr" do
    translations = %Translations{
      headers: [],
      translations: [
        %Translation.Singular{msgid: [~s("quotes")], msgstr: [~s(foo "bar" baz)]},
        %Translation.Singular{msgid: [~s(new\nlines\r)], msgstr: [~s(and\ttabs)]}
      ]
    }

    assert IO.iodata_to_binary(Po.compose(translations)) == ~S"""
           msgid "\"quotes\""
           msgstr "foo \"bar\" baz"

           msgid "new\nlines\r"
           msgstr "and\ttabs"
           """
  end

  test "double quotes in headers are escaped" do
    translations = %Translations{headers: [~s(Foo: "bar"\n)], translations: []}

    assert IO.iodata_to_binary(Po.compose(translations)) == ~S"""
           msgid ""
           msgstr "Foo: \"bar\"\n"
           """
  end

  test "multiple translations with msgctxt" do
    translations = %Translations{
      headers: [],
      translations: [
        %Translation.Singular{msgid: ["foo"], msgstr: ["bar"]},
        %Translation.Singular{msgid: ["foo"], msgstr: ["bong"], msgctxt: ["baz"]}
      ]
    }

    assert IO.iodata_to_binary(Po.compose(translations)) == ~S"""
           msgid "foo"
           msgstr "bar"

           msgctxt "baz"
           msgid "foo"
           msgstr "bong"
           """
  end

  test "single plural translation with msgctxt" do
    translations = %Translations{
      headers: [],
      translations: [
        %Translation.Plural{
          msgid: ["one foo"],
          msgid_plural: ["%{count} foos"],
          msgstr: %{
            0 => ["one bar"],
            1 => ["%{count} bars"]
          },
          msgctxt: ["baz"]
        }
      ]
    }

    assert IO.iodata_to_binary(Po.compose(translations)) == ~S"""
           msgctxt "baz"
           msgid "one foo"
           msgid_plural "%{count} foos"
           msgstr[0] "one bar"
           msgstr[1] "%{count} bars"
           """
  end

  test "single translation with previous msgid" do
    translations = %Translations{
      headers: [],
      translations: [
        %Translation.Singular{
          msgid: ["foo"],
          msgstr: ["bar"],
          previous_msgids: ["test"]
        }
      ]
    }

    assert IO.iodata_to_binary(Po.compose(translations)) == ~S"""
           #| msgid "test"
           msgid "foo"
           msgstr "bar"
           """
  end

  test "single obsolete translation" do
    translations = %Translations{
      headers: [],
      translations: [
        %Translation.Singular{
          msgid: ["foo"],
          msgstr: ["bar"],
          obsolete: true
        }
      ]
    }

    assert IO.iodata_to_binary(Po.compose(translations)) == ~S"""
           #~ msgid "foo"
           #~ msgstr "bar"
           """
  end
end
