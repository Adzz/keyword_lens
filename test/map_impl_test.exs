defmodule MapImplTest do
  use ExUnit.Case, async: true
  # doctest KeywordLens

  test "We can do the simplest list" do
    data = %{a: 1, b: 2}
    result = KeywordLens.map(data, [:a, :b], &(&1 + 1))
    assert result == %{a: 2, b: 3}
  end

  test "Three deep" do
    data = %{f: %{}, a: %{g: %{}, b: %{c: 1}}}
    result = KeywordLens.map(data, [a: [b: [:c]]], &(&1 + 1))
    assert result == %{f: %{}, a: %{g: %{}, b: %{c: 2}}}
  end

  test "Three deep no extra" do
    data = %{a: %{b: %{c: 1}}}
    result = KeywordLens.map(data, [a: [b: [:c]]], &(&1 + 1))
    assert result == %{a: %{b: %{c: 2}}}
  end

  test "We can do a simple list" do
    data = %{a: %{b: 1}}
    result = KeywordLens.map(data, [a: :b], &(&1 + 1))
    assert result == %{a: %{b: 2}}
  end

  test "We can do a less simple list" do
    data = %{a: %{b: 1, c: 2}}
    result = KeywordLens.map(data, [a: [:b, :c]], &(&1 + 1))
    assert result == %{a: %{b: 2, c: 3}}
  end

  test "We can do a less simple list nested again" do
    data = %{a: %{d: %{b: 1, c: 2}}}
    result = KeywordLens.map(data, [a: [d: [:b, :c]]], &(&1 + 1))
    assert result == %{a: %{d: %{b: 2, c: 3}}}
  end

  test "We can do an even less simple list" do
    data = %{a: %{b: 1, c: %{d: 3, e: 4}}}
    result = KeywordLens.map(data, [a: [:b, c: [:d, :e]]], &(&1 + 1))
    assert result == %{a: %{b: 2, c: %{d: 4, e: 5}}}
  end

  test "We can do another less simple list" do
    data = %{a: %{b: 1, c: %{d: 3, e: 4}}}
    result = KeywordLens.map(data, [a: [:b, c: :d]], &(&1 + 1))
    assert result == %{a: %{b: 2, c: %{d: 4, e: 4}}}
  end

  test "Sure why not" do
    data = %{a: %{b: 1, c: %{d: 3, e: 4}}}
    result = KeywordLens.map(data, [a: [:b, c: :d]], &(&1 + 1))
    assert result == %{a: %{b: 2, c: %{d: 4, e: 4}}}
  end

  test "When the path is too long" do
  end

  test "When the path tries to lens into something opaque" do
    data = %{a: 1}
    result = KeywordLens.map(data, [a: [c: :d]], &(&1 + 1))
    assert result == %{a: %{b: 2, c: %{d: 4, e: 4}}}
  end
end
