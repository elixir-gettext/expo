defmodule Expo.PluralForms do
  @moduledoc """
  Gettext Plural Helper

  https://www.gnu.org/software/gettext/manual/html_node/Plural-forms.html
  """

  alias Expo.PluralForms.SyntaxError

  @type t :: {nplurals :: pos_integer(), plural :: plural()}
  @type plural ::
          :n
          | integer()
          | {:!= | :> | :< | :== | :% | :<= | :>= | :&& | :||, plural(), plural()}
          | {:if, plural(), plural(), plural()}
          | {:paren, plural()}

  @type parse_error ::
          {:error,
           {:parse_error, message :: String.t(), line :: pos_integer(), offset :: pos_integer()}}

  @doc """
  Parse Plural Forms Header

  ### Examples

      iex> Expo.PluralForms.parse_string("nplurals=2; plural=n != 1;")
      {:ok, {2, {:!=, :n, 1}}}
  """
  @spec parse_string(content :: String.t()) ::
          {:ok, t()}
          | parse_error()
  defdelegate parse_string(content), to: Expo.PluralForms.Parser, as: :parse

  @doc """
  Parse Plural Forms Header

  Works exactly like `parse_string/1`, but returns a plural forms tuple
   if there are no errors or raises a `Expo.PluralForms.SyntaxError` error
   if there are.

  ### Examples

      iex> Expo.PluralForms.parse_string!("nplurals=2; plural=n != 1;")
      {2, {:!=, :n, 1}}

      iex> Expo.PluralForms.parse_string!("invalid")
      ** (Expo.PluralForms.SyntaxError) 1:0 expected string \"nplurals=\"

  """
  @spec parse_string!(content :: String.t()) :: t() | no_return()
  def parse_string!(content) do
    case parse_string(content) do
      {:ok, plural_forms} ->
        plural_forms

      {:error, {:parse_error, reason, line, offset}} ->
        raise SyntaxError, line: line, reason: reason, offset: offset
    end
  end

  @doc """
  Convert parsed plural form to string
  """
  @spec compose(plural_forms :: t()) :: iodata()
  defdelegate compose(plural_forms), to: Expo.PluralForms.Composer

  @doc """
  Get Index from PluralForms Header

  ### Examples

      iex> {:ok, {2, plurals}} = Expo.PluralForms.parse_string("nplurals=2; plural=n != 1;")
      iex> Expo.PluralForms.index(plurals, 4)
      1

  """
  @spec index(plural_forms :: plural(), n :: non_neg_integer()) :: non_neg_integer()
  defdelegate index(plural_form, n), to: Expo.PluralForms.Evaluator

  @doc """
  Compile plural forms so that it returns the index

  ### Bindings

  * `n` - the number to get the index for

  ### Usage

      defmodule MyModule do
        {:ok, {2, plurals}} = Expo.PluralForms.parse_string("nplurals=2; plural=n>1;")
        def index(n), do: unquote(Expo.PluralForms.compile_index(plurals))
      end

  """
  @spec compile_index(plural_forms :: plural()) :: Macro.t()
  defdelegate compile_index(plural_forms), to: Expo.PluralForms.Evaluator

  @doc """
  Get Plural Forms for language

  ### Examples

      iex> Expo.PluralForms.plural_form("de")
      {:ok, {2, {:paren, {:!=, :n, 1}}}}

      iex> Expo.PluralForms.plural_form("invalid")
      :error
  """
  @spec plural_form(iso_language_tag :: String.t()) :: {:ok, t()} | :error
  defdelegate plural_form(iso_language_tag), to: Expo.PluralForms.Known
end
