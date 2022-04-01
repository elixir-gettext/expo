defmodule Expo.PluralFormsTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Expo.PluralForms

  doctest PluralForms

  describe "parse/1" do
    test "Only one form" do
      assert {:ok, {1, 0}} = PluralForms.parse("nplurals=1; plural=0;")
    end

    test "Two forms, singular used for one only" do
      assert {:ok, {2, {:!=, :n, 1}}} = PluralForms.parse("nplurals=2; plural=n != 1;")
    end

    test "Two forms, singular used for zero and one" do
      assert {:ok, {2, {:>, :n, 1}}} = PluralForms.parse("nplurals=2; plural=n>1;")
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
               PluralForms.parse("nplurals=3; plural=n%10==1 && n%100!=11 ? 0 : n != 0 ? 1 : 2;")
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
                   {
                     :||,
                     {:==, :n, 0},
                     {
                       :&&,
                       {:>, {:%, :n, 100}, 0},
                       {:<, {:%, :n, 100}, 20}
                     }
                   },
                   1,
                   2
                 }
               }}} =
               PluralForms.parse("""
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
                     {
                       :||,
                       {:<, {:%, :n, 100}, 10},
                       {:>=, {:%, :n, 100}, 20}
                     }
                   },
                   1,
                   2
                 }
               }}} =
               PluralForms.parse("""
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
                     {
                       :||,
                       {:<, {:%, :n, 100}, 10},
                       {:>=, {:%, :n, 100}, 20}
                     }
                   },
                   1,
                   2
                 }
               }}} =
               PluralForms.parse("""
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
                 {:==, :n, 1},
                 0,
                 {
                   :if,
                   {
                     :&&,
                     {:>=, :n, 2},
                     {:<=, :n, 4}
                   },
                   1,
                   2
                 }
               }}} =
               PluralForms.parse("""
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
                     {
                       :||,
                       {:<, {:%, :n, 100}, 10},
                       {:>=, {:%, :n, 100}, 20}
                     }
                   },
                   1,
                   2
                 }
               }}} =
               PluralForms.parse("""
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
               PluralForms.parse("""
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
               PluralForms.parse("""
               nplurals=6; \
                     plural=n==0 ? 0 : n==1 ? 1 : n==2 ? 2 : n%100>=3 && n%100<=10 ? 3 \
                     : n%100>=11 ? 4 : 5;
               """)
    end
  end

  describe "index/2" do
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
             PluralForms.parse("""
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
end
