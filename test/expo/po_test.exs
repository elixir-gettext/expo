defmodule Expo.POTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Expo.Message
  alias Expo.Messages
  alias Expo.PO
  alias Expo.PO.DuplicateMessagesError
  alias Expo.PO.SyntaxError

  doctest PO

  describe "compose/2" do
    test "single message" do
      messages = %Messages{
        headers: [],
        messages: [
          %Message.Singular{msgid: ["foo"], msgstr: ["bar"]}
        ]
      }

      assert IO.iodata_to_binary(PO.compose(messages)) == ~S"""
             msgid "foo"
             msgstr "bar"
             """
    end

    test "single plural message" do
      messages = %Messages{
        headers: [],
        messages: [
          %Message.Plural{
            msgid: ["one foo"],
            msgid_plural: ["%{count} foos"],
            msgstr: %{
              0 => ["one bar"],
              1 => ["%{count} bars"]
            }
          }
        ]
      }

      assert IO.iodata_to_binary(PO.compose(messages)) == ~S"""
             msgid "one foo"
             msgid_plural "%{count} foos"
             msgstr[0] "one bar"
             msgstr[1] "%{count} bars"
             """
    end

    test "multiple messages" do
      messages = %Messages{
        headers: [],
        messages: [
          %Message.Singular{msgid: ["foo"], msgstr: ["bar"]},
          %Message.Singular{msgid: ["baz"], msgstr: ["bong"]}
        ]
      }

      assert IO.iodata_to_binary(PO.compose(messages)) == ~S"""
             msgid "foo"
             msgstr "bar"

             msgid "baz"
             msgstr "bong"
             """
    end

    test "message with comments" do
      messages = %Messages{
        headers: [],
        messages: [
          %Message.Singular{
            msgid: ["foo"],
            msgstr: ["bar"],
            comments: [" comment", " another comment"]
          }
        ]
      }

      assert IO.iodata_to_binary(PO.compose(messages)) == ~S"""
             # comment
             # another comment
             msgid "foo"
             msgstr "bar"
             """
    end

    test "message with extracted comments" do
      messages = %Messages{
        headers: [],
        messages: [
          %Message.Singular{
            msgid: ["foo"],
            msgstr: ["bar"],
            extracted_comments: [" some comment", " another comment"]
          }
        ]
      }

      assert IO.iodata_to_binary(PO.compose(messages)) == ~S"""
             #. some comment
             #. another comment
             msgid "foo"
             msgstr "bar"
             """
    end

    test "references" do
      messages = %Messages{
        messages: [
          %Message.Singular{
            msgid: ["foo"],
            msgstr: ["bar"],
            references: [[{"foo.ex", 1}, {"lib/bar.ex", 2}], ["file_without_line"]]
          },
          %Message.Plural{
            msgid: ["foo"],
            msgid_plural: ["foos"],
            msgstr: %{0 => [""], 1 => [""]},
            references: [[{"lib/with spaces.ex", 1}, {"lib/with other spaces.ex", 2}]]
          }
        ]
      }

      assert IO.iodata_to_binary(PO.compose(messages)) == ~S"""
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
      messages = %Messages{
        messages: [
          %Message.Singular{
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

      assert IO.iodata_to_binary(PO.compose(messages)) == ~S"""
             #: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.ex:1
             #: bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.ex:1
             #: cccccccccccccccccccccccccccccc.ex:1
             msgid "foo"
             msgstr "bar"
             """
    end

    test "flags" do
      messages = %Messages{
        messages: [
          %Message.Singular{
            flags: [["bar", "baz", "foo"]],
            comments: [" other comment"],
            msgid: ["foo"],
            msgstr: ["bar"]
          }
        ]
      }

      assert IO.iodata_to_binary(PO.compose(messages)) == ~S"""
             # other comment
             #, bar, baz, foo
             msgid "foo"
             msgstr "bar"
             """
    end

    test "headers" do
      messages = %Messages{
        messages: [],
        headers: [
          "",
          "Content-Type: text/plain\n",
          "Project-Id-Version: xxx\n"
        ]
      }

      assert IO.iodata_to_binary(PO.compose(messages)) == ~S"""
             msgid ""
             msgstr ""
             "Content-Type: text/plain\n"
             "Project-Id-Version: xxx\n"
             """
    end

    test "multiple strings" do
      messages = %Messages{
        headers: [],
        messages: [
          %Message.Singular{
            msgid: ["", "foo\n", "morefoo\n"],
            msgstr: ["bar", "baz\n", "bang"]
          },
          %Message.Plural{
            msgid: ["a", "b"],
            msgid_plural: ["as", "bs"],
            msgstr: %{
              0 => ["c", "d"],
              1 => ["e", "f"]
            }
          }
        ]
      }

      assert IO.iodata_to_binary(PO.compose(messages)) == ~S"""
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

    test "headers and multiple (plural) messages with comments" do
      messages = %Messages{
        messages: [
          %Message.Singular{
            msgid: ["foo"],
            msgstr: ["bar"],
            comments: [" comment", " another comment"]
          },
          %Message.Plural{
            msgid: ["a foo, %{name}"],
            msgid_plural: ["%{count} foos, %{name}"],
            msgstr: %{0 => ["a bar, %{name}"], 1 => ["%{count} bars, %{name}"]},
            comments: [" comment 1", " comment 2"]
          }
        ],
        headers: [
          "",
          "Project-Id-Version: 1\n",
          "Language: fooesque\n"
        ]
      }

      assert IO.iodata_to_binary(PO.compose(messages)) == ~S"""
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
      messages = %Messages{
        headers: [],
        messages: [
          %Message.Singular{msgid: [~s("quotes")], msgstr: [~s(foo "bar" baz)]},
          %Message.Singular{msgid: [~s(new\nlines\r)], msgstr: [~s(and\ttabs)]}
        ]
      }

      assert IO.iodata_to_binary(PO.compose(messages)) == ~S"""
             msgid "\"quotes\""
             msgstr "foo \"bar\" baz"

             msgid "new\nlines\r"
             msgstr "and\ttabs"
             """
    end

    test "double quotes in headers are escaped" do
      messages = %Messages{headers: [~s(Foo: "bar"\n)], messages: []}

      assert IO.iodata_to_binary(PO.compose(messages)) == ~S"""
             msgid ""
             msgstr "Foo: \"bar\"\n"
             """
    end

    test "multiple messages with msgctxt" do
      messages = %Messages{
        headers: [],
        messages: [
          %Message.Singular{msgid: ["foo"], msgstr: ["bar"]},
          %Message.Singular{msgid: ["foo"], msgstr: ["bong"], msgctxt: ["baz"]}
        ]
      }

      assert IO.iodata_to_binary(PO.compose(messages)) == ~S"""
             msgid "foo"
             msgstr "bar"

             msgctxt "baz"
             msgid "foo"
             msgstr "bong"
             """
    end

    test "single plural message with msgctxt" do
      messages = %Messages{
        headers: [],
        messages: [
          %Message.Plural{
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

      assert IO.iodata_to_binary(PO.compose(messages)) == ~S"""
             msgctxt "baz"
             msgid "one foo"
             msgid_plural "%{count} foos"
             msgstr[0] "one bar"
             msgstr[1] "%{count} bars"
             """
    end

    test "single message with previous msgid" do
      messages = %Messages{
        headers: [],
        messages: [
          %Message.Singular{
            msgid: ["foo"],
            msgstr: ["bar"],
            previous_messages: [%Message.Singular{msgid: ["test"]}]
          }
        ]
      }

      assert IO.iodata_to_binary(PO.compose(messages)) == ~S"""
             #| msgid "test"
             msgid "foo"
             msgstr "bar"
             """
    end

    test "single obsolete message" do
      messages = %Messages{
        headers: [],
        messages: [
          %Message.Singular{
            msgid: ["fo", "o"],
            msgstr: ["bar"],
            obsolete: true
          }
        ]
      }

      assert IO.iodata_to_binary(PO.compose(messages)) == ~S"""
             #~ msgid "fo"
             #~ "o"
             #~ msgstr "bar"
             """
    end

    test "with previous msgid" do
      messages = %Messages{
        messages: [
          %Message.Singular{
            msgid: ["hello"],
            msgstr: ["ciao"],
            previous_messages: [%Message.Singular{msgid: ["holla"]}]
          },
          %Message.Plural{
            msgid: ["hello amigo"],
            msgid_plural: ["hello amigos"],
            msgstr: %{0 => ["ciao"]},
            previous_messages: [
              %Message.Plural{
                msgid: ["holla amigo"],
                msgid_plural: ["holla amigos"]
              }
            ]
          }
        ]
      }

      assert IO.iodata_to_binary(PO.compose(messages)) == ~S"""
             #| msgid "holla"
             msgid "hello"
             msgstr "ciao"

             #| msgid "holla amigo"
             #| msgid_plural "holla amigos"
             msgid "hello amigo"
             msgid_plural "hello amigos"
             msgstr[0] "ciao"
             """
    end
  end

  describe "parse_string/1" do
    test "with single strings" do
      assert {:ok,
              %Messages{
                messages: [
                  %Message.Singular{msgid: ["hel", "l", "o"], msgstr: ["ciao"]} = message
                ]
              }} =
               PO.parse_string("""
               msgid "hel" "l"
               "o"
               msgstr "ciao"
               """)

      assert 3 == Message.source_line_number(message, :msgstr)
    end

    test "with singular previous msgid" do
      assert {:ok,
              %Messages{
                messages: [
                  %Message.Singular{
                    msgid: ["", "foo\n", "bar\n", "baz\n"],
                    msgstr: ["bar"],
                    previous_messages: [%Message.Singular{msgid: ["", "fo\n", "bar\n", "baz\n"]}]
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
                ]
              }} =
               PO.parse_string(~S"""
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

    test "with plural previous msgid" do
      assert {:ok,
              %Messages{
                messages: [
                  %Message.Plural{
                    msgid: ["new"],
                    msgid_plural: ["news"],
                    msgstr: %{0 => ["translated"]},
                    previous_messages: [%Message.Plural{msgid: ["old"], msgid_plural: ["olds"]}]
                  }
                ]
              }} =
               PO.parse_string(~S"""
               #: reference:8
               #| msgid "old"
               #| msgid_plural "olds"
               msgid "new"
               msgid_plural "news"
               msgstr[0] "translated"
               """)
    end

    test "with obsolete message" do
      assert {:ok,
              %Messages{
                messages: [
                  %Message.Singular{
                    msgid: ["hel", "l", "o"],
                    msgstr: ["ciao"],
                    comments: [" comment"],
                    obsolete: true
                  },
                  %Message.Plural{
                    msgid: ["hell", "o"],
                    msgid_plural: ["hell", "os"],
                    msgstr: %{0 => ["holl", "a"]},
                    comments: [" comment", " comment"],
                    previous_messages: [%Message.Singular{msgid: ["test"]}],
                    obsolete: true
                  }
                ]
              }} =
               PO.parse_string("""
               # comment
               #~ msgid "hel" "l"
               #~ "o"
               #~ msgstr "ciao"

               # comment
               #~ # comment
               #~ #| msgid "test"
               #~ msgid "hell"
               #~ "o"
               #~ msgid_plural "hell"
               #~ "os"
               #~ msgstr[0] "holl"
               #~ "a"
               """)
    end

    test "with multiple concatenated strings" do
      assert {:ok,
              %Messages{
                messages: [
                  %Message.Singular{msgid: ["hello", " world"], msgstr: ["ciao", " mondo"]}
                ]
              }} =
               PO.parse_string("""
               msgid "hello" " world"
               msgstr "ciao" " mondo"
               """)
    end

    test "with multiple messages" do
      assert {:ok,
              %Messages{
                messages: [
                  %Message.Singular{msgid: ["hello"], msgstr: ["ciao"]},
                  %Message.Singular{msgid: ["word"], msgstr: ["parola"]}
                ]
              }} =
               PO.parse_string("""
               msgid "hello"
               msgstr "ciao"
               msgid "word"
               msgstr "parola"
               """)
    end

    test "with unicode characters in the strings" do
      assert {:ok,
              %Messages{
                messages: [%Message.Singular{msgid: ["føø"], msgstr: ["bårπ"]}]
              }} =
               PO.parse_string("""
               msgid "føø"
               msgstr "bårπ"
               """)
    end

    test "with a pluralized string" do
      assert {:ok,
              %Messages{
                messages: [
                  %Message.Plural{
                    msgid: ["foo"],
                    msgstr: %{0 => ["bar"], 1 => ["bars"], 2 => ["barres"]}
                  } = message
                ]
              }} =
               PO.parse_string("""
               msgid "foo"
               msgid_plural "foos"
               msgstr[0] "bar"
               msgstr[1] "bars"
               msgstr[2] "barres"
               """)

      assert 5 == Message.source_line_number(message, {:msgstr, 2})
    end

    test "comments are associated with messages" do
      assert {:ok,
              %Messages{
                messages: [
                  %Message.Singular{
                    msgid: ["foo"],
                    msgstr: ["bar"],
                    comments: [" This is a message", " Ah, another comment!"],
                    extracted_comments: [" An extracted comment"],
                    references: [[{"lib/foo.ex", 32}]]
                  }
                ]
              }} =
               PO.parse_string("""
               # This is a message
               #: lib/foo.ex:32
               # Ah, another comment!
               #. An extracted comment
               msgid "foo"
               msgstr "bar"
               """)
    end

    test "comments always belong to the next message" do
      assert {:ok,
              %Messages{
                messages: [
                  %Message.Singular{msgid: ["a"], msgstr: ["b"]},
                  %Message.Singular{msgid: ["c"], msgstr: ["d"], comments: [" Comment"]}
                ]
              }} =
               PO.parse_string("""
               msgid "a"
               msgstr "b"
               # Comment
               msgid "c"
               msgstr "d"
               """)
    end

    test "syntax error when there is no 'msgid'" do
      assert {:error, %SyntaxError{reason: "syntax error before: msgstr", line: 1}} =
               PO.parse_string("msgstr \"foo\"")

      assert {:error, %SyntaxError{reason: "syntax error before: msgstr", line: 1}} =
               PO.parse_string("msgstr \"foo\"")

      assert {:error, %SyntaxError{reason: "syntax error before: \"foo\"", line: 1}} =
               PO.parse_string("\"foo\"")
    end

    test "if there's a msgid_plural, then plural forms must follow" do
      assert {:error, %SyntaxError{reason: "syntax error before: \"bar\"", line: 3}} =
               PO.parse_string("""
               msgid "foo"
               msgid_plural "foos"
               msgstr "bar"
               """)
    end

    test "'msgid_plural' must come after 'msgid'" do
      assert {:error, %SyntaxError{reason: "syntax error before: msgid_plural", line: 1}} =
               PO.parse_string("msgid_plural ")
    end

    test "comments can't be placed between 'msgid' and 'msgstr'" do
      assert {:error, %SyntaxError{reason: "syntax error before: \"# Comment\"", line: 2}} =
               PO.parse_string("""
               msgid "foo"
               # Comment
               msgstr "bar"
               """)

      assert {:error, %SyntaxError{reason: "syntax error before: \"# Comment\"", line: 3}} =
               PO.parse_string("""
               msgid "foo"
               msgid_plural "foo"
               # Comment
               msgstr[0] "bar"
               """)
    end

    test "files with just comments are ok" do
      assert {:ok, %Messages{top_comments: ["# A comment", "# Another comment"]}} =
               PO.parse_string("""
               # A comment
               # Another comment
               """)
    end

    test "reference are extracted into the :reference field of a message" do
      assert {:ok, %Messages{messages: [%Message.Singular{} = message]}} =
               PO.parse_string("""
               #: foo.ex:1
               #: f:2
               #: filename with spaces.ex:12
               # Not a reference comment
               # : Not a reference comment either
               #: another/ref/comment.ex:83
               #: reference_without_line
               msgid "foo"
               msgstr "bar"
               """)

      assert message.references == [
               [{"foo.ex", 1}],
               [{"f", 2}],
               [{"filename with spaces.ex", 12}],
               [{"another/ref/comment.ex", 83}],
               ["reference_without_line"]
             ]

      # All the reference comments are removed.
      assert message.comments == [
               " Not a reference comment",
               " : Not a reference comment either"
             ]
    end

    test "extracted comments are extracted into the :extracted_comments field of a message" do
      assert {:ok, %Messages{messages: [%Message.Singular{} = message]}} =
               PO.parse_string("""
               #. Extracted comment
               # Not an extracted comment
               #.Another extracted comment
               msgid "foo"
               msgstr "bar"
               """)

      assert message.extracted_comments == [
               " Extracted comment",
               "Another extracted comment"
             ]

      # All the reference comments are removed.
      assert message.comments == [
               " Not an extracted comment"
             ]
    end

    test "flags are extracted in to the :flags field of a message" do
      assert {:ok, %Messages{messages: [%Message.Singular{} = message]}} =
               PO.parse_string("""
               #, flag,a-flag b-flag, c-flag
               # comment
               #, flag,  ,d-flag ,, e-flag
               msgid "foo"
               msgstr "bar"
               """)

      assert message.flags == [
               ["flag", "a-flag b-flag", "c-flag"],
               ["flag", "d-flag", "e-flag"]
             ]

      assert message.comments == [" comment"]
    end

    test "headers are parsed when present" do
      assert {:ok, %Messages{messages: [], headers: headers}} =
               PO.parse_string(~S"""
               msgid ""
               msgstr "Language: en_US\n"
                      "Last-Translator: Jane Doe <jane@doe.com>\n"
               """)

      assert ["Language: en_US\n", "Last-Translator: Jane Doe <jane@doe.com>\n"] = headers
    end

    test "duplicated messages cause an error" do
      assert {:error,
              %DuplicateMessagesError{
                duplicates: [
                  {"found duplicate on line 4 for msgid: 'foo'", 4, 1},
                  {"found duplicate on line 7 for msgid: 'foo'", 7, 1}
                ]
              }} =
               PO.parse_string("""
               msgid "foo"
               msgstr "bar"

               msgid "foo"
               msgstr "baz"

               msgid "foo"
               msgstr "bong"
               """)

      # Works if the msgid is split differently as well
      assert {:error,
              %DuplicateMessagesError{
                duplicates: [{"found duplicate on line 4 for msgid: 'foo'", 4, 1}]
              }} =
               PO.parse_string("""
               msgid "foo" ""
               msgstr "bar"

               msgid "" "foo"
               msgstr "baz"
               """)
    end

    test "duplicated plural messages cause an error" do
      assert {:error,
              %DuplicateMessagesError{
                duplicates: [
                  {"found duplicate on line 5 for msgid: 'foo' and msgid_plural: 'foos'", 5, 1}
                ]
              }} =
               PO.parse_string("""
               msgid "foo"
               msgid_plural "foos"
               msgstr[0] "bar"

               msgid "foo"
               msgid_plural "foos"
               msgstr[0] "baz"
               """)
    end

    test "an empty list of tokens is parsed as an empty list of messages" do
      assert {:ok, %Messages{messages: [], headers: []}} = PO.parse_string("")
    end

    test "multiple references on the same line are parsed correctly" do
      assert {:ok, %Messages{messages: [%Message.Singular{} = message]}} =
               PO.parse_string("""
               #: foo.ex:1 bar.ex:2 with spaces.ex:3
               #: baz.ex:3 with:colon.ex:12
               msgid "foo"
               msgstr "bar"
               """)

      assert message.references == [
               [{"foo.ex", 1}, {"bar.ex", 2}, {"with spaces.ex", 3}],
               [{"baz.ex", 3}, {"with:colon.ex", 12}]
             ]
    end

    test "top-of-the-file comments are extracted correctly" do
      assert {:ok, %Messages{messages: [], top_comments: top_comments}} =
               PO.parse_string("""
               # Top of the file
               ## Top of the file with two hashes
               msgid ""
               msgstr "Language: en_US\\r\\n"
               """)

      assert [" Top of the file", "# Top of the file with two hashes"] = top_comments
    end

    test "msgctxt is parsed correctly for messages" do
      assert {:ok, %Messages{messages: [%Message.Singular{} = message]}} =
               PO.parse_string("""
               msgctxt "my_" "context"
               msgid "my_msgid"
               msgstr "my_msgstr"
               """)

      assert message.msgctxt == ["my_", "context"]
      assert message.msgid == ["my_msgid"]
      assert message.msgstr == ["my_msgstr"]
    end

    test "msgctxt is parsed correctly for plural messages" do
      assert {:ok, %Messages{messages: [%Message.Plural{} = message]}} =
               PO.parse_string("""
               msgctxt "my_" "context"
               msgid "my_msgid"
               msgid_plural "my_msgid_plural"
               msgstr[0] "my_msgstr"
               """)

      assert message.msgctxt == ["my_", "context"]
      assert message.msgid == ["my_msgid"]
      assert message.msgid_plural == ["my_msgid_plural"]
      assert message.msgstr[0] == ["my_msgstr"]
    end

    test "msgctxt is nil when no msgctxt is present in a message" do
      assert {:ok, %Messages{messages: [%Message.Singular{} = message]}} =
               PO.parse_string("""
               msgid "my_msgid"
               msgstr "my_msgstr"
               """)

      assert message.msgctxt == nil
    end

    test "msgctxt causes a syntax error when misplaced" do
      # Badly placed msgctxt still causes a syntax error
      assert {:error, %SyntaxError{reason: "syntax error before: msgctxt", line: 2}} =
               PO.parse_string("""
               msgid "my_msgid"
               msgctxt "my_context"
               msgstr "my_msgstr"
               """)
    end

    test "msgctxt should not cause duplication messages" do
      assert {:ok,
              %Messages{
                messages: [
                  %Message.Singular{} = message1,
                  %Message.Singular{} = message2
                ]
              }} =
               PO.parse_string("""
               msgctxt "my_" "context"
               msgid "my_msgid"
               msgstr "my_msgstr"
               msgid "my_msgid"
               msgstr "my_msgstr"
               """)

      assert message1.msgctxt == ["my_", "context"]
      assert message1.msgid == ["my_msgid"]
      assert message1.msgstr == ["my_msgstr"]

      assert message2.msgctxt == nil
      assert message2.msgid == ["my_msgid"]
      assert message2.msgstr == ["my_msgstr"]
    end

    test "msgctxt should not cause duplication for plural messages" do
      assert {:ok,
              %Messages{
                messages: [
                  %Message.Plural{} = message1,
                  %Message.Plural{} = message2
                ]
              }} =
               PO.parse_string("""
               msgctxt "my_" "context"
               msgid "my_msgid"
               msgid_plural "my_msgid_plural"
               msgstr[0] "my_msgstr"
               msgid "my_msgid"
               msgid_plural "my_msgid_plural"
               msgstr[0] "my_msgstr"
               """)

      assert message1.msgctxt == ["my_", "context"]
      assert message1.msgid == ["my_msgid"]
      assert message1.msgid_plural == ["my_msgid_plural"]
      assert message1.msgstr[0] == ["my_msgstr"]

      assert message2.msgctxt == nil
      assert message2.msgid == ["my_msgid"]
      assert message2.msgid_plural == ["my_msgid_plural"]
      assert message2.msgstr[0] == ["my_msgstr"]
    end

    test "populates the :file field with the path of the parsed file if option is provided" do
      fixture_path = "test/fixtures/po/valid.po"

      assert {:ok, %Messages{file: ^fixture_path}} =
               PO.parse_string(File.read!(fixture_path), file: fixture_path)
    end

    test "tokens are printed as Elixir terms, not Erlang terms" do
      parsed =
        PO.parse_string("""
        msgid ""
        # comment
        """)

      assert {:error, %SyntaxError{reason: reason, line: 2}} = parsed
      assert reason == "syntax error before: \"# comment\""
    end
  end

  describe "parse_string!/1" do
    test "populates the :file field with the path of the parsed file if option is provided" do
      fixture_path = "test/fixtures/po/valid.po"

      assert %Messages{file: ^fixture_path} =
               PO.parse_string!(File.read!(fixture_path), file: fixture_path)
    end

    test "valid strings" do
      str = """
      msgid "foo"
      msgstr "bar"
      """

      assert %Messages{
               messages: [%Message.Singular{msgid: ["foo"], msgstr: ["bar"]}],
               headers: []
             } = PO.parse_string!(str)
    end

    test "invalid strings" do
      str = "msg"

      assert_raise SyntaxError, "1: unknown keyword 'msg'", fn ->
        PO.parse_string!(str)
      end

      str = """

      msgid
      msgstr "bar"
      """

      assert_raise SyntaxError, "2: syntax error before: msgstr", fn ->
        PO.parse_string!(str)
      end

      assert_raise SyntaxError, "file:2: syntax error before: msgstr", fn ->
        PO.parse_string!(str, file: "file")
      end
    end

    test "file with duplicate messages" do
      fixture_path = "test/fixtures/po/duplicate_messages.po"

      msg = "file:4: found duplicate on line 4 for msgid: 'test'"

      assert_raise DuplicateMessagesError, msg, fn ->
        PO.parse_string!(File.read!(fixture_path), file: "file")
      end
    end
  end

  test "parse_string(!)/1: headers" do
    str = ~S"""
    msgid ""
    msgstr ""
      "Project-Id-Version: xxx\n"
      "Report-Msgid-Bugs-To: \n"
      "POT-Creation-Date: 2010-07-06 12:31-0500\n"
    msgid "foo"
    msgstr "bar"
    """

    assert {:ok,
            %Messages{
              messages: [%Message.Singular{msgid: ["foo"], msgstr: ["bar"]}],
              headers: [
                "",
                "Project-Id-Version: xxx\n",
                "Report-Msgid-Bugs-To: \n",
                "POT-Creation-Date: 2010-07-06 12:31-0500\n"
              ]
            }} = PO.parse_string(str)
  end

  describe "parse_file/1" do
    test "populates the :file field with the path of the parsed file" do
      fixture_path = "test/fixtures/po/valid.po"
      assert {:ok, %Messages{file: ^fixture_path}} = PO.parse_file(fixture_path)
    end

    test "valid file contents" do
      fixture_path = "test/fixtures/po/valid.po"

      assert {:ok,
              %Messages{
                headers: [],
                messages: [
                  %Message.Singular{msgid: ["hello"], msgstr: ["ciao"]},
                  %Message.Singular{
                    msgid: ["how are you,", " friend?"],
                    msgstr: ["come stai,", " amico?"]
                  }
                ]
              }} = PO.parse_file(fixture_path)
    end

    test "invalid file contents" do
      fixture_path = "test/fixtures/po/invalid_syntax_error.po"

      assert PO.parse_file(fixture_path) ==
               {:error,
                %SyntaxError{reason: "syntax error before: msgstr", line: 4, file: fixture_path}}

      fixture_path = "test/fixtures/po/invalid_token_error.po"

      assert PO.parse_file(fixture_path) ==
               {:error,
                %SyntaxError{reason: "unknown keyword 'msg'", line: 3, file: fixture_path}}
    end

    test "missing file" do
      assert PO.parse_file("nonexistent") == {:error, :enoent}
    end

    test "file starting with a BOM byte sequence" do
      fixture_path = "test/fixtures/po/bom.po"

      output =
        capture_io(:stderr, fn ->
          assert {:ok, po} = PO.parse_file(fixture_path)
          assert [%Message.Singular{msgid: ["foo"], msgstr: ["bar"]}] = po.messages
        end)

      assert output =~ "#{fixture_path}: warning: the file being parsed starts with a BOM"
      refute output =~ "nofile: warning: the string being parsed"
    end
  end

  describe "parse_file!/1" do
    test "populates the :file field with the path of the parsed file" do
      fixture_path = "test/fixtures/po/valid.po"
      assert %Messages{file: ^fixture_path} = PO.parse_file!(fixture_path)
    end

    test "valid file contents" do
      fixture_path = "test/fixtures/po/valid.po"

      assert %Messages{
               headers: [],
               messages: [
                 %Message.Singular{msgid: ["hello"], msgstr: ["ciao"]},
                 %Message.Singular{
                   msgid: ["how are you,", " friend?"],
                   msgstr: ["come stai,", " amico?"]
                 }
               ]
             } = PO.parse_file!(fixture_path)
    end

    test "invalid file contents" do
      fixture_path = "test/fixtures/po/invalid_syntax_error.po"

      assert_raise SyntaxError, "#{fixture_path}:4: syntax error before: msgstr", fn ->
        PO.parse_file!(fixture_path)
      end

      fixture_path = "test/fixtures/po/invalid_token_error.po"

      assert_raise SyntaxError, "#{fixture_path}:3: unknown keyword 'msg'", fn ->
        PO.parse_file!(fixture_path)
      end
    end

    test "missing file" do
      # We're using a regex because we want optional double quotes around the file
      # path: the error message (for File.read!/1) in Elixir v1.2 doesn't have
      # them, but it does in v1.3.
      msg = ~r/could not parse "?nonexistent"?: no such file or directory/

      assert_raise File.Error, msg, fn ->
        PO.parse_file!("nonexistent")
      end
    end

    test "empty files don't cause parsing errors" do
      fixture_path = "test/fixtures/po/empty.po"
      assert %Messages{messages: [], headers: []} = PO.parse_file!(fixture_path)
    end

    test "file with duplicate messages" do
      fixture_path = "test/fixtures/po/duplicate_messages.po"
      message = "#{fixture_path}:4: found duplicate on line 4 for msgid: 'test'"

      assert_raise DuplicateMessagesError, message, fn ->
        PO.parse_file!(fixture_path)
      end
    end
  end
end
