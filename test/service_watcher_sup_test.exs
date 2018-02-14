defmodule Service.WatcherTest do
  use ExUnit.Case
  doctest Service.Watcher

  test "greets the world" do
    assert Service.Watcher.hello() == :world
  end
end
