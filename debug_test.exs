defmodule DebugTest do
  use ExUnit.Case, async: true

  describe "map" do
    # We need to separate the traversal from the zipping and the function?
    # The traversal and the zipping / unzipping are intimately tied because
    # each step requires manipulating the data structure being zipped / unzipped.
    # So the cases are going down and going across.
    # Each step down is easy - you turn the map inside out as you go, and return it
    # to normal by "backtracking"

    # Step right means we just take the result so far and use that as the acc.

    # Each step forward / step back. What is that?
    test "simple" do

    end
  end
end
