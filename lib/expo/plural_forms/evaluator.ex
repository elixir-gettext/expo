defmodule Expo.PluralForms.Evaluator do
  @moduledoc false

  alias Expo.PluralForms

  @spec index(plural_forms :: PluralForms.plural(), n :: non_neg_integer()) :: non_neg_integer()
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

  @spec compile_index(plural_forms :: PluralForms.plural()) :: Macro.t()
  def compile_index(plural)

  def compile_index(:n) do
    quote do
      var!(n)
    end
  end

  def compile_index(number) when is_integer(number), do: number

  def compile_index({:if, condition, truthy, falsy}) do
    quote do
      if unquote(compile_index(condition)) == 1,
        do: unquote(compile_index(truthy)),
        else: unquote(compile_index(falsy))
    end
  end

  def compile_index({:paren, content}), do: compile_index(content)

  def compile_index({:!=, left, right}) do
    quote do
      if unquote(compile_index(left)) != unquote(compile_index(right)),
        do: 1,
        else: 0
    end
  end

  def compile_index({:>, left, right}) do
    quote do
      if unquote(compile_index(left)) > unquote(compile_index(right)),
        do: 1,
        else: 0
    end
  end

  def compile_index({:<, left, right}) do
    quote do
      if unquote(compile_index(left)) < unquote(compile_index(right)),
        do: 1,
        else: 0
    end
  end

  def compile_index({:==, left, right}) do
    quote do
      if unquote(compile_index(left)) == unquote(compile_index(right)),
        do: 1,
        else: 0
    end
  end

  def compile_index({:%, left, right}) do
    quote do
      rem(unquote(compile_index(left)), unquote(compile_index(right)))
    end
  end

  def compile_index({:>=, left, right}) do
    quote do
      if unquote(compile_index(left)) >= unquote(compile_index(right)),
        do: 1,
        else: 0
    end
  end

  def compile_index({:<=, left, right}) do
    quote do
      if unquote(compile_index(left)) <= unquote(compile_index(right)),
        do: 1,
        else: 0
    end
  end

  def compile_index({:&&, left, right}) do
    quote do
      if unquote(compile_index(left)) == 1 and unquote(compile_index(right)) == 1,
        do: 1,
        else: 0
    end
  end

  def compile_index({:||, left, right}) do
    quote do
      if unquote(compile_index(left)) == 1 or unquote(compile_index(right)) == 1,
        do: 1,
        else: 0
    end
  end
end
