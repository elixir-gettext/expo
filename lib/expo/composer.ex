defmodule Expo.Composer do
  @moduledoc """
  Composer Behaviour
  """

  alias Expo.Translations

  @callback compose(translations :: Translations.t(), opts :: Keyword.t()) :: iodata()
end
