defmodule Expo.PluralForms do
  @moduledoc """
  Gettext Plural Forms Parser

  https://www.gnu.org/software/gettext/manual/html_node/Plural-forms.html
  """

  alias Expo.PluralForms.Known
  alias Expo.PluralForms.Parser

  @type t :: {nplurals :: pos_integer(), plural :: plural()}
  @opaque plural ::
            :n
            | integer()
            | {:!= | :> | :< | :== | :% | :<= | :>= | :&& | :||, plural(), plural()}
            | {:if, plural(), plural(), plural()}
            | {:paren, plural()}

  @doc """
  Parse Plural Forms Header

  ### Examples

      iex> Expo.PluralForms.parse("nplurals=2; plural=n != 1;")
      {:ok, {2, {:!=, :n, 1}}}
  """
  defdelegate parse(content), to: Parser

  @doc """
  Get Index from PluralForms Header

  ### Examples

      iex> {:ok, {2, plurals}} = Expo.PluralForms.parse("nplurals=2; plural=n != 1;")
      iex> Expo.PluralForms.index(plurals, 4)
      1

  """
  @spec index(plural_forms :: plural(), n :: non_neg_integer()) :: non_neg_integer()
  def index(plural, n)
  def index(:n, n) when is_integer(n), do: n
  def index(number, _n) when is_integer(number), do: number

  def index({:if, condition, truthy, falsy}, n),
    do: if(index(condition, n) == 1, do: index(truthy, n), else: index(falsy, n))

  def index({:paren, content}, n), do: index(content, n)

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

  @doc """
  Get Plural Forms for language

  ### Examples

  iex> Expo.PluralForms.plural_form("de")
  {:ok, {2, {:paren, {:!=, :n, 1}}}}

  iex> Expo.PluralForms.plural_form("invalid")
  :error
  """
  @spec plural_form(iso_language_tag :: String.t()) :: {:ok, t()} | :error
  def plural_form(iso_language_tag)

  for {iso_language_tag, plural_form} <- Known.known_plural_forms() do
    def plural_form(unquote(iso_language_tag)), do: {:ok, unquote(Macro.escape(plural_form))}
  end

  def plural_form(locale) do
    case String.split(locale, "_", parts: 2, trim: true) do
      [lang, _territory] -> plural_form(lang)
      _other -> :error
    end
  end

  @doc """
  Convert parsed plural form to string
  """
  @spec compose(plural_forms :: t) :: iodata()
  def compose({nplurals, plural_forms}),
    do: [
      "nplurals=",
      Integer.to_string(nplurals),
      "; plural=",
      compose_plural(plural_forms),
      ";"
    ]

  defp compose_plural(:n), do: "n"
  defp compose_plural(number) when is_integer(number), do: Integer.to_string(number)

  defp compose_plural({:if, condition, truthy, falsy}),
    do: [compose_plural(condition), " ? ", compose_plural(truthy), " : ", compose_plural(falsy)]

  defp compose_plural({:paren, content}),
    do: ["(", compose_plural(content), ")"]

  defp compose_plural({:!=, left, right}),
    do: [compose_plural(left), "!=", compose_plural(right)]

  defp compose_plural({:>, left, right}),
    do: [compose_plural(left), ">", compose_plural(right)]

  defp compose_plural({:<, left, right}),
    do: [compose_plural(left), "<", compose_plural(right)]

  defp compose_plural({:==, left, right}),
    do: [compose_plural(left), "==", compose_plural(right)]

  defp compose_plural({:%, left, right}),
    do: [compose_plural(left), "%", compose_plural(right)]

  defp compose_plural({:>=, left, right}),
    do: [compose_plural(left), ">=", compose_plural(right)]

  defp compose_plural({:<=, left, right}),
    do: [compose_plural(left), "<=", compose_plural(right)]

  defp compose_plural({:&&, left, right}),
    do: [compose_plural(left), " && ", compose_plural(right)]

  defp compose_plural({:||, left, right}),
    do: [compose_plural(left), " || ", compose_plural(right)]
end
