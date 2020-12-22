defmodule MapImplTest do
  use ExUnit.Case, async: true
  doctest KeywordLens

  describe "reduce_while" do
    test "We can reduce a map successfully" do
      data = %{a: 1, b: 2}

      reducer = fn {key, value}, acc ->
        {:cont, Map.merge(acc, %{key => value + 1})}
      end

      result = KeywordLens.reduce_while(data, [:a, :b], %{}, reducer)
      assert result == %{a: 2, b: 3}
    end

    test "we can halt the reduce" do
      data = %{a: 1, b: 2}

      reducer = fn {_key, _value}, _acc ->
        {:halt, {:error, "Oh no!"}}
      end

      result = KeywordLens.reduce_while(data, [:a, :b], %{}, reducer)
      assert result == {:error, "Oh no!"}
    end
  end

  describe "map_while" do
    test "does this work?" do
      data = %{state: %{params: %{price: 10}, other: %{thing: 1}}}

      result =
        KeywordLens.map_while(data, [state: [params: :price, other: :thing]], fn x ->
          {:cont, IO.inspect(x, limit: :infinity, label: "XX") + 1}
        end)

      assert result == %{a: 2, b: 3}

      data = %{state: %{params: %{price: 10}, other: %{thing: 1}}}

      result = KeywordLens.map_while(data, [state: [params: :price]], &{:cont, &1 + 1})

      assert result == %{a: 2, b: 3}
    end

    test "we can map without a stop like normal" do
      data = %{a: 1, b: 2}
      result = KeywordLens.map_while(data, [:a, :b], &{:cont, &1 + 1})
      assert result == %{a: 2, b: 3}
    end

    test "We can halt" do
      data = %{a: 1, b: 2}
      result = KeywordLens.map_while(data, [:a, :b], &{:halt, {:error, "#{&1} is no good"}})
      assert result == {:error, "1 is no good"}
    end

    test "error if the mapping function seems wrong" do
      data = %{a: 1, b: 2}
      message = "The reducing function should return {:cont, term} or {:halt, term}"

      assert_raise(KeywordLens.InvalidReducingFunctionError, message, fn ->
        KeywordLens.map_while(data, [:a, :b], &(&1 + 1))
      end)
    end

    test "Three deep" do
      data = %{f: %{}, a: %{g: %{}, b: %{c: 1}}}
      result = KeywordLens.map_while(data, [a: [b: [:c]]], &{:cont, &1 + 1})
      assert result == %{f: %{}, a: %{g: %{}, b: %{c: 2}}}
    end

    test "Three deep no extra" do
      data = %{a: %{b: %{c: 1}}}
      result = KeywordLens.map_while(data, [a: [b: [:c]]], &{:cont, &1 + 1})
      assert result == %{a: %{b: %{c: 2}}}
    end

    test "We can do a simple list" do
      data = %{a: %{b: 1}}
      result = KeywordLens.map_while(data, [a: :b], &{:cont, &1 + 1})
      assert result == %{a: %{b: 2}}
    end

    test "We can do a less simple list" do
      data = %{a: %{b: 1, c: 2}}
      result = KeywordLens.map_while(data, [a: [:b, :c]], &{:cont, &1 + 1})
      assert result == %{a: %{b: 2, c: 3}}
    end

    test "We can do a less simple list nested again" do
      data = %{a: %{d: %{b: 1, c: 2}}}
      result = KeywordLens.map_while(data, [a: [d: [:b, :c]]], &{:cont, &1 + 1})
      assert result == %{a: %{d: %{b: 2, c: 3}}}
    end

    test "We can do an even less simple list" do
      data = %{a: %{b: 1, c: %{d: 3, e: 4}}}
      result = KeywordLens.map_while(data, [a: [:b, c: [:d, :e]]], &{:cont, &1 + 1})
      assert result == %{a: %{b: 2, c: %{d: 4, e: 5}}}
    end

    test "We can do another less simple list" do
      data = %{a: %{b: 1, c: %{d: 3, e: 4}}}
      result = KeywordLens.map_while(data, [a: [:b, c: :d]], &{:cont, &1 + 1})
      assert result == %{a: %{b: 2, c: %{d: 4, e: 4}}}
    end

    test "Sure why not" do
      data = %{a: %{b: 1, c: %{d: 3, e: 4}}}
      result = KeywordLens.map_while(data, [a: [:b, c: :d]], &{:cont, &1 + 1})
      assert result == %{a: %{b: 2, c: %{d: 4, e: 4}}}
    end

    test "string keys" do
      data = %{"a" => 1, "b" => 2}
      result = KeywordLens.map_while(data, ["a", "b"], &{:cont, &1 + 1})
      assert result == %{"a" => 2, "b" => 3}
    end

    test "number keys" do
      data = %{1 => 1, 2 => 2}
      result = KeywordLens.map_while(data, [1, 2], &{:cont, &1 + 1})
      assert result == %{1 => 2, 2 => 3}
    end

    test "other keys" do
      data = %{1 => %{2 => %{3 => 7}}, %{} => 2}
      result = KeywordLens.map_while(data, [{1, {2, 3}}], &{:cont, &1 + 1})
      assert result == %{1 => %{2 => %{3 => 8}}, %{} => 2}

      data = %{1 => %{2 => %{[] => 7}}, %{} => 2}
      result = KeywordLens.map_while(data, [{1, {2, []}}], &{:cont, &1 + 1})
      assert result == %{1 => %{2 => %{[] => 8}}, %{} => 2}

      data = %{{1, 2} => %{2 => %{[] => 7}}, %{} => 2}
      result = KeywordLens.map_while(data, [{{1, 2}, {2, []}}], &{:cont, &1 + 1})
      assert result == %{%{} => 2, {1, 2} => %{2 => %{[] => 8}}}
    end

    test "Inner map key the same as outer map key" do
      data = %{f: %{}, a: %{a: %{a: 1}, g: %{}, b: %{c: 1}}}
      result = KeywordLens.map_while(data, [a: [b: [:c]]], &{:cont, &1 + 1})
      assert result == %{a: %{a: %{a: 1}, b: %{c: 2}, g: %{}}, f: %{}}

      data = %{f: %{}, a: %{a: %{a: 1}, g: %{}, b: %{c: 1}}}
      result = KeywordLens.map_while(data, [a: [a: [:a]]], &{:cont, &1 + 1})
      assert result == %{a: %{a: %{a: 2}, b: %{c: 1}, g: %{}}, f: %{}}
    end

    test "deep legs" do
      data = %{a: %{b: 1, c: %{d: 3, e: 4}}, f: %{g: %{h: 5}}}
      result = KeywordLens.map_while(data, [a: [:b, c: :d], f: [g: :h]], &{:cont, &1 + 1})
      %{a: %{b: 2, c: %{d: 4, b: 2}}, f: %{g: %{h: 6}}}
      assert result == %{a: %{b: 2, c: %{d: 4, e: 4}}, f: %{g: %{h: 6}}}

      data = %{a: %{b: 1, c: %{d: 3, e: 4}}, f: %{b: %{c: 5}}}
      result = KeywordLens.map_while(data, [a: [:b, c: :d], f: [b: :c]], &{:cont, &1 + 1})
      assert result == %{a: %{b: 2, c: %{d: 4, e: 4}}, f: %{b: %{c: 6}}}
    end

    test "Other keys Error" do
      data = %{1 => 1, [] => []}

      message =
        "a KeywordLens requires that each key in the path points to a map until the last key in the path. It looks like your path is too long, please check"

      assert_raise(KeywordLens.InvalidPathError, message, fn ->
        KeywordLens.map_while(data, [{1, {[], :a}}], &{:cont, &1 + 1})
      end)
    end

    test "When the path is too long" do
      data = %{a: 1}

      message =
        "a KeywordLens requires that each key in the path points to a map until the last key in the path. It looks like your path is too long, please check"

      assert_raise(KeywordLens.InvalidPathError, message, fn ->
        KeywordLens.map_while(data, [a: [c: :d]], &{:cont, &1 + 1})
      end)
    end

    test "Mixing and matching data" do
      data = %{a: %{b: 1, c: []}}

      message =
        "a KeywordLens requires that each key in the path points to a map until the last key in the path. It looks like your path is too long, please check"

      assert_raise(KeywordLens.InvalidPathError, message, fn ->
        KeywordLens.map_while(data, [a: [c: :d]], &{:cont, &1 + 1})
      end)
    end
  end

  describe "map" do
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

    test "other keys - map" do
      data = %{1 => %{2 => %{3 => 7}}, %{} => 2}
      result = KeywordLens.map(data, [{1, {2, 3}}], &(&1 + 1))
      assert result == %{1 => %{2 => %{3 => 8}}, %{} => 2}
    end

    test "other keys - list key" do
      data = %{1 => %{2 => %{[] => 7}}, %{} => 2}
      result = KeywordLens.map(data, [{1, {2, []}}], &(&1 + 1))
      assert result == %{1 => %{2 => %{[] => 8}}, %{} => 2}
    end

    test "other keys - mixed" do
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

    test "deep legs" do
      data = %{a: %{b: 1, c: %{d: 3, e: 4}}, f: %{g: %{h: 5}}}
      result = KeywordLens.map(data, [a: [:b, c: :d], f: [g: :h]], &(&1 + 1))
      %{a: %{b: 2, c: %{d: 4, b: 2}}, f: %{g: %{h: 6}}}
      assert result == %{a: %{b: 2, c: %{d: 4, e: 4}}, f: %{g: %{h: 6}}}

      data = %{a: %{b: 1, c: %{d: 3, e: 4}}, f: %{b: %{c: 5}}}
      result = KeywordLens.map(data, [a: [:b, c: :d], f: [b: :c]], &(&1 + 1))
      assert result == %{a: %{b: 2, c: %{d: 4, e: 4}}, f: %{b: %{c: 6}}}
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
end
