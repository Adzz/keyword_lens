defmodule MapImplTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  doctest KeywordLens

  describe "reduce_while - suspend" do
    test "we can suspend the enumeration, and then continue it" do
      data = %{a: 1, b: 2}

      reducer = fn
        {key, value}, acc -> {:suspend, Map.merge(acc, %{key => value + 1})}
        # {key, value}, {:cont, acc} -> {:suspend, Map.merge(acc, %{key => value + 1})}
        # _, {:halt, acc} -> acc
        # _, aaac -> aaac |> IO.inspect(limit: :infinity, label: "aaaac")
      end

      {:suspended, acc, continue} = KeywordLens.reduce_while(data, [:a, :b], %{}, reducer)
      assert acc == %{a: 2}
      {:suspended, acc, continue} = continue.({:cont, acc})
      assert acc == %{a: 2, b: 3}
      continue.({:cont, acc})
      |> IO.inspect(limit: :infinity, label: "")
    end
  end

  describe "reduce_while" do
    test "does this work?" do
      data = %{state: %{params: %{price: 10}, other: %{thing: 1}}}
      reducer = fn {key, value}, acc -> {:cont, Map.merge(acc, %{key => value + 1})} end

      result =
        KeywordLens.reduce_while(data, [state: [params: :price, other: :thing]], %{}, reducer)

      assert result == %{price: 11, thing: 2}
      # This is map:
      # %{state: %{other: %{thing: 2}, params: %{price: 11}}}
      # Reduce just collects up the values at the ends of the lists.... so yea
      # %{price: 11, thing: 2}
    end

    test "mixed keys and stuff" do
      data = %{:a => 1, "b" => 2, :c => 3}
      lens = [:a, "b", :c]
      reducer = fn {key, value}, acc -> {:cont, Map.merge(acc, %{key => value + 1})} end
      result = KeywordLens.reduce_while(data, lens, %{}, reducer)
      assert result == %{:a => 2, :c => 4, "b" => 3}
    end

    test "Does half this work?" do
      data = %{state: %{params: %{price: 10}, other: %{thing: 1}}}
      reducer = fn {key, value}, acc -> {:cont, Map.merge(acc, %{key => value + 1})} end
      result = KeywordLens.reduce_while(data, [state: [params: :price]], %{}, reducer)
      assert result == %{price: 11}
    end

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
          {:cont, x + 1}
        end)

      assert result == %{state: %{other: %{thing: 2}, params: %{price: 11}}}
    end

    test "Does half this work?" do
      data = %{state: %{params: %{price: 10}, other: %{thing: 1}}}
      result = KeywordLens.map_while(data, [state: [params: :price]], &{:cont, &1 + 1})
      assert result == %{state: %{other: %{thing: 1}, params: %{price: 11}}}
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

      result =
        KeywordLens.map_while(data, [a: [b: [:c]]], fn x ->
          {:cont, x + 1}
        end)

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
        "a KeywordLens requires that each key in the path points to a map until the last key in the path. It looks like your path is wrong, please check."

      assert_raise(KeywordLens.InvalidPathError, message, fn ->
        KeywordLens.map_while(data, [{1, {[], :a}}], &{:cont, &1 + 1})
      end)
    end

    test "When the path is wrong" do
      data = %{a: 1}

      message =
        "a KeywordLens requires that each key in the path points to a map until the last key in the path. It looks like your path is wrong, please check."

      assert_raise(KeywordLens.InvalidPathError, message, fn ->
        KeywordLens.map_while(data, [a: [c: :d]], &{:cont, &1 + 1})
      end)
    end

    test "Mixing and matching data" do
      data = %{a: %{b: 1, c: []}}

      message =
        "a KeywordLens requires that each key in the path points to a map until the last key in the path. It looks like your path is wrong, please check."

      assert_raise(KeywordLens.InvalidPathError, message, fn ->
        KeywordLens.map_while(data, [a: [c: :d]], &{:cont, &1 + 1})
      end)
    end
  end

  describe "map" do
    # MAP SHOULD GET THE KEY AND VALUE PASSED TO THE FUN. oh shit.
    # now we are all in the territory of maps returning lists.
    # We either always preserve keys as we do here, or we have to
    # pass key and value to the fun and collect into a list.
    # We get to reuse collect though I think. But do we have to then
    # implement Enum.into etc for this? Where does it end...

    test "many top level components" do
      data = %{a: %{b: 1}, c: %{d: 2}}
      result = KeywordLens.map(data, [a: :b, c: :d], &(&1 + 1))
      assert result == %{a: %{b: 2}, c: %{d: 3}}

      assert result == the_other_way(data, a: :b, c: :d)
    end

    test "When the map doesn't have the key" do
      # The issue is sometimes we may want to nil it.
      # get_in do we need ! variants of everything?
      # map! vs map
      # that doesn't mean it can't raise though, it will still raise if the path is pointing
      # to something that isn't there. it's just if we try to get
      assert_raise(KeyError, "key :a not found in: %{}", fn ->
        KeywordLens.map(%{}, [:a], & &1)
      end)

      assert_raise(KeyError, "key :b not found in: %{}", fn ->
        KeywordLens.map(%{a: %{}}, [a: :b], & &1)
      end)
    end

    test "does this work?" do
      data = %{state: %{params: %{price: 10}, other: %{thing: 1}}}
      result = KeywordLens.map(data, [state: [params: :price, other: :thing]], &(&1 + 1))
      assert result == %{state: %{other: %{thing: 2}, params: %{price: 11}}}
      assert result == the_other_way(data, state: [params: :price, other: :thing])
    end

    test "Does half this work?" do
      data = %{state: %{params: %{price: 10}, other: %{thing: 1}}}
      result = KeywordLens.map(data, [state: [params: :price]], &(&1 + 1))
      assert result == %{state: %{other: %{thing: 1}, params: %{price: 11}}}
      assert result == the_other_way(data, state: [params: :price])
    end

    test "We can do the simplest list" do
      data = %{a: 1, b: 2}
      result = KeywordLens.map(data, [:a, :b], &(&1 + 1))
      assert result == %{a: 2, b: 3}
      assert result == the_other_way(data, [:a, :b])
    end

    test "Three deep" do
      data = %{f: %{}, a: %{g: %{}, b: %{c: 1}}}
      result = KeywordLens.map(data, [a: [b: [:c]]], &(&1 + 1))
      assert result == %{f: %{}, a: %{g: %{}, b: %{c: 2}}}
      assert result == the_other_way(data, a: [b: [:c]])
    end

    test "Three deep no extra" do
      data = %{a: %{b: %{c: 1}}}
      result = KeywordLens.map(data, [a: [b: [:c]]], &(&1 + 1))
      assert result == %{a: %{b: %{c: 2}}}
      assert result == the_other_way(data, a: [b: [:c]])
    end

    test "We can do a simple list" do
      data = %{a: %{b: 1}}
      result = KeywordLens.map(data, [a: :b], &(&1 + 1))
      assert result == %{a: %{b: 2}}
      assert result == the_other_way(data, a: :b)
    end

    test "We can do a less simple list" do
      data = %{a: %{b: 1, c: 2}}
      result = KeywordLens.map(data, [a: [:b, :c]], &(&1 + 1))
      assert result == %{a: %{b: 2, c: 3}}
      assert result == the_other_way(data, a: [:b, :c])
    end

    test "We can do a less simple list nested again" do
      data = %{a: %{d: %{b: 1, c: 2}}}
      result = KeywordLens.map(data, [a: [d: [:b, :c]]], &(&1 + 1))
      assert result == %{a: %{d: %{b: 2, c: 3}}}
      assert result == the_other_way(data, a: [d: [:b, :c]])
    end

    test "We can do an even less simple list" do
      data = %{a: %{b: 1, c: %{d: 3, e: 4}}}
      result = KeywordLens.map(data, [a: [:b, c: [:d, :e]]], &(&1 + 1))
      assert result == %{a: %{b: 2, c: %{d: 4, e: 5}}}
      assert result == the_other_way(data, a: [:b, c: [:d, :e]])
    end

    test "We can do another less simple list" do
      data = %{a: %{b: 1, c: %{d: 3, e: 4}}}
      result = KeywordLens.map(data, [a: [:b, c: :d]], &(&1 + 1))
      assert result == %{a: %{b: 2, c: %{d: 4, e: 4}}}
      assert result == the_other_way(data, a: [:b, c: :d])
    end

    test "Sure why not" do
      data = %{a: %{b: 1, c: %{d: 3, e: 4}}}
      result = KeywordLens.map(data, [a: [:b, c: :d]], &(&1 + 1))
      assert result == %{a: %{b: 2, c: %{d: 4, e: 4}}}
      assert result == the_other_way(data, a: [:b, c: :d])
    end

    test "string keys" do
      data = %{"a" => 1, "b" => 2}
      result = KeywordLens.map(data, ["a", "b"], &(&1 + 1))
      assert result == %{"a" => 2, "b" => 3}
      assert result == the_other_way(data, ["a", "b"])
    end

    test "number keys" do
      data = %{1 => 1, 2 => 2}
      result = KeywordLens.map(data, [1, 2], &(&1 + 1))
      assert result == %{1 => 2, 2 => 3}
      assert result == the_other_way(data, [1, 2])
    end

    test "other keys - map" do
      data = %{1 => %{2 => %{3 => 7}}, %{} => 2}
      result = KeywordLens.map(data, [{1, {2, 3}}], &(&1 + 1))
      assert result == %{1 => %{2 => %{3 => 8}}, %{} => 2}
      assert result == the_other_way(data, [{1, {2, 3}}])
    end

    test "other keys - list key" do
      data = %{1 => %{2 => %{[] => 7}}, %{} => 2}
      result = KeywordLens.map(data, [{1, {2, []}}], &(&1 + 1))
      assert result == %{1 => %{2 => %{[] => 8}}, %{} => 2}
      assert result == the_other_way(data, [{1, {2, []}}])
    end

    test "other keys - mixed" do
      data = %{{1, 2} => %{2 => %{[] => 7}}, %{} => 2}
      result = KeywordLens.map(data, [{{1, 2}, {2, []}}], &(&1 + 1))
      assert result == %{%{} => 2, {1, 2} => %{2 => %{[] => 8}}}
      assert result == the_other_way(data, [{{1, 2}, {2, []}}])
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
        "a KeywordLens requires that each key in the path points to a map until the last key in the path. It looks like your path is wrong, please check."

      assert_raise(KeywordLens.InvalidPathError, message, fn ->
        KeywordLens.map(data, [{1, {[], :a}}], &(&1 + 1))
      end)
    end

    test "When the path doesn't point to a map" do
      data = %{a: 1}

      message =
        "a KeywordLens requires that each key in the path points to a map until the last key in the path. It looks like your path is wrong, please check."

      assert_raise(KeywordLens.InvalidPathError, message, fn ->
        KeywordLens.map(data, [a: [c: :d]], &(&1 + 1))
      end)
    end

    test "Mixing and matching data" do
      data = %{a: %{b: 1, c: []}}

      message =
        "a KeywordLens requires that each key in the path points to a map until the last key in the path. It looks like your path is wrong, please check."

      assert_raise(KeywordLens.InvalidPathError, message, fn ->
        KeywordLens.map(data, [a: [c: :d]], &(&1 + 1))
      end)
    end

    @tag timeout: :infinity
    @tag :property
    test "property tests" do
      check all(
              generated_lists <-
                StreamData.integer()
                |> StreamData.keyword_of()
                |> StreamData.keyword_of(),
              default_map <-
                StreamData.map_of(
                  StreamData.term(),
                  StreamData.map_of(StreamData.term(), StreamData.boolean())
                )
            ) do
        generated_list = generated_lists |> Enum.map(&KeywordLens.Helpers.expand/1)

        map =
          Enum.reduce(generated_list, %{}, fn p, acc ->
            Map.merge(
              acc,
              Enum.reduce(p, acc, fn z, accum ->
                put_in(accum, Enum.map(z, &Access.key(&1, default_map)), 42)
              end)
            )
          end)

        result =
          Enum.reduce(generated_lists, map, fn lens, acc ->
            KeywordLens.map(acc, lens, &(&1 * 2))
          end)

        oracle =
          Enum.reduce(generated_lists, map, fn lens, acc ->
            KeywordLens.Helpers.expand(lens)
            |> Enum.reduce(acc, fn path, accum ->
              {_, res} = get_and_update_in(accum, path, &{&1, &1 * 2})
              res
            end)
          end)

        assert result == oracle
      end
    end
  end

  def the_other_way(data, lens) do
    KeywordLens.Helpers.expand(lens)
    |> Enum.reduce(data, fn path, acc ->
      {_, res} = get_and_update_in(acc, path, &{&1, &1 + 1})
      res
    end)
  end
end
