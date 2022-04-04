defmodule Expo.PluralForms do
  @moduledoc """
  Gettext Plural Helper

  https://www.gnu.org/software/gettext/manual/html_node/Plural-forms.html
  """

  @type t :: {nplurals :: pos_integer(), plural :: plural()}
  @type plural ::
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
  @spec parse(content :: String.t()) ::
          {:ok, t()}
          | {:error,
             {:parse_error, message :: String.t(), line :: pos_integer(), offset :: pos_integer()}}
  defdelegate parse(content), to: Expo.PluralForms.Parser

  @doc """
  Convert parsed plural form to string
  """
  @spec compose(plural_forms :: t()) :: iodata()
  defdelegate compose(plural_forms), to: Expo.PluralForms.Composer

  @doc """
  Get Index from PluralForms Header

  ### Examples

      iex> {:ok, {2, plurals}} = Expo.PluralForms.parse("nplurals=2; plural=n != 1;")
      iex> Expo.PluralForms.index(plurals, 4)
      1

  """
  @spec index(plural_forms :: plural(), n :: non_neg_integer()) :: non_neg_integer()
  defdelegate index(plural_form, n), to: Expo.PluralForms.Evaluator

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
