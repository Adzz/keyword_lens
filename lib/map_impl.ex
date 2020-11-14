defimpl KeywordLens, for: Map do
  @moduledoc """
  A map implementation of the KeywordLens protocol.
  """

  def map(data, paths, fun) do
    Enum.reduce(paths, data, fn path, acc ->
      lenses = to_lenses(path, acc, fun)
      lenses |> IO.inspect(limit: :infinity, label: "FIN")
      # Creating the lenses then running through them is simpler but slower I presume
      # we could execute the function at the end of the path and merge the result there anyway.
      # Enum.reduce(lenses, acc, fn lens, accum ->
      # put_in(accum, lens, fun.(get_in(data, lens)))
      # end)
    end)
  end

  # Thread fun, and the end when you have the path, do Map.fetchs so you raise if you can't
  # get it and update the value there.

  defp to_lenses(paths, data, fun) do
    to_lenses(paths, [[]], data, %{}, fun)
  end

  defp to_lenses(key, lenses = [current | acc], data, visited, fun)
       when is_atom(key) or is_binary(key) do
    1 |> IO.inspect(limit: :infinity, label: "FIRST")

    visited =
      Map.merge(visited, Map.delete(data, key))
      |> IO.inspect(limit: :infinity, label: "VISITED")

    data =
      %{key => fun.(Map.fetch!(data, key))}
      |> IO.inspect(limit: :infinity, label: "dataaa")

    backtrack([key], lenses, data, visited, fun)
  end

  #   # Going down:
  #   m = %{a: %{b: :c}, d: %{}}
  #   rest = Map.delete(m, :a) # %{d: %{}}
  #   head = Map.fetch!(m, :a) # %{b: :c}
  #   key = :a

  # # ============================================================
  #   m = %{b: :c}
  #   # How does this get merged with the previous rest or visited.
  #   rest = Map.delete(m, :b) # %{}
  #   head = Map.fetch!(m, :b) # :c
  #   key = :b

  # # ============================================================

  #   new_data = Map.fetch!(data, key)
  # In the world of zippers there is step forwards and step backwards this is all step forwards so
  # far, step back is to come.
  defp to_lenses({key, value}, [current | acc], data, visited, fun)
       when is_atom(value) or is_binary(value) do
    2 |> IO.inspect(limit: :infinity, label: "SECOND")

    visited =
      Map.merge(visited, Map.delete(data, key))
      |> IO.inspect(limit: :infinity, label: "VISITED")

    data =
      %{value => fun.(Map.fetch!(data, key) |> Map.fetch!(value))}
      # %{key => }
      |> IO.inspect(limit: :infinity, label: "dataaa")

    # [[key, value | acc]]
    backtrack([value], [[key | current] | acc], data, visited, fun)
  end

  defp to_lenses({key, value}, [current | acc], data, visited, fun) when is_list(value) do
    3 |> IO.inspect(limit: :infinity, label: "THIRD")

    visited =
      Map.merge(visited, Map.delete(data, key))
      |> IO.inspect(limit: :infinity, label: "VISITED")

    data =
      Map.fetch!(data, key)
      |> IO.inspect(limit: :infinity, label: "DATAAA")

    to_lenses(value, [[key | current] | acc], data, visited, fun)
  end

  defp to_lenses([{key, value}], [current | acc], data, visited, fun) when is_list(value) do
    4 |> IO.inspect(limit: :infinity, label: "FOUR")

    visited =
      Map.merge(visited, %{key => Map.delete(data, key)})
      |> IO.inspect(limit: :infinity, label: "VISITED")

    data =
      Map.fetch!(data, key)
      |> IO.inspect(limit: :infinity, label: "DATAAA")

    to_lenses(value, [[key | current] | acc], data, visited, fun)
  end

  defp to_lenses([{key, value}], [current | acc], data, visited, fun)
       when is_atom(value) or is_binary(value) do
    5 |> IO.inspect(limit: :infinity, label: "FIVE")
    [[key, value | current] | acc]
  end

  defp to_lenses(p = [key], l = [current | acc], data, visited, fun)
       when is_atom(key) or is_binary(key) do
    6 |> IO.inspect(limit: :infinity, label: "SIX")

    visited =
      Map.merge(
        visited |> IO.inspect(limit: :infinity, label: "v"),
        Map.delete(data, key) |> IO.inspect(limit: :infinity, label: "Dddddd")
      )
      |> IO.inspect(limit: :infinity, label: "VISITED")

    # It's only because we are mapping that we do this. I feel like we need to implement reduce
    p |> IO.inspect(limit: :infinity, label: "pppppp")
    l |> IO.inspect(limit: :infinity, label: "llacc")
    data |> IO.inspect(limit: :infinity, label: "detaa")

    data =
      Map.put(data, key, fun.(Map.fetch!(data, key)))
      |> IO.inspect(limit: :infinity, label: "DATAAA")

    # What differs is what you do at the leaf. But what do we need to be given to allow that decision
    # to be abstract. To make a to_lenses function, we'd need the path so far, plus the key.
    # Plus the value we've arrived at I guess... Plus the visited data ?
    backtrack([key], [current | acc], data, visited, fun)
    |> IO.inspect(limit: :infinity, label: "KKKKKKKK")
  end

  defp to_lenses(p = [key | rest], l = [prev | acc], data, visited, fun)
       when is_atom(key) or is_binary(key) do
    7 |> IO.inspect(limit: :infinity, label: "SEVEN")
    p |> IO.inspect(limit: :infinity, label: "pppppp")
    l |> IO.inspect(limit: :infinity, label: "llacc")
    data |> IO.inspect(limit: :infinity, label: "detaa")
    visited |> IO.inspect(limit: :infinity, label: "vis")

    visited =
      Map.merge(visited, %{key => Map.delete(data, key)})
      |> IO.inspect(limit: :infinity, label: "VISITED REALLLYYYYY")

    data =
      Map.put(data, key, fun.(Map.fetch!(data, key)))
      |> IO.inspect(limit: :infinity, label: "OH REALLLYYYYY")

    # When ever we are the end of a path we need to backtrack and the result of backtrack
    # becomes the new data. That's great and all, but now the question becomes how do we recur?
    # We need to
    data =
      backtrack([key], l, data, %{}, fun)
      |> IO.inspect(limit: :infinity, label: "BACK2BACK")

    # data =
    #   Map.put(data, key, fun.(Map.fetch!(data, key)))
    #   |> IO.inspect(limit: :infinity, label: "OH REALLLYYYYY")

    # Map.fetch!(data, key) |> IO.inspect(limit: :infinity, label: "DLTS")
    # d = Map.fetch!(data, prev) |> IO.inspect(limit: :infinity, label: "dldldld")
    rest |> IO.inspect(limit: :infinity, label: "rest")
    prev |> IO.inspect(limit: :infinity, label: "ppppppppppppppppp")
    that = Enum.reverse(rest ++ prev) |> IO.inspect(limit: :infinity, label: "th")

    # # How do we turn a flat list into a nested keyword list?
    # [:c, :a] -> [a: :c]
    # Enum.reduce(rest ++ prev, [], fn
    #   value, [] -> [{nil, value}]
    #   key, acc = [{nil, value}] -> [{key, value}]
    #   key, acc = [{_, value}] -> [{key, value}]
    # end)

    map(data, [a: [:c]], fun) |> Map.drop([key])

    # to_lenses(rest, l, d, visited, fun)
  end

  defp to_lenses(_, _, _, _, _), do: raise("Fucked it")

  defp backtrack(_paths, [[]], data, visited, fun) do
    0 |> IO.inspect(limit: :infinity, label: "BACK ZERO")
    visited |> IO.inspect(limit: :infinity, label: "VISteD")

    data |> IO.inspect(limit: :infinity, label: "")
    Map.merge(data, visited)
    # data
  end

  defp backtrack(paths, l = [[], acc | _], data, visited, fun) do
    0.5 |> IO.inspect(limit: :infinity, label: "HALF")

    data |> IO.inspect(limit: :infinity, label: "detaaa")
    visited |> IO.inspect(limit: :infinity, label: "V")
    l |> IO.inspect(limit: :infinity, label: "LLL")
    paths |> IO.inspect(limit: :infinity, label: "PPP")
    # backtrack([paths], acc, data, %{}, fun)
    acc |> IO.inspect(limit: :infinity, label: "ACCCCCC")
    to_lenses(acc, [[]], data, %{}, fun)
  end

  defp backtrack(paths = [k], l = [current = [key | rest] | acc], data, visited, fun) do
    1 |> IO.inspect(limit: :infinity, label: "BACK ONE")

    current |> IO.inspect(limit: :infinity, label: "L")
    data |> IO.inspect(limit: :infinity, label: "DATAA")
    visited |> IO.inspect(limit: :infinity, label: "VIS")
    # Why the merge
    #
    data =
      Map.merge(%{key => data}, Map.get(visited, key, %{}))
      |> IO.inspect(limit: :infinity, label: "newww detaa")

    visited = Map.delete(visited, key) |> IO.inspect(limit: :infinity, label: "DLT")
    # visited = Map.delete(data, k) |> IO.inspect(limit: :infinity, label: "DLT")
    backtrack([key | paths], [rest | acc], data, visited, fun)
  end

  defp backtrack(paths = [k | _], [[key | rest] | acc], data, visited, fun) do
    2 |> IO.inspect(limit: :infinity, label: "BACK TWO")
    data |> IO.inspect(limit: :infinity, label: "deta")
    visited |> IO.inspect(limit: :infinity, label: "VISted")

    backtrack([key | paths], [rest | acc], %{key => data}, visited, fun)
  end
end
