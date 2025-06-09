defmodule LLMExTest do
  use ExUnit.Case
  doctest LLMEx

  test "greets the world" do
    assert LLMEx.hello() == :world
  end
end
