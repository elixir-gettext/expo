defmodule Expo.PoTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Expo.Po
  alias Expo.Po.DuplicateTranslationsError
  alias Expo.Po.SyntaxError
  alias Expo.Translation
  alias Expo.Translations

  doctest Po

  describe "compose/2" do
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

  describe "parse_string/1" do
    test "with single strings" do
      assert {:ok,
              %Translations{
                translations: [%Translation.Singular{msgid: ["hello"], msgstr: ["ciao"]}]
              }} =
               Po.parse_string("""
               msgid "hello"
               msgstr "ciao"
               """)
    end

    test "with previous msgid" do
      assert {:ok,
              %Translations{
                translations: [
                  %Translation.Singular{
                    msgid: ["hello"],
                    msgstr: ["ciao"],
                    previous_msgids: [["holla"]]
                  }
                ]
              }} =
               Po.parse_string("""
               #| msgid "holla"
               msgid "hello"
               msgstr "ciao"
               """)
    end

    test "with obsolete translation" do
      assert {:ok,
              %Translations{
                translations: [
                  %Translation.Singular{
                    msgid: ["hello"],
                    msgstr: ["ciao"],
                    comments: ["comment"]
                  }
                ]
              }} =
               Po.parse_string("""
               # comment
               #~ msgid "hello"
               #~ msgstr "ciao"
               """)
    end

    test "with multiple concatenated strings" do
      assert {:ok,
              %Translations{
                translations: [
                  %Translation.Singular{msgid: ["hello", " world"], msgstr: ["ciao", " mondo"]}
                ]
              }} =
               Po.parse_string("""
               msgid "hello" " world"
               msgstr "ciao" " mondo"
               """)
    end

    test "with multiple translations" do
      assert {:ok,
              %Translations{
                translations: [
                  %Translation.Singular{msgid: ["hello"], msgstr: ["ciao"]},
                  %Translation.Singular{msgid: ["word"], msgstr: ["parola"]}
                ]
              }} =
               Po.parse_string("""
               msgid "hello"
               msgstr "ciao"
               msgid "word"
               msgstr "parola"
               """)
    end

    test "with unicode characters in the strings" do
      assert {:ok,
              %Translations{
                translations: [%Translation.Singular{msgid: ["føø"], msgstr: ["bårπ"]}]
              }} =
               Po.parse_string("""
               msgid "føø"
               msgstr "bårπ"
               """)
    end

    test "with a pluralized string" do
      assert {:ok,
              %Translations{
                translations: [
                  %Translation.Plural{
                    msgid: ["foo"],
                    msgstr: %{0 => ["bar"], 1 => ["bars"], 2 => ["barres"]}
                  }
                ]
              }} =
               Po.parse_string("""
               msgid "foo"
               msgid_plural "foos"
               msgstr[0] "bar"
               msgstr[1] "bars"
               msgstr[2] "barres"
               """)
    end

    test "comments are associated with translations" do
      assert {:ok,
              %Translations{
                translations: [
                  %Translation.Singular{
                    msgid: ["foo"],
                    msgstr: ["bar"],
                    comments: ["This is a translation", "Ah, another comment!"],
                    extracted_comments: ["An extracted comment"],
                    references: [[{"lib/foo.ex", 32}]]
                  }
                ]
              }} =
               Po.parse_string("""
               # This is a translation
               #: lib/foo.ex:32
               # Ah, another comment!
               #. An extracted comment
               msgid "foo"
               msgstr "bar"
               """)
    end

    test "comments always belong to the next translation" do
      assert {:ok,
              %Translations{
                translations: [
                  %Translation.Singular{msgid: ["a"], msgstr: ["b"]},
                  %Translation.Singular{msgid: ["c"], msgstr: ["d"], comments: ["Comment"]}
                ]
              }} =
               Po.parse_string("""
               msgid "a"
               msgstr "b"
               # Comment
               msgid "c"
               msgstr "d"
               """)
    end

    test "syntax error when there is no 'msgid'" do
      assert {:error,
              {:parse_error,
               "expected msgid followed by strings while processing plural translation inside singular translation or plural translation",
               _context, 1}} = Po.parse_string("msgstr \"foo\"")

      assert {:error,
              {:parse_error,
               "expected msgid followed by strings while processing plural translation inside singular translation or plural translation",
               _context, 1}} = Po.parse_string("msgstr \"foo\"")

      assert {:error,
              {:parse_error,
               "expected msgid followed by strings while processing plural translation inside singular translation or plural translation",
               _context, 1}} = Po.parse_string("\"foo\"")
    end

    test "if there's a msgid_plural, then plural forms must follow" do
      assert {:error,
              {:parse_error,
               "expected plural form (like [0]) while processing plural translation inside singular translation or plural translation",
               _context,
               3}} =
               Po.parse_string("""
               msgid "foo"
               msgid_plural "foos"
               msgstr "bar"
               """)
    end

    test "'msgid_plural' must come after 'msgid'" do
      assert {:error,
              {:parse_error,
               "expected whitespace while processing msgid followed by strings inside plural translation inside singular translation or plural translation",
               _context, 1}} = Po.parse_string("msgid_plural ")
    end

    test "comments can't be placed between 'msgid' and 'msgstr'" do
      assert {:error,
              {:parse_error,
               "expected msgid_plural followed by strings while processing plural translation inside singular translation or plural translation",
               _context,
               2}} =
               Po.parse_string("""
               msgid "foo"
               # Comment
               msgstr "bar"
               """)

      assert {:error,
              {:parse_error,
               "expected plural translation while processing singular translation or plural translation",
               _context,
               3}} =
               Po.parse_string("""
               msgid "foo"
               msgid_plural "foo"
               # Comment
               msgstr[0] "bar"
               """)
    end

    # TODO: Should work
    # test "files with just comments are ok (the comments are discarded)" do
    #   assert {:ok, _translations} =
    #            Po.parse_string("""
    #            # A comment
    #            # Another comment
    #            """)
    # end

    test "reference are extracted into the :reference field of a translation" do
      assert {:ok, %Translations{translations: [%Translation.Singular{} = translation]}} =
               Po.parse_string("""
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

      assert translation.references == [
               [{"foo.ex", 1}],
               [{"f", 2}],
               [{"filename with spaces.ex", 12}],
               [{"another/ref/comment.ex", 83}],
               ["reference_without_line"]
             ]

      # All the reference comments are removed.
      assert translation.comments == [
               "Not a reference comment",
               ": Not a reference comment either"
             ]
    end

    test "extracted comments are extracted into the :extracted_comments field of a translation" do
      assert {:ok, %Translations{translations: [%Translation.Singular{} = translation]}} =
               Po.parse_string("""
               #. Extracted comment
               # Not an extracted comment
               #.Another extracted comment
               msgid "foo"
               msgstr "bar"
               """)

      assert translation.extracted_comments == [
               "Extracted comment",
               "Another extracted comment"
             ]

      # All the reference comments are removed.
      assert translation.comments == [
               "Not an extracted comment"
             ]
    end

    test "flags are extracted in to the :flags field of a translation" do
      assert {:ok, %Translations{translations: [%Translation.Singular{} = translation]}} =
               Po.parse_string("""
               #, flag,a-flag b-flag, c-flag
               # comment
               #, flag,  ,d-flag ,, e-flag
               msgid "foo"
               msgstr "bar"
               """)

      assert Enum.sort(translation.flags) == [
               ["flag", "a-flag b-flag", "c-flag"],
               ["flag", "d-flag ", "e-flag"]
             ]

      assert translation.comments == ["comment"]
    end

    test "headers are parsed when present" do
      assert {:ok, %Translations{translations: [], headers: headers}} =
               Po.parse_string(~S"""
               msgid ""
               msgstr "Language: en_US\n"
                      "Last-Translator: Jane Doe <jane@doe.com>\n"
               """)

      assert ["Language: en_US\n", "Last-Translator: Jane Doe <jane@doe.com>\n"] = headers
    end

    test "duplicated translations cause a parse error" do
      assert {:error,
              {:duplicate_translations,
               [
                 {"found duplicate on line 4 for msgid: 'foo'", 4, 1},
                 {"found duplicate on line 7 for msgid: 'foo'", 7, 1}
               ]}} =
               Po.parse_string("""
               msgid "foo"
               msgstr "bar"

               msgid "foo"
               msgstr "baz"

               msgid "foo"
               msgstr "bong"
               """)

      # Works if the msgid is split differently as well
      assert {:error,
              {:duplicate_translations, [{"found duplicate on line 4 for msgid: 'foo'", 4, 1}]}} =
               Po.parse_string("""
               msgid "foo" ""
               msgstr "bar"

               msgid "" "foo"
               msgstr "baz"
               """)
    end

    test "duplicated plural translations cause a parse error" do
      assert {:error,
              {:duplicate_translations,
               [{"found duplicate on line 5 for msgid: 'foo' and msgid_plural: 'foos'", 5, 1}]}} =
               Po.parse_string("""
               msgid "foo"
               msgid_plural "foos"
               msgstr[0] "bar"

               msgid "foo"
               msgid_plural "foos"
               msgstr[0] "baz"
               """)
    end

    # TODO: Fix
    # test "an empty list of tokens is parsed as an empty list of translations" do
    #   assert {:ok, %Translations{translations: [], headers: []}} =      Po.parse_string("")
    # end

    test "multiple references on the same line are parsed correctly" do
      assert {:ok, %Translations{translations: [%Translation.Singular{} = translation]}} =
               Po.parse_string("""
               #: foo.ex:1 bar.ex:2 with spaces.ex:3
               #: baz.ex:3 with:colon.ex:12
               msgid "foo"
               msgstr "bar"
               """)

      assert translation.references == [
               [{"foo.ex", 1}, {"bar.ex", 2}, {"with spaces.ex", 3}],
               [{"baz.ex", 3}, {"with:colon.ex", 12}]
             ]
    end

    test "top-of-the-file comments are extracted correctly" do
      assert {:ok, %Translations{translations: [], top_comments: top_comments}} =
               Po.parse_string("""
               # Top of the file
               ## Top of the file with two hashes
               msgid ""
               msgstr "Language: en_US\\n"
               """)

      assert ["Top of the file", "# Top of the file with two hashes"] = top_comments
    end

    test "msgctxt is parsed correctly for translations" do
      assert {:ok, %Translations{translations: [%Translation.Singular{} = translation]}} =
               Po.parse_string("""
               msgctxt "my_" "context"
               msgid "my_msgid"
               msgstr "my_msgstr"
               """)

      assert translation.msgctxt == ["my_", "context"]
      assert translation.msgid == ["my_msgid"]
      assert translation.msgstr == ["my_msgstr"]
    end

    test "msgctxt is parsed correctly for plural translations" do
      assert {:ok, %Translations{translations: [%Translation.Plural{} = translation]}} =
               Po.parse_string("""
               msgctxt "my_" "context"
               msgid "my_msgid"
               msgid_plural "my_msgid_plural"
               msgstr[0] "my_msgstr"
               """)

      assert translation.msgctxt == ["my_", "context"]
      assert translation.msgid == ["my_msgid"]
      assert translation.msgid_plural == ["my_msgid_plural"]
      assert translation.msgstr[0] == ["my_msgstr"]
    end

    test "msgctxt is nil when no msgctxt is present in a translation" do
      assert {:ok, %Translations{translations: [%Translation.Singular{} = translation]}} =
               Po.parse_string("""
               msgid "my_msgid"
               msgstr "my_msgstr"
               """)

      assert translation.msgctxt == nil
    end

    test "msgctxt causes a syntax error when misplaced" do
      # Badly placed msgctxt still causes a syntax error
      assert {:error,
              {:parse_error,
               "expected msgid_plural followed by strings while processing plural translation inside singular translation or plural translation",
               _context,
               2}} =
               Po.parse_string("""
               msgid "my_msgid"
               msgctxt "my_context"
               msgstr "my_msgstr"
               """)
    end

    test "msgctxt should not cause duplication translations" do
      assert {:ok,
              %Translations{
                translations: [
                  %Translation.Singular{} = translation1,
                  %Translation.Singular{} = translation2
                ]
              }} =
               Po.parse_string("""
               msgctxt "my_" "context"
               msgid "my_msgid"
               msgstr "my_msgstr"
               msgid "my_msgid"
               msgstr "my_msgstr"
               """)

      assert translation1.msgctxt == ["my_", "context"]
      assert translation1.msgid == ["my_msgid"]
      assert translation1.msgstr == ["my_msgstr"]

      assert translation2.msgctxt == nil
      assert translation2.msgid == ["my_msgid"]
      assert translation2.msgstr == ["my_msgstr"]
    end

    test "msgctxt should not cause duplication for plural translations" do
      assert {:ok,
              %Translations{
                translations: [
                  %Translation.Plural{} = translation1,
                  %Translation.Plural{} = translation2
                ]
              }} =
               Po.parse_string("""
               msgctxt "my_" "context"
               msgid "my_msgid"
               msgid_plural "my_msgid_plural"
               msgstr[0] "my_msgstr"
               msgid "my_msgid"
               msgid_plural "my_msgid_plural"
               msgstr[0] "my_msgstr"
               """)

      assert translation1.msgctxt == ["my_", "context"]
      assert translation1.msgid == ["my_msgid"]
      assert translation1.msgid_plural == ["my_msgid_plural"]
      assert translation1.msgstr[0] == ["my_msgstr"]

      assert translation2.msgctxt == nil
      assert translation2.msgid == ["my_msgid"]
      assert translation2.msgid_plural == ["my_msgid_plural"]
      assert translation2.msgstr[0] == ["my_msgstr"]
    end
  end

  describe "parse_string!/1" do
    test "valid strings" do
      str = """
      msgid "foo"
      msgstr "bar"
      """

      assert %Translations{
               translations: [%Translation.Singular{msgid: ["foo"], msgstr: ["bar"]}],
               headers: []
             } = Po.parse_string!(str)
    end

    test "invalid strings" do
      str = "msg"

      assert_raise SyntaxError,
                   "1: expected msgid followed by strings while processing plural translation inside singular translation or plural translation",
                   fn ->
                     Po.parse_string!(str)
                   end

      str = """

      msgid
      msgstr "bar"
      """

      assert_raise SyntaxError,
                   "2: expected whitespace while processing msgid followed by strings inside plural translation inside singular translation or plural translation",
                   fn ->
                     Po.parse_string!(str)
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
            %Translations{
              translations: [%Translation.Singular{msgid: ["foo"], msgstr: ["bar"]}],
              headers: [
                "",
                "Project-Id-Version: xxx\n",
                "Report-Msgid-Bugs-To: \n",
                "POT-Creation-Date: 2010-07-06 12:31-0500\n"
              ]
            }} = Po.parse_string(str)
  end

  describe "parse_file/1" do
    test "valid file contents" do
      fixture_path = Application.app_dir(:expo, "priv/test/po/valid.po")

      assert {:ok,
              %Translations{
                headers: [],
                translations: [
                  %Translation.Singular{msgid: ["hello"], msgstr: ["ciao"]},
                  %Translation.Singular{
                    msgid: ["how are you,", " friend?"],
                    msgstr: ["come stai,", " amico?"]
                  }
                ]
              }} = Po.parse_file(fixture_path)
    end

    test "invalid file contents" do
      fixture_path = Application.app_dir(:expo, "priv/test/po/invalid_syntax_error.po")

      assert Po.parse_file(fixture_path) ==
               {:error, {:parse_error, "expected end of string", "msgstr \"bong\"\n", 4}}

      fixture_path = Application.app_dir(:expo, "priv/test/po/invalid_token_error.po")

      assert Po.parse_file(fixture_path) ==
               {:error,
                {:parse_error,
                 "expected msgid followed by strings while processing plural translation inside singular translation or plural translation",
                 "msg\n", 3}}
    end

    test "missing file" do
      assert Po.parse_file("nonexistent") == {:error, :enoent}
    end

    test "file starting with a BOM byte sequence" do
      fixture_path = Application.app_dir(:expo, "priv/test/po/bom.po")

      output =
        capture_io(:stderr, fn ->
          assert {:ok, po} = Po.parse_file(fixture_path)
          assert [%Translation.Singular{msgid: ["foo"], msgstr: ["bar"]}] = po.translations
        end)

      assert output =~ "#{fixture_path}: warning: the file being parsed starts with a BOM"
      refute output =~ "nofile: warning: the string being parsed"
    end
  end

  describe "parse_file!/1" do
    test "populates the :file field with the path of the parsed file" do
      fixture_path = Application.app_dir(:expo, "priv/test/po/valid.po")
      assert %Translations{file: ^fixture_path} = Po.parse_file!(fixture_path)
    end

    test "valid file contents" do
      fixture_path = Application.app_dir(:expo, "priv/test/po/valid.po")

      assert %Translations{
               headers: [],
               translations: [
                 %Translation.Singular{msgid: ["hello"], msgstr: ["ciao"]},
                 %Translation.Singular{
                   msgid: ["how are you,", " friend?"],
                   msgstr: ["come stai,", " amico?"]
                 }
               ]
             } = Po.parse_file!(fixture_path)
    end

    test "invalid file contents" do
      fixture_path = Application.app_dir(:expo, "priv/test/po/invalid_syntax_error.po")

      msg = "_build/test/lib/expo/priv/test/po/invalid_syntax_error.po:4: expected end of string"

      assert_raise SyntaxError, msg, fn ->
        Po.parse_file!(fixture_path)
      end

      fixture_path = Application.app_dir(:expo, "priv/test/po/invalid_token_error.po")

      msg =
        "_build/test/lib/expo/priv/test/po/invalid_token_error.po:3: expected msgid followed by strings while processing plural translation inside singular translation or plural translation"

      assert_raise SyntaxError, msg, fn ->
        Po.parse_file!(fixture_path)
      end
    end

    test "missing file" do
      # We're using a regex because we want optional double quotes around the file
      # path: the error message (for File.read!/1) in Elixir v1.2 doesn't have
      # them, but it does in v1.3.
      msg = ~r/could not parse "?nonexistent"?: no such file or directory/

      assert_raise File.Error, msg, fn ->
        Po.parse_file!("nonexistent")
      end
    end

    test "file with duplicate translations" do
      fixture_path = Application.app_dir(:expo, "priv/test/po/duplicate_translations.po")

      msg =
        "_build/test/lib/expo/priv/test/po/duplicate_translations.po:4: found duplicate on line 4 for msgid: 'test'"

      assert_raise DuplicateTranslationsError, msg, fn ->
        Po.parse_file!(fixture_path)
      end
    end
  end
end
