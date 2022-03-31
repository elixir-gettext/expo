# credo:disable-for-this-file Credo.Check.Refactor.PipeChainStart
defmodule Expo.PluralForms do
  @moduledoc """
  Gettext Plural Forms Parser

  https://www.gnu.org/software/gettext/manual/html_node/Plural-forms.html

  This parses is extrapolated from prior work of Stefan Lapels:
  https://github.com/slapers/ex_sel
  """

  import NimbleParsec

  @type t :: {nplurals :: pos_integer(), plural :: plural()}
  @opaque plural ::
            :n
            | integer()
            | {:!= | :> | :< | :== | :% | :<= | :>= | :&& | :||, plural(), plural()}
            | {:if, plural(), plural(), plural()}

  #
  # Basics
  #

  optional_whitespace =
    ascii_char([?\s, ?\n, ?\r, ?\t])
    |> times(min: 0)
    |> label("whitespace")
    |> ignore()

  ignore_surrounding_whitespace = fn p ->
    optional_whitespace
    |> concat(p)
    |> ignore(optional_whitespace)
  end

  lparen = label(ascii_char([?(]), "(")
  rparen = label(ascii_char([?)]), ")")

  gt = string(">") |> replace(:>) |> label(">")
  gte = string(">=") |> replace(:>=) |> label(">=")
  lt = string("<") |> replace(:<) |> label("<")
  lte = string("<=") |> replace(:<=) |> label("<=")
  eq = string("==") |> replace(:==) |> label("==")
  neq = string("!=") |> replace(:!=) |> label("!=")

  mod = string("%") |> replace(:%) |> label("%")

  and_ = "&&" |> string() |> replace(:&&)
  or_ = "||" |> string |> replace(:||)

  #
  # Value Expressions
  #
  # <value_expression_num> ::= <int>
  # <int>                  ::= <digit>
  # <value_expression_var> ::= "n"
  # <digit>                ::= "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9"

  value_expression_num = label(integer(min: 1), "integer")

  value_expression_var =
    ascii_char([?n])
    |> replace(:n)
    |> label("n")

  value_expression = choice([value_expression_num, value_expression_var])

  #
  # Arithmetic expressions
  #
  # <arithmetic_expression>        ::= <term> {% <term>}
  # <term>                         ::= <arithmetic_expression_factor> {* | / <arithmetic_expression_factor>}
  # <arithmetic_expression_factor> ::= ( <arithmetic_expression> ) | <const>

  arithmetic_expression_factor =
    [
      ignore(lparen) |> parsec(:arithmetic_expression) |> ignore(rparen),
      value_expression_num,
      value_expression_var
    ]
    |> choice()
    |> ignore_surrounding_whitespace.()

  defcombinatorp :arithmetic_expression,
                 arithmetic_expression_factor
                 |> repeat(concat(mod, arithmetic_expression_factor))
                 |> reduce(:fold_infixl)

  #
  # Comparison expressions
  #
  # <comparison_expression>        ::= <comparison_expression_factor> <eq_op> <comparison_expression_factor> | <comparison_expression_term>
  # <comparison_expression_term>   ::= (<comparison_expression>) | <comparison_expression_ord>
  # <comparison_expression_factor> ::= (<bexpr>) | <comparison_expression_term> | <arithmetic_expression> | <value_expression>
  # <comparison_expression_ord>    ::= <arithmetic_expression> <ord_op> <arithmetic_expression>
  # <ord_op>                       ::= > | >= | < | <=
  # <eq_op>                        ::= != | ==

  comparison_expression_ord =
    parsec(:arithmetic_expression)
    |> choice([gte, lte, gt, lt])
    |> parsec(:arithmetic_expression)
    |> reduce(:fold_infixl)

  comparison_expression_term =
    [
      ignore(lparen) |> parsec(:comparison_expression) |> ignore(rparen),
      comparison_expression_ord
    ]
    |> choice()
    |> ignore_surrounding_whitespace.()

  comparison_expression_factor =
    [
      ignore(lparen) |> parsec(:boolean_expression) |> ignore(rparen),
      comparison_expression_term,
      parsec(:arithmetic_expression),
      value_expression
    ]
    |> choice()
    |> ignore_surrounding_whitespace.()

  defcombinatorp :comparison_expression,
                 choice([
                   comparison_expression_factor
                   |> choice([eq, neq])
                   |> concat(comparison_expression_factor)
                   |> reduce(:fold_infixl),
                   comparison_expression_term
                 ])

  #
  # Boolean logic expressions
  #
  # Priority order (high to low):  AND, OR
  # expressions in parens are evaluated first
  #
  # <boolean_expression>        ::= <boolean_expression_term> {<or> <boolean_expression_term>}
  # <boolean_expression_term>   ::= <boolean_expression_factor> {<and> <boolean_expression_factor>}
  # <boolean_expression_factor> ::= ( <boolean_expression> ) | <comparison_expression> | <vexpr_bool>
  # <or>                        ::= '||'
  # <and>                       ::= '&&'

  boolean_expression_factor =
    choice([
      ignore(lparen) |> parsec(:boolean_expression) |> ignore(rparen),
      parsec(:comparison_expression),
      value_expression_num
    ])
    |> ignore_surrounding_whitespace.()
    |> label("logic factor")

  boolean_expression_term =
    boolean_expression_factor
    |> repeat(concat(and_, boolean_expression_factor))
    |> reduce(:fold_infixl)
    |> label("logic term")

  defcombinatorp :boolean_expression,
                 boolean_expression_term
                 |> repeat(concat(or_, boolean_expression_term))
                 |> reduce(:fold_infixl)
                 |> label("boolean logic expression")

  #
  # Conditional Expression
  #
  # <conditional_expression ::= <boolean_expression> "?" <conditional_expression> ":" <conditional_expression> | <boolean_expression>

  defcombinatorp :conditional_expression,
                 parsec(:boolean_expression)
                 |> optional(
                   string("?")
                   |> label("?")
                   |> replace(:if)
                   |> concat(parsec(:conditional_expression))
                   |> concat(string(":") |> label(":") |> ignore())
                   |> concat(parsec(:conditional_expression))
                 )
                 |> reduce(:to_conditional)

  #
  # Full Header
  #
  # <nplurals>     ::= "nplurals=" <digit>
  # <plural>       ::= "plural=" <conditional_expression>
  # <plural_forms> ::= <nplurals> ";" <plural> ";" EOS

  nplurals =
    string("nplurals=")
    |> ignore()
    |> integer(min: 1)

  plural =
    string("plural=")
    |> ignore()
    |> concat(parsec(:conditional_expression))

  defparsecp :plural_forms,
             nplurals
             |> concat(optional_whitespace)
             |> concat(ignore(string(";")))
             |> concat(optional_whitespace)
             |> concat(plural)
             |> concat(optional_whitespace)
             |> concat(ignore(string(";")))
             |> concat(optional_whitespace)
             |> eos()
             |> reduce({List, :to_tuple, []})

  @doc """
  Parse Plural Forms Header

  ### Examples

      iex> Expo.PluralForms.parse("nplurals=2; plural=n != 1;")
      {:ok, {2, {:!=, :n, 1}}}
  """
  # TODO: specify reason
  @spec parse(content :: String.t()) ::
          {:ok, t()}
          | {:error,
             {:parse_error, message :: String.t(), line :: pos_integer(), offset :: pos_integer()}}
  def parse(content) do
    case plural_forms(content) do
      {:ok, [result], "", _context, _line, _offset} ->
        {:ok, result}

      {:error, message, _rest, _context, {line, _line_offset}, offset} ->
        {:error, {:parse_error, message, line, offset}}
    end
  end

  @spec index(plural_forms :: plural(), n :: non_neg_integer()) :: non_neg_integer()
  def index(plural, n)
  def index(:n, n) when is_integer(n), do: n
  def index(number, _n) when is_integer(number), do: number

  def index({:if, condition, truthy, falsy}, n),
    do: if(index(condition, n) == 1, do: index(truthy, n), else: index(falsy, n))

  def index({:!=, left, right}, n), do: if(index(left, n) != index(right, n), do: 1, else: 0)
  def index({:>, left, right}, n), do: if(index(left, n) > index(right, n), do: 1, else: 0)
  def index({:<, left, right}, n), do: if(index(left, n) < index(right, n), do: 1, else: 0)
  def index({:==, left, right}, n), do: if(index(left, n) == index(right, n), do: 1, else: 0)
  def index({:%, left, right}, n), do: rem(index(left, n), index(right, n))
  def index({:>=, left, right}, n), do: if(index(left, n) >= index(right, n), do: 1, else: 0)
  def index({:<=, left, right}, n), do: if(index(left, n) <= index(right, n), do: 1, else: 0)

  def index({:&&, left, right}, n),
    do: if(index(left, n) == 1 and index(right, n) == 1, do: 1, else: 0)

  def index({:||, left, right}, n),
    do: if(index(left, n) == 1 or index(right, n) == 1, do: 1, else: 0)

  defp fold_infixl(acc) do
    acc
    |> Enum.reverse()
    |> Enum.chunk_every(2)
    |> List.foldr([], fn
      [l], [] -> l
      [r, op], l -> {op, l, r}
    end)
  end

  defp to_conditional(tokens)
  defp to_conditional([expr]), do: expr

  defp to_conditional([condition, :if, truthy, falsy]),
    do: {:if, condition, truthy, falsy}
end
