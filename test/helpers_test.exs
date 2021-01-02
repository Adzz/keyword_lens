defmodule KeywordLens.HelpersTest do
  use ExUnit.Case, async: true
  doctest KeywordLens.Helpers

  test "simple" do
    assert KeywordLens.Helpers.expand(a: :b) == [[:a, :b]]
  end

  test "multiple" do
    assert KeywordLens.Helpers.expand(a: :b, c: :d) == [[:a, :b], [:c, :d]]
  end

  test "multiple legs" do
    assert KeywordLens.Helpers.expand(z: [a: :b, c: :d]) == [[:z, :a, :b], [:z, :c, :d]]
  end

  test "different keys" do
    assert KeywordLens.Helpers.expand([{"z", [a: :b, c: :d]}]) == [["z", :a, :b], ["z", :c, :d]]
    assert KeywordLens.Helpers.expand([{"z", [{1, :b}, c: :d]}]) == [["z", 1, :b], ["z", :c, :d]]

    assert KeywordLens.Helpers.expand([{"z", [{[1], :b}, c: :d]}]) == [
             ["z", [1], :b],
             ["z", :c, :d]
           ]
  end
end
