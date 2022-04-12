defmodule Expo.PluralFormsTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Expo.PluralForms

  doctest PluralForms

  describe "parse/1" do
    test "Only one form" do
      assert {:ok, {1, 0}} = PluralForms.parse_string("nplurals=1; plural=0;")
    end

    test "Two forms, singular used for one only" do
      assert {:ok, {2, {:!=, :n, 1}}} = PluralForms.parse_string("nplurals=2; plural=n != 1;")
    end

    test "Two forms, singular used for zero and one" do
      assert {:ok, {2, {:>, :n, 1}}} = PluralForms.parse_string("nplurals=2; plural=n>1;")
    end

    test "Three forms, special case for zero" do
      assert {:ok,
              {3,
               {
                 :if,
                 {
                   :&&,
                   {
                     :==,
                     {:%, :n, 10},
                     1
                   },
                   {
                     :!=,
                     {:%, :n, 100},
                     11
                   }
                 },
                 0,
                 {
                   :if,
                   {:!=, :n, 0},
                   1,
                   2
                 }
               }}} =
               PluralForms.parse_string(
                 "nplurals=3; plural=n%10==1 && n%100!=11 ? 0 : n != 0 ? 1 : 2;"
               )
    end

    test "Three forms, special case for numbers ending in 00 or [2-9][0-9]" do
      assert {:ok,
              {3,
               {
                 :if,
                 {:==, :n, 1},
                 0,
                 {
                   :if,
                   {:paren,
                    {
                      :||,
                      {:==, :n, 0},
                      {:paren,
                       {
                         :&&,
                         {:>, {:%, :n, 100}, 0},
                         {:<, {:%, :n, 100}, 20}
                       }}
                    }},
                   1,
                   2
                 }
               }}} =
               PluralForms.parse_string("""
               nplurals=3; \
                    plural=n==1 ? 0 : (n==0 || (n%100 > 0 && n%100 < 20)) ? 1 : 2;
               """)
    end

    test "Three forms, special case for numbers ending in 1[2-9]" do
      assert {:ok,
              {3,
               {
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
               }}} =
               PluralForms.parse_string("""
               nplurals=3; \
                  plural=n%10==1 && n%100!=11 ? 0 : \
                        n%10>=2 && (n%100<10 || n%100>=20) ? 1 : 2;
               """)
    end

    test "Three forms, special cases for numbers ending in 1 and 2, 3, 4, except those ending in 1[1-4]" do
      assert {:ok,
              {3,
               {
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
               }}} =
               PluralForms.parse_string("""
               nplurals=3; \
                     plural=n%10==1 && n%100!=11 ? 0 : \
                         n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2;
               """)
    end

    test "Three forms, special cases for 1 and 2, 3, 4" do
      assert {:ok,
              {3,
               {
                 :if,
                 {:paren, {:==, :n, 1}},
                 0,
                 {
                   :if,
                   {:paren,
                    {
                      :&&,
                      {:>=, :n, 2},
                      {:<=, :n, 4}
                    }},
                   1,
                   2
                 }
               }}} =
               PluralForms.parse_string("""
               nplurals=3; \
                     plural=(n==1) ? 0 : (n>=2 && n<=4) ? 1 : 2;
               """)
    end

    test "Three forms, special case for one and some numbers ending in 2, 3, or 4" do
      assert {:ok,
              {3,
               {
                 :if,
                 {:==, :n, 1},
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
               }}} =
               PluralForms.parse_string("""
               nplurals=3; \
                     plural=n==1 ? 0 : \
                           n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2;
               """)
    end

    test "Four forms, special case for one and all numbers ending in 02, 03, or 04" do
      assert {:ok,
              {4,
               {
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
               }}} =
               PluralForms.parse_string("""
               nplurals=4; \
                     plural=n%100==1 ? 0 : n%100==2 ? 1 : n%100==3 || n%100==4 ? 2 : 3;
               """)
    end

    test "Six forms, special cases for one, two, all numbers ending in 02, 03, … 10, all numbers ending in 11 … 99, and others" do
      assert {:ok,
              {6,
               {
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
                       {
                         :&&,
                         {:>=, {:%, :n, 100}, 3},
                         {:<=, {:%, :n, 100}, 10}
                       },
                       3,
                       {
                         :if,
                         {:>=, {:%, :n, 100}, 11},
                         4,
                         5
                       }
                     }
                   }
                 }
               }}} =
               PluralForms.parse_string("""
               nplurals=6; \
                     plural=n==0 ? 0 : n==1 ? 1 : n==2 ? 2 : n%100>=3 && n%100<=10 ? 3 \
                     : n%100>=11 ? 4 : 5;
               """)
    end

    test "invalid expression" do
      assert {:error, {:parse_error, _message, 1, 19}} =
               PluralForms.parse_string("nplurals=6; plural=m % 20 == 1;")
    end
  end

  describe "index/2" do
    # Tests copied from https://github.com/elixir-gettext/gettext/blob/600e4630fb7db514d464f92e2069a138cf9c68a1/test/gettext/plural_test.exs#L1

    test "identity" do
      assert 2 = PluralForms.index(:n, 2)
      assert 7 = PluralForms.index(7, 2)
    end

    test "operators" do
      assert 0 = PluralForms.index({:%, 10, 2}, 2)
      assert 1 = PluralForms.index({:%, 10, 3}, 2)

      assert 0 = PluralForms.index({:>, 1, 2}, 2)
      assert 1 = PluralForms.index({:>, 2, 1}, 2)
      assert 0 = PluralForms.index({:>, 1, 1}, 2)

      assert 0 = PluralForms.index({:>=, 1, 2}, 2)
      assert 1 = PluralForms.index({:>=, 2, 1}, 2)
      assert 1 = PluralForms.index({:>=, 1, 1}, 2)

      assert 1 = PluralForms.index({:<, 1, 2}, 2)
      assert 0 = PluralForms.index({:<, 2, 1}, 2)
      assert 0 = PluralForms.index({:<, 1, 1}, 2)

      assert 1 = PluralForms.index({:<=, 1, 2}, 2)
      assert 0 = PluralForms.index({:<=, 2, 1}, 2)
      assert 1 = PluralForms.index({:<=, 1, 1}, 2)

      assert 1 = PluralForms.index({:!=, 1, 2}, 2)
      assert 0 = PluralForms.index({:!=, 1, 1}, 2)

      assert 0 = PluralForms.index({:==, 1, 2}, 2)
      assert 1 = PluralForms.index({:==, 1, 1}, 2)

      assert 1 = PluralForms.index({:&&, 1, 1}, 2)
      assert 0 = PluralForms.index({:&&, 0, 1}, 2)
      assert 0 = PluralForms.index({:&&, 1, 0}, 2)
      assert 0 = PluralForms.index({:&&, 0, 0}, 2)

      assert 1 = PluralForms.index({:||, 1, 1}, 2)
      assert 1 = PluralForms.index({:||, 0, 1}, 2)
      assert 1 = PluralForms.index({:||, 1, 0}, 2)
      assert 0 = PluralForms.index({:||, 0, 0}, 2)
    end

    test "conditional" do
      condition = {:if, {:>, :n, 1}, 7, 0}

      assert 7 = PluralForms.index(condition, 3)
      assert 0 = PluralForms.index(condition, 0)
    end
  end

  test "arabic" do
    assert {:ok, {6, plurals}} =
             PluralForms.parse_string("""
             nplurals=6; \
                   plural=n==0 ? 0 : n==1 ? 1 : n==2 ? 2 : n%100>=3 && n%100<=10 ? 3 \
                   : n%100>=11 ? 4 : 5;
             """)

    assert PluralForms.index(plurals, 0) == 0
    assert PluralForms.index(plurals, 1) == 1
    assert PluralForms.index(plurals, 2) == 2
    assert PluralForms.index(plurals, 2009) == 3
    assert PluralForms.index(plurals, 2011) == 4
    assert PluralForms.index(plurals, 2099) == 4
    assert PluralForms.index(plurals, 3000) == 5
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
      assert :error = PluralForms.plural_form("wat")

      # This happens with dash as the territory/locale separator
      # (https://en.wikipedia.org/wiki/IETF_language_tag).
      assert :error = PluralForms.plural_form("en-us")
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
    {:ok, {_nplurals, plural_form}} = PluralForms.plural_form(code)
    PluralForms.index(plural_form, n)
  end

  defp nplurals(code) do
    {:ok, {nplurals, _plural_form}} = PluralForms.plural_form(code)
    nplurals
  end

  describe "compose/1" do
    test "converts plural form back to string" do
      {:ok, plural_forms} =
        PluralForms.parse_string(
          "nplurals=6; plural=(n==0 ? 0 : n==1 ? 1 : n==2 ? 2 : n%100>=3 && n%100<=10 ? 3 : n%100>=11 ? 4 : 5);"
        )

      assert "nplurals=6; plural=(n==0 ? 0 : n==1 ? 1 : n==2 ? 2 : n%100>=3 && n%100<=10 ? 3 : n%100>=11 ? 4 : 5);" =
               plural_forms |> PluralForms.compose() |> IO.iodata_to_binary()
    end

    for locale <- PluralForms.known_locales() do
      {:ok, plural_form} = PluralForms.plural_form(locale)

      test "repeated parse / compose yields same result for #{locale}" do
        assert {:ok, unquote(Macro.escape(plural_form))} ==
                 unquote(Macro.escape(plural_form))
                 |> PluralForms.compose()
                 |> IO.iodata_to_binary()
                 |> PluralForms.parse_string()
      end
    end
  end

  describe "compile_index/1" do
    test "simple" do
      assert {:ok, {2, plurals}} = PluralForms.parse_string("nplurals=2; plural=n>1;")

      quoted = PluralForms.compile_index(plurals)

      assert {1, _bindings} = Code.eval_quoted(quoted, n: 7)
      assert {0, _bindings} = Code.eval_quoted(quoted, n: 0)
    end

    test "one form does not error" do
      assert {:ok, {2, plurals}} = PluralForms.parse_string("nplurals=2; plural=0;")

      quoted = PluralForms.compile_index(plurals)

      assert {0, _bindings} = Code.eval_quoted(quoted, n: 7)
    end

    test "arabic" do
      assert {:ok, {6, plurals}} =
               PluralForms.parse_string("""
               nplurals=6; \
                     plural=(n==0 ? 0 : n==1 ? 1 : n==2 ? 2 : n%100>=3 && n%100<=10 ? 3 \
                     : n%100>=11 ? 4 : 5);
               """)

      quoted = PluralForms.compile_index(plurals)

      assert {5, _bindings} = Code.eval_quoted(quoted, n: 3000)
    end

    test "compiled" do
      assert index_simple(2) == 1
    end
  end

  describe "known_locales/0" do
    assert "en" in Expo.PluralForms.known_locales()
  end

  {:ok, {2, plurals}} = PluralForms.parse_string("nplurals=2; plural=n>1;")
  defp index_simple(n), do: unquote(PluralForms.compile_index(plurals))
end
