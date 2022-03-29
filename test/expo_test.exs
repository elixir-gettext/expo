defmodule ExpoTest do
  use ExUnit.Case
  doctest Expo

  test "greets the world" do
    assert Expo.hello() == :world
  end
end
