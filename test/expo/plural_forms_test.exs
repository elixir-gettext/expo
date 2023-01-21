defmodule Expo.PluralFormsTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Expo.PluralForms.SyntaxError

  doctest Expo.PluralForms

  describe "parse/1" do
    test "with plural as simple integer" do
      assert Expo.PluralForms.parse("nplurals=1; plural=0;") ==
               {:ok, %Expo.PluralForms{nplurals: 1, plural: 0}}

      assert Expo.PluralForms.parse("nplurals=1; plural=3;") ==
               {:ok, %Expo.PluralForms{nplurals: 1, plural: 3}}
    end

    test "with plural as a single boolean expression" do
      assert Expo.PluralForms.parse("nplurals=2; plural=n != 1;") ==
               {:ok, %Expo.PluralForms{nplurals: 2, plural: {:!=, :n, 1}}}
    end

    test "Two forms, singular used for zero and one" do
      assert Expo.PluralForms.parse("nplurals=2; plural=n>1;") ==
               {:ok, %Expo.PluralForms{nplurals: 2, plural: {:>, :n, 1}}}
    end

    test "with three plural forms and a complex if statement" do
      string = "nplurals=3; plural=n%10==1 && n%100!=11 ? 0 : n != 0 ? 1 : 2;"

      assert {:ok,
              %Expo.PluralForms{
                nplurals: 3,
                plural: {:if, and_expr, 0, {:if, not_equal_expr, 1, 2}}
              }} = Expo.PluralForms.parse(string)

      assert and_expr == {:&&, {:==, {:%, :n, 10}, 1}, {:!=, {:%, :n, 100}, 11}}
      assert not_equal_expr == {:!=, :n, 0}
    end

    test "with special case for numbers ending in 00 or [2-9][0-9]" do
      assert {:ok, %Expo.PluralForms{nplurals: 3, plural: plural}} =
               Expo.PluralForms.parse("""
               nplurals=3; \
                    plural=n==1 ? 0 : (n==0 || (n%100 > 0 && n%100 < 20)) ? 1 : 2;
               """)

      assert {:if, {:==, :n, 1}, 0, else_expr} = plural
      assert {:if, {:paren, or_expr}, 1, 2} = else_expr
      assert {:||, {:==, :n, 0}, and_expr} = or_expr
      assert {:paren, {:&&, {:>, {:%, :n, 100}, 0}, {:<, {:%, :n, 100}, 20}}} = and_expr
    end

    test "with special case for numbers ending in 1[2-9]" do
      assert {:ok, %Expo.PluralForms{nplurals: 3, plural: plural}} =
               Expo.PluralForms.parse("""
               nplurals=3; \
                  plural=n%10==1 && n%100!=11 ? 0 : \
                        n%10>=2 && (n%100<10 || n%100>=20) ? 1 : 2;
               """)

      assert plural == {
               :if,
               {
                 :&&,
                 {:==, {:%, :n, 10}, 1},
                 {:!=, {:%, :n, 100}, 11}
               },
               0,
               {
                 :if,
                 {
                   :&&,
                   {:>=, {:%, :n, 10}, 2},
                   {:paren,
                    {
                      :||,
                      {:<, {:%, :n, 100}, 10},
                      {:>=, {:%, :n, 100}, 20}
                    }}
                 },
                 1,
                 2
               }
             }
    end

    test "with special cases for numbers ending in 1 and 2, 3, 4, except those ending in 1[1-4]" do
      assert {:ok, %Expo.PluralForms{nplurals: 3, plural: plural}} =
               Expo.PluralForms.parse("""
               nplurals=3; \
                     plural=n%10==1 && n%100!=11 ? 0 : \
                         n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2;
               """)

      assert plural == {
               :if,
               {
                 :&&,
                 {:==, {:%, :n, 10}, 1},
                 {:!=, {:%, :n, 100}, 11}
               },
               0,
               {
                 :if,
                 {
                   :&&,
                   {
                     :&&,
                     {:>=, {:%, :n, 10}, 2},
                     {:<=, {:%, :n, 10}, 4}
                   },
                   {:paren,
                    {
                      :||,
                      {:<, {:%, :n, 100}, 10},
                      {:>=, {:%, :n, 100}, 20}
                    }}
                 },
                 1,
                 2
               }
             }
    end

    test "with special case for one and all numbers ending in 02, 03, or 04" do
      assert {:ok, %Expo.PluralForms{nplurals: 4, plural: plural}} =
               Expo.PluralForms.parse("""
               nplurals=4; \
                     plural=n%100==1 ? 0 : n%100==2 ? 1 : n%100==3 || n%100==4 ? 2 : 3;
               """)

      assert plural == {
               :if,
               {:==, {:%, :n, 100}, 1},
               0,
               {
                 :if,
                 {:==, {:%, :n, 100}, 2},
                 1,
                 {
                   :if,
                   {
                     :||,
                     {:==, {:%, :n, 100}, 3},
                     {:==, {:%, :n, 100}, 4}
                   },
                   2,
                   3
                 }
               }
             }
    end

    test "with special cases for one, two, all numbers ending in 02, 03, …10, all numbers ending in 11…99, and others" do
      assert {:ok, %Expo.PluralForms{nplurals: 6, plural: plural}} =
               Expo.PluralForms.parse("""
               nplurals=6; \
                     plural=n==0 ? 0 : n==1 ? 1 : n==2 ? 2 : n%100>=3 && n%100<=10 ? 3 \
                     : n%100>=11 ? 4 : 5;
               """)

      assert plural == {
               :if,
               {:==, :n, 0},
               0,
               {
                 :if,
                 {:==, :n, 1},
                 1,
                 {
                   :if,
                   {:==, :n, 2},
                   2,
                   {
                     :if,
                     {:&&, {:>=, {:%, :n, 100}, 3}, {:<=, {:%, :n, 100}, 10}},
                     3,
                     {:if, {:>=, {:%, :n, 100}, 11}, 4, 5}
                   }
                 }
               }
             }
    end

    test "invalid token" do
      assert Expo.PluralForms.parse("nplurals=6; plural=m % 20 == 1;") ==
               {:error, %SyntaxError{line: 1, column: 20, reason: ~s(unexpected token: "m")}}
    end

    test "syntax error at the beginning" do
      assert Expo.PluralForms.parse("plural=n>1;") ==
               {:error, %SyntaxError{line: 1, column: nil, reason: "syntax error before: plural"}}
    end

    test "syntax error in the middle" do
      assert Expo.PluralForms.parse("nplurals=1;plural=n ?;") ==
               {:error, %SyntaxError{line: 1, column: nil, reason: "syntax error before: '?'"}}
    end

    test "incomplete string" do
      assert Expo.PluralForms.parse("nplurals=1;plural=n ?") ==
               {:error, %SyntaxError{line: 1, column: nil, reason: "syntax error before: '?'"}}
    end

    test "valid but semantically incorrect string" do
      assert Expo.PluralForms.parse("nplurals=1;nplurals=2;plural=n>1;") ==
               {:error,
                %SyntaxError{line: 1, column: nil, reason: "syntax error before: nplurals"}}
    end
  end

  describe "parse!/1" do
    test "valid" do
      assert Expo.PluralForms.parse!("nplurals=1; plural=0;") ==
               %Expo.PluralForms{nplurals: 1, plural: 0}
    end

    test "invalid" do
      assert_raise SyntaxError, ~s(1:20: unexpected token: "m"), fn ->
        Expo.PluralForms.parse!("nplurals=6; plural=m % 20 == 1;")
      end
    end
  end

  describe "index/2" do
    # Tests copied from https://github.com/elixir-gettext/gettext/blob/600e4630fb7db514d464f92e2069a138cf9c68a1/test/gettext/plural_test.exs#L1

    test "identity" do
      assert Expo.PluralForms.index(%Expo.PluralForms{nplurals: 1, plural: :n}, 2) == 2
      assert Expo.PluralForms.index(%Expo.PluralForms{nplurals: 1, plural: 7}, 2) == 7
    end

    test "operators" do
      assert Expo.PluralForms.index(%Expo.PluralForms{nplurals: 2, plural: {:%, 10, 2}}, 2) == 0
      assert Expo.PluralForms.index(%Expo.PluralForms{nplurals: 2, plural: {:%, 10, 3}}, 2) == 1

      assert Expo.PluralForms.index(%Expo.PluralForms{nplurals: 2, plural: {:>, 1, 2}}, 2) == 0
      assert Expo.PluralForms.index(%Expo.PluralForms{nplurals: 2, plural: {:>, 2, 1}}, 2) == 1
      assert Expo.PluralForms.index(%Expo.PluralForms{nplurals: 2, plural: {:>, 1, 1}}, 2) == 0

      assert Expo.PluralForms.index(%Expo.PluralForms{nplurals: 2, plural: {:>=, 1, 2}}, 2) == 0
      assert Expo.PluralForms.index(%Expo.PluralForms{nplurals: 2, plural: {:>=, 2, 1}}, 2) == 1
      assert Expo.PluralForms.index(%Expo.PluralForms{nplurals: 2, plural: {:>=, 1, 1}}, 2) == 1

      assert Expo.PluralForms.index(%Expo.PluralForms{nplurals: 2, plural: {:<, 1, 2}}, 2) == 1
      assert Expo.PluralForms.index(%Expo.PluralForms{nplurals: 2, plural: {:<, 2, 1}}, 2) == 0
      assert Expo.PluralForms.index(%Expo.PluralForms{nplurals: 2, plural: {:<, 1, 1}}, 2) == 0

      assert Expo.PluralForms.index(%Expo.PluralForms{nplurals: 2, plural: {:<=, 1, 2}}, 2) == 1
      assert Expo.PluralForms.index(%Expo.PluralForms{nplurals: 2, plural: {:<=, 2, 1}}, 2) == 0
      assert Expo.PluralForms.index(%Expo.PluralForms{nplurals: 2, plural: {:<=, 1, 1}}, 2) == 1

      assert Expo.PluralForms.index(%Expo.PluralForms{nplurals: 2, plural: {:!=, 1, 2}}, 2) == 1
      assert Expo.PluralForms.index(%Expo.PluralForms{nplurals: 2, plural: {:!=, 1, 1}}, 2) == 0

      assert Expo.PluralForms.index(%Expo.PluralForms{nplurals: 2, plural: {:==, 1, 2}}, 2) == 0
      assert Expo.PluralForms.index(%Expo.PluralForms{nplurals: 2, plural: {:==, 1, 1}}, 2) == 1

      assert Expo.PluralForms.index(%Expo.PluralForms{nplurals: 2, plural: {:&&, 1, 1}}, 2) == 1
      assert Expo.PluralForms.index(%Expo.PluralForms{nplurals: 2, plural: {:&&, 0, 1}}, 2) == 0
      assert Expo.PluralForms.index(%Expo.PluralForms{nplurals: 2, plural: {:&&, 1, 0}}, 2) == 0
      assert Expo.PluralForms.index(%Expo.PluralForms{nplurals: 2, plural: {:&&, 0, 0}}, 2) == 0

      assert Expo.PluralForms.index(%Expo.PluralForms{nplurals: 2, plural: {:||, 1, 1}}, 2) == 1
      assert Expo.PluralForms.index(%Expo.PluralForms{nplurals: 2, plural: {:||, 0, 1}}, 2) == 1
      assert Expo.PluralForms.index(%Expo.PluralForms{nplurals: 2, plural: {:||, 1, 0}}, 2) == 1
      assert Expo.PluralForms.index(%Expo.PluralForms{nplurals: 2, plural: {:||, 0, 0}}, 2) == 0
    end

    test "conditional" do
      plural_form = %Expo.PluralForms{nplurals: 2, plural: {:if, {:>, :n, 1}, 7, 0}}

      assert 7 = Expo.PluralForms.index(plural_form, 3)
      assert 0 = Expo.PluralForms.index(plural_form, 0)
    end

    test "arabic" do
      assert {:ok, plural_forms} =
               Expo.PluralForms.parse("""
               nplurals=6; \
                     plural=n==0 ? 0 : n==1 ? 1 : n==2 ? 2 : n%100>=3 && n%100<=10 ? 3 \
                     : n%100>=11 ? 4 : 5;
               """)

      assert Expo.PluralForms.index(plural_forms, 0) == 0
      assert Expo.PluralForms.index(plural_forms, 1) == 1
      assert Expo.PluralForms.index(plural_forms, 2) == 2
      assert Expo.PluralForms.index(plural_forms, 2009) == 3
      assert Expo.PluralForms.index(plural_forms, 2011) == 4
      assert Expo.PluralForms.index(plural_forms, 2099) == 4
      assert Expo.PluralForms.index(plural_forms, 3000) == 5
    end
  end

  describe "plural_form/1" do
    test "x_* locales are pluralized like x except for exceptions" do
      assert nplurals("en") == nplurals("en_GB")

      assert plural("pt", 0) == 1
      assert plural("pt", 1) == 0
      assert plural("pt_BR", 0) == 0
      assert plural("pt_BR", 1) == 0
    end

    test "locale with a territory" do
      # The _XX in en_XX gets stripped and en_XX is pluralized as en.
      assert nplurals("en_XX") == nplurals("en")
      assert plural("en_XX", 100) == plural("en", 100)
    end

    test "unknown locale" do
      assert :error = Expo.PluralForms.plural_form("wat")

      # This happens with dash as the territory/locale separator
      # (https://en.wikipedia.org/wiki/IETF_language_tag).
      assert :error = Expo.PluralForms.plural_form("en-us")
    end

    test "locales with one form" do
      assert nplurals("ja") == 1
      assert plural("ja", 0) == 0
      assert plural("ja", 8) == 0
    end

    test "locales with two forms where 0 is same as > 1" do
      assert nplurals("it") == 2
      assert plural("it", 1) == 0
      assert plural("it", 0) == 1
      assert plural("it", 13) == 1
    end

    test "locales with two forms where 0 and 1 are the same" do
      assert nplurals("fr") == 2
      assert plural("fr", 0) == 0
      assert plural("fr", 1) == 0
      assert plural("fr", 2) == 1
    end

    test "locales that belong to the 3-forms slavic family" do
      assert nplurals("ru") == 3
      assert plural("ru", 21) == 0
      assert plural("ru", 42) == 1
      assert plural("ru", 11) == 2
    end

    test "locales that belong to the alternative 3-forms slavic family" do
      assert nplurals("cs") == 3
      assert plural("cs", 1) == 0
      assert plural("cs", 3) == 1
      assert plural("cs", 12) == 2
    end

    test "locales that don't belong to any pluralization family" do
      assert plural("ar", 0) == 0
      assert plural("ar", 1) == 1
      assert plural("ar", 2) == 2
      assert plural("ar", 505) == 3
      assert plural("ar", 733) == 4
      assert plural("ar", 101) == 5

      assert plural("csb", 1) == 0
      assert plural("csb", 33) == 1
      assert plural("csb", 115) == 2

      assert plural("cy", 1) == 0
      assert plural("cy", 2) == 1
      assert plural("cy", 23) == 2
      assert plural("cy", 8) == 3

      assert plural("ga", 1) == 0
      assert plural("ga", 2) == 1
      assert plural("ga", 4) == 2
      assert plural("ga", 10) == 3
      assert plural("ga", 133) == 4

      assert plural("gd", 1) == 0
      assert plural("gd", 12) == 1
      assert plural("gd", 18) == 2
      assert plural("gd", 20) == 3

      assert plural("is", 71) == 0
      assert plural("is", 11) == 1

      assert plural("jv", 0) == 0
      assert plural("jv", 13) == 1

      assert plural("kw", 1) == 0
      assert plural("kw", 2) == 1
      assert plural("kw", 3) == 2
      assert plural("kw", 99) == 3

      assert plural("lt", 81) == 0
      assert plural("lt", 872) == 1
      assert plural("lt", 112) == 2

      assert plural("lv", 31) == 0
      assert plural("lv", 9) == 1
      assert plural("lv", 0) == 2

      assert plural("mk", 131) == 0
      assert plural("mk", 132) == 1
      assert plural("mk", 9) == 2

      assert plural("mnk", 0) == 0
      assert plural("mnk", 1) == 1
      assert plural("mnk", 12) == 2

      assert plural("mt", 1) == 0
      assert plural("mt", 0) == 1
      assert plural("mt", 119) == 2
      assert plural("mt", 67) == 3

      assert plural("pl", 1) == 0
      assert plural("pl", 102) == 1
      assert plural("pl", 713) == 2

      assert plural("ro", 1) == 0
      assert plural("ro", 19) == 1
      assert plural("ro", 80) == 2

      assert plural("sl", 320) == 0
      assert plural("sl", 101) == 1
      assert plural("sl", 202) == 2
      assert plural("sl", 303) == 3
    end
  end

  defp plural(code, n) do
    {:ok, plural_form} = Expo.PluralForms.plural_form(code)
    Expo.PluralForms.index(plural_form, n)
  end

  defp nplurals(code) do
    {:ok, plural_form} = Expo.PluralForms.plural_form(code)
    plural_form.nplurals
  end

  describe "to_string/1" do
    test "converts plural form back to string" do
      {:ok, plural_forms} =
        Expo.PluralForms.parse(
          "nplurals=6; plural=(n==0 ? 0 : n==1 ? 1 : n==2 ? 2 : n%100>=3 && n%100<=10 ? 3 : n%100>=11 ? 4 : 5);"
        )

      assert "nplurals=6; plural=(n==0 ? 0 : n==1 ? 1 : n==2 ? 2 : n%100>=3 && n%100<=10 ? 3 : n%100>=11 ? 4 : 5);" =
               plural_forms |> Expo.PluralForms.to_string() |> IO.iodata_to_binary()
    end

    for locale <- Expo.PluralForms.known_locales() do
      assert {:ok, %Expo.PluralForms{} = plural_form} = Expo.PluralForms.plural_form(locale)

      test "repeated parsing and dumping yields same result for #{locale}" do
        assert {:ok, unquote(Macro.escape(plural_form))} ==
                 unquote(Macro.escape(plural_form))
                 |> Expo.PluralForms.to_string()
                 |> Expo.PluralForms.parse()
      end
    end
  end

  describe "known_locales/0" do
    assert "en" in Expo.PluralForms.known_locales()
  end

  describe "Inspect protocol implementation" do
    test "inspect/1" do
      assert inspect(%Expo.PluralForms{nplurals: 2, plural: {:>, :n, 0}}) ==
               ~s{Expo.PluralForms.parse!("nplurals=2; plural=n>0;")}
    end
  end
end
