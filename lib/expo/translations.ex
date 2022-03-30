defmodule Expo.Translations do
  @moduledoc """
  Translation List Struct for mo / po files
  """

  alias Expo.Translation

  @typedoc """
  Header Names are case sensitive!
  """
  @type header_name :: String.t()
  @type header_value :: String.t()
  @type header :: {header_name(), header_value()}

  @type t :: %__MODULE__{
          headers: [header],
          translations: [Translation.t()],
          obsolete_translations: [Translation.t()]
        }

  @enforce_keys [:headers, :translations]
  defstruct headers: [], translations: [], obsolete_translations: []

  @spec get_header(translations :: t(), name :: header_name()) :: [header_value()]
  def get_header(%__MODULE__{headers: headers} = _translations, name) when is_binary(name) do
    for {^name, value} <- headers, do: value
  end

  @spec put_header(translations :: t(), name :: header_name(), value :: header_value()) :: t()
  def put_header(%__MODULE__{headers: headers} = translations, name, value)
      when is_binary(name) and is_binary(value) do
    %__MODULE__{translations | headers: List.keystore(headers, name, 0, {name, value})}
  end
end
