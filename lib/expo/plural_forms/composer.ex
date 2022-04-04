defmodule Expo.PluralForms.Composer do
  @moduledoc false

  alias Expo.PluralForms

  @spec compose(plural_forms :: PluralForms.t()) :: iodata()
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
