defmodule Expo.MessagesTest do
  use ExUnit.Case, async: true

  alias Expo.Message
  alias Expo.Messages

  doctest Messages

  describe "rebalance/1" do
    test "rebalances headers" do
      assert %Messages{headers: ["", "hello\n", "world"]} =
               Messages.rebalance(%Messages{
                 headers: ["hello\n", "world"],
                 messages: []
               })

      assert %Messages{headers: []} =
               Messages.rebalance(%Messages{
                 headers: [],
                 messages: []
               })
    end

    test "rebalances messages" do
      assert %Messages{messages: [%Message.Singular{msgid: ["hello\n", "world"]}]} =
               Messages.rebalance(%Messages{
                 headers: [],
                 messages: [
                   %Message.Singular{msgid: ["", "hello", "\n", "", "world", ""]}
                 ]
               })
    end
  end

  describe "get_header/2" do
    test "gets single line header case insensitive" do
      assert Messages.get_header(
               %Messages{headers: ["Language: en_US\n"], messages: []},
               "language"
             ) == ["en_US"]
    end

    test "gets multi line header case insensitive" do
      assert Messages.get_header(
               %Messages{
                 headers: [
                   ~S"""
                   Plural-Forms: nplurals=6; \
                     plural=n==0 ? 0 : n==1 ? 1 : n==2 ? 2 : n%100>=3 && n%100<=10 ? 3 \
                     : n%100>=11 ? 4 : 5;
                   """
                 ],
                 messages: []
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
      assert Messages.get_header(%Messages{headers: [], messages: []}, "language") ==
               []
    end

    test "gets multiple headers iwth same name" do
      assert Messages.get_header(
               %Messages{
                 headers: [
                   """
                   Translator: José
                   Translator: Jonatan
                   """
                 ],
                 messages: []
               },
               "translator"
             ) == ["José", "Jonatan"]
    end
  end

  describe "find/2" do
    test "works with Messages struct" do
      messages = %Messages{
        messages: [
          %Message.Singular{msgid: ["foo"], msgstr: ["foo"]},
          %Message.Singular{msgid: ["bar"], msgstr: ["bar"]}
        ]
      }

      assert %Message.Singular{msgstr: ["foo"]} =
               Messages.find(messages, %Message.Singular{msgid: ["foo"]})

      assert nil ==
               Messages.find(messages, %Message.Singular{msgid: ["baz"]})
    end

    test "works with list" do
      messages = [
        %Message.Singular{msgid: ["foo"], msgstr: ["foo"]},
        %Message.Singular{msgid: ["bar"], msgstr: ["bar"]}
      ]

      assert %Message.Singular{msgstr: ["foo"]} =
               Messages.find(messages, %Message.Singular{msgid: ["foo"]})

      assert nil ==
               Messages.find(messages, %Message.Singular{msgid: ["baz"]})
    end
  end
end
