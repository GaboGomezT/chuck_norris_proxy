defmodule ApiProxyTest do
  use ExUnit.Case
  doctest ApiProxy

  test "greets the world" do
    assert ApiProxy.hello() == :world
  end
end
