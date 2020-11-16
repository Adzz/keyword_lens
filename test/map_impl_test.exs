defmodule MapImplTest do
  use ExUnit.Case, async: true
  doctest KeywordLens

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

  test "string keys" do
    data = %{"a" => 1, "b" => 2}
    result = KeywordLens.map(data, ["a", "b"], &(&1 + 1))
    assert result == %{"a" => 2, "b" => 3}
  end

  test "number keys" do
    data = %{1 => 1, 2 => 2}
    result = KeywordLens.map(data, [1, 2], &(&1 + 1))
    assert result == %{1 => 2, 2 => 3}
  end

  test "other keys" do
    data = %{1 => %{2 => %{3 => 7}}, %{} => 2}
    result = KeywordLens.map(data, [{1, {2, 3}}], &(&1 + 1))
    assert result == %{1 => %{2 => %{3 => 8}}, %{} => 2}

    data = %{1 => %{2 => %{[] => 7}}, %{} => 2}
    result = KeywordLens.map(data, [{1, {2, []}}], &(&1 + 1))
    assert result == %{1 => %{2 => %{[] => 8}}, %{} => 2}

    data = %{{1, 2} => %{2 => %{[] => 7}}, %{} => 2}
    result = KeywordLens.map(data, [{{1, 2}, {2, []}}], &(&1 + 1))
    assert result == %{%{} => 2, {1, 2} => %{2 => %{[] => 8}}}
  end

  test "Inner map key the same as outer map key" do
    data = %{f: %{}, a: %{a: %{a: 1}, g: %{}, b: %{c: 1}}}
    result = KeywordLens.map(data, [a: [b: [:c]]], &(&1 + 1))
    assert result == %{a: %{a: %{a: 1}, b: %{c: 2}, g: %{}}, f: %{}}

    data = %{f: %{}, a: %{a: %{a: 1}, g: %{}, b: %{c: 1}}}
    result = KeywordLens.map(data, [a: [a: [:a]]], &(&1 + 1))
    assert result == %{a: %{a: %{a: 2}, b: %{c: 1}, g: %{}}, f: %{}}
  end

  test "Other keys Error" do
    data = %{1 => 1, [] => []}

    message =
      "a KeywordLens requires that each key in the path points to a map until the last key in the path. It looks like your path is too long, please check"

    assert_raise(KeywordLens.InvalidPathError, message, fn ->
      KeywordLens.map(data, [{1, {[], :a}}], &(&1 + 1))
    end)
  end

  test "When the path is too long" do
    data = %{a: 1}

    message =
      "a KeywordLens requires that each key in the path points to a map until the last key in the path. It looks like your path is too long, please check"

    assert_raise(KeywordLens.InvalidPathError, message, fn ->
      KeywordLens.map(data, [a: [c: :d]], &(&1 + 1))
    end)
  end

  test "Mixing and matching data" do
    data = %{a: %{b: 1, c: []}}

    message =
      "a KeywordLens requires that each key in the path points to a map until the last key in the path. It looks like your path is too long, please check"

    assert_raise(KeywordLens.InvalidPathError, message, fn ->
      KeywordLens.map(data, [a: [c: :d]], &(&1 + 1))
    end)
  end
end
