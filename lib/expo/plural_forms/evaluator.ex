defmodule Expo.PluralForms.Evaluator do
  @moduledoc false

  alias Expo.PluralForms

  @boolean_operators [:!=, :>, :<, :==, :>=, :<=, :&&, :||]

  defmodule IntegerOperators do
    @moduledoc false

    # credo:disable-for-lines:28 Credo.Check.Readability.Specs
    # credo:disable-for-lines:27 Credo.Check.Readability.FunctionNames

    def left != right when Kernel.!=(left, right), do: 1
    def _left != _right, do: 0

    def left == right when Kernel.==(left, right), do: 1
    def _left == _right, do: 0

    def left > right when Kernel.>(left, right), do: 1
    def _left > _right, do: 0

    def left < right when Kernel.<(left, right), do: 1
    def _left < _right, do: 0

    def left <= right when Kernel.<=(left, right), do: 1
    def _left <= _right, do: 0

    def left >= right when Kernel.>=(left, right), do: 1
    def _left >= _right, do: 0

    # credo:disable-for-next-line Credo.Check.Warning.BoolOperationOnSameValues
    def 1 && 1, do: 1
    def _left && _right, do: 0

    def 1 || _right, do: 1
    def _left || 1, do: 1
    def _left || _right, do: 0
  end

  @spec index(plural_forms :: PluralForms.plural(), n :: non_neg_integer()) :: non_neg_integer()
  def index(plural, n)
  def index(:n, n) when is_integer(n), do: n
  def index(number, _n) when is_integer(number), do: number

  def index({:if, condition, truthy, falsy}, n),
    do: if(index(condition, n) == 1, do: index(truthy, n), else: index(falsy, n))

  def index({:paren, content}, n), do: index(content, n)

  for operator <- @boolean_operators do
    def index({unquote(operator), left, right}, n),
      do: IntegerOperators.unquote(operator)(index(left, n), index(right, n))
  end

  def index({:%, left, right}, n), do: rem(index(left, n), index(right, n))

  @spec compile_index(plural_forms :: PluralForms.plural()) :: Macro.t()
  def compile_index(plural) do
    plural
    |> unroll_nested_ifs_to_cond()
    |> _compile_index()
  end

  defp unroll_nested_ifs_to_cond(plural)

  defp unroll_nested_ifs_to_cond({:if, condition, truthy, falsy}) do
    condition = unroll_nested_ifs_to_cond(condition)
    truthy = unroll_nested_ifs_to_cond(truthy)
    falsy = unroll_nested_ifs_to_cond(falsy)

    # Only the false branch needs unrolling since only that is actually used
    conditions =
      case falsy do
        {:cond, child_conditions} -> [{condition, truthy} | child_conditions]
        other -> [{condition, truthy}, {1, other}]
      end

    {:cond, conditions}
  end

  defp unroll_nested_ifs_to_cond({:paren, plural}),
    do: {:paren, unroll_nested_ifs_to_cond(plural)}

  defp unroll_nested_ifs_to_cond({operator, left, right})
       when operator in [:!=, :>, :<, :==, :%, :>=, :<=, :&&, :||],
       do: {operator, unroll_nested_ifs_to_cond(left), unroll_nested_ifs_to_cond(right)}

  defp unroll_nested_ifs_to_cond(:n), do: :n
  defp unroll_nested_ifs_to_cond(number) when is_integer(number), do: number

  defp _compile_index(plural)

  defp _compile_index(:n) do
    quote do
      var!(n)
    end
  end

  defp _compile_index(number) when is_integer(number), do: number

  defp _compile_index({:cond, conditions}) do
    conditions =
      Enum.map(conditions, fn
        {1, result} ->
          {:->, [], [[true], _compile_index(result)]}

        {condition, result} ->
          {:->, [],
           [
             [
               quote do
                 Kernel.==(unquote(_compile_index(condition)), 1)
               end
             ],
             _compile_index(result)
           ]}
      end)

    quote do
      cond do: unquote(conditions)
    end
  end

  defp _compile_index({:paren, content}), do: _compile_index(content)

  defp _compile_index({:%, left, right}) do
    quote do
      rem(unquote(_compile_index(left)), unquote(_compile_index(right)))
    end
  end

  for operator <- @boolean_operators do
    defp _compile_index({unquote(operator) = operator, left, right}) do
      quote do
        IntegerOperators.unquote(operator)(
          unquote(_compile_index(left)),
          unquote(_compile_index(right))
        )
      end
    end
  end
end
