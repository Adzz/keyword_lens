defimpl KeywordLens, for: Map do
  @moduledoc """
  A map implementation of the KeywordLens protocol.
  """

  @doc """
  Calls the reducing function with the value pointed to by each of the lenses encoded within the
  keyword_lens.

  ### Examples

      iex> reducer = fn {key, value}, acc ->
      ...>   {:cont, Map.merge(acc, %{key => value + 1})}
      ...> end
      ...> KeywordLens.reduce_while(data, [:a, :b], %{}, reducer)
      %{a: 2, b: 3}

      iex> reducer = fn {_key, _value}, _acc ->
      ...>   {:halt, {:error, "Oh no!"}}
      ...> end
      ...> KeywordLens.reduce_while(data, [:a, :b], %{}, reducer)
      {:error, "Oh no!"}
  """
  def reduce_while(data, keyword_lens, accumulator, fun) do
    Enum.reduce_while(keyword_lens, accumulator, fn lens, acc ->
      paths = KeywordLens.Helpers.expand(lens)

      result =
        Enum.reduce_while(paths, acc, fn path, accum ->
          lens_in_while(path, [], data, accum, %{}, fun)
        end)

      {:cont, result}
    end)
  end

  defp lens_in_while([], [key | _], data, accumulator, _data_rest, fun) do
    fun.({key, data}, accumulator)
  end

  defp lens_in_while([key | rest], visited, data, accumulator, data_rest, fun)
       when is_map(data) do
    fetched = Map.fetch!(data, key)
    remaining = %{key => data_rest} |> Map.merge(Map.delete(data, key))
    lens_in_while(rest, [key | visited], fetched, accumulator, remaining, fun)
  end

  @doc """
  Maps until the mapping fun returns {:halt, term}, or until we reach the end of the data being
  mapped over. The mapping function must return {:cont, term} to continue to the next iteration.

  Returns data where each value pointed to by the KeywordLens has been replaced by the result
  of calling the fun with that value.
  """
  def map_while(data, keyword_lens, fun) do
    Enum.reduce_while(keyword_lens, data, fn lens, acc ->
      lens |> IO.inspect(limit: :infinity, label: "LENS MAP")
      lens_in(lens, acc, fun)
    end)
  end

  @doc """
  Returns data where each value pointed to by the KeywordLens has been replaced by the result
  of calling the fun with that value.

  ### Examples

      iex> KeywordLens.map(%{a: %{b: 1}}, [a: :b], &(&1 + 1))
      %{a: %{b: 2}}
  """
  def map(data, keyword_lens, fun) do
    fun = fn value -> {:cont, fun.(value)} end

    Enum.reduce(keyword_lens, data, fn lens, acc ->
      {:cont, result} = lens_in(lens, acc, fun)
      result
    end)
  end

  defp lens_in(paths, data, fun) do
    lens_in(paths, [[]], data, %{}, fun)
  end

  defp lens_in({key, value}, [current | acc], data, data_rest, fun) when is_list(value) do
    "lens_in" |> IO.inspect(limit: :infinity, label: "2")
    value |> IO.inspect(limit: :infinity, label: "VALUE")
    fetched = Map.fetch!(data, key)
    remaining = %{key => data_rest} |> Map.merge(Map.delete(data, key))
    lens_in(value, [[key | current] | acc], fetched, remaining, fun)
  end

  defp lens_in({key, value = {_, _}}, [current | acc], data, data_rest, fun) do
    "lens_in" |> IO.inspect(limit: :infinity, label: "3")

    fetched = Map.fetch!(data, key)
    remaining = %{key => data_rest} |> Map.merge(Map.delete(data, key))
    lens_in(value, [[key | current] | acc], fetched, remaining, fun)
  end

  defp lens_in({key, value}, [acc | _], data, data_rest, fun) do
    "lens_in" |> IO.inspect(limit: :infinity, label: "4")

    fetched =
      try do
        Map.fetch!(data, key)
        |> Map.fetch!(value)
      rescue
        BadMapError -> raise KeywordLens.InvalidPathError
      end

    remaining =
      %{value => %{key => data_rest} |> Map.merge(Map.delete(data, key))}
      |> Map.merge(Map.delete(Map.fetch!(data, key), value))

    case fun.(fetched) do
      {:cont, result} -> backtrack([value, key | acc], [], result, remaining)
      halt = {:halt, _} -> halt
      _ -> raise KeywordLens.InvalidReducingFunctionError
    end
  end

  defp lens_in([{key, value}], [current | acc], data, data_rest, fun)
       when is_list(value) or is_tuple(value) do
    "lens_in" |> IO.inspect(limit: :infinity, label: "5")
    fetched = Map.fetch!(data, key)
    remaining = %{key => data_rest} |> Map.merge(Map.delete(data, key))
    lens_in(value, [[key | current] | acc], fetched, remaining, fun)
  end

  defp lens_in([{key, value} | rest], [current | acc], data, data_rest, fun) do
    "lens_in" |> IO.inspect(limit: :infinity, label: "6")

    # Here we need to backtrack a bit
    # We may have to implement step forward / step back.

    # We first have to continue with value
    fetched = Map.fetch!(data, key) |> IO.inspect(limit: :infinity, label: "FETCHED")
    remaining = %{key => data_rest} |> Map.merge(Map.delete(data, key))

    # This takes value to it's end and returns the changed stuff, much like below.
    # So now we need to reverse
    with {:cont, value_result} <- lens_in(value, [[key | current] | acc], fetched, remaining, fun) do
      # Enum.reduce(Enum.reverse(current), value_result, fn key, acc -> Map.fetch!(acc, key) end)
      # end
      # with {:cont, result} <- fun.(fetched),
      # {:cont, dataa} <- backtrack([key | current], [], result, remaining) do
      data =
        Enum.reduce(
          Enum.reverse(current),
          value_result |> IO.inspect(limit: :infinity, label: "VALUE RESULT"),
          fn key, acc ->
            Map.fetch!(acc, key) |> IO.inspect(limit: :infinity, label: "FETCHED")
          end
        )

      lens_in(rest, [current | [[key | current] | acc]], data, data_rest, fun)
    else
      halt = {:halt, _} -> halt
      _ -> raise KeywordLens.InvalidReducingFunctionError
    end
  end

  # this seems wrong as value could be a tuple, and therefore not at the end of the path
  # so the fetch would fail.
  defp lens_in([{key, value}], [current | _], data, data_rest, fun) do
    "lens_in" |> IO.inspect(limit: :infinity, label: "7")

    fetched =
      try do
        Map.fetch!(data, key)
        |> Map.fetch!(value)
      rescue
        BadMapError -> raise KeywordLens.InvalidPathError
      end

    remaining =
      %{value => Map.merge(%{key => data_rest}, Map.delete(data, key))}
      |> Map.merge(Map.delete(Map.fetch!(data, key), value))

    case fun.(fetched) do
      {:cont, result} -> backtrack([value, key | current], [], result, remaining)
      halt = {:halt, _} -> halt
      _ -> raise KeywordLens.InvalidReducingFunctionError
    end
  end

  defp lens_in([key], [current | _], data, data_rest, fun) do
    "lens_in" |> IO.inspect(limit: :infinity, label: "8")
    fetched = Map.fetch!(data, key)
    remaining = %{key => data_rest} |> Map.merge(Map.delete(data, key))

    case fun.(fetched) do
      {:cont, result} -> backtrack([key | current], [], result, remaining)
      halt = {:halt, _} -> halt
      _ -> raise KeywordLens.InvalidReducingFunctionError
    end
  end

  # Here we have gotten to the end of one path, so we need to finish it off, then
  # move to the next path...
  defp lens_in([key | rest], [current | acc], data, data_rest, fun) do
    "lens_in" |> IO.inspect(limit: :infinity, label: "9")
    fetched = Map.fetch!(data, key)
    remaining = %{key => data_rest} |> Map.merge(Map.delete(data, key))

    with {:cont, result} <- fun.(fetched),
         {:cont, dataa} <- backtrack([key | current], [], result, remaining) do
      data = Enum.reduce(Enum.reverse(current), dataa, fn key, acc -> Map.fetch!(acc, key) end)
      lens_in(rest, [current | [[key | current] | acc]], data, data_rest, fun)
    else
      halt = {:halt, _} -> halt
      _ -> raise KeywordLens.InvalidReducingFunctionError
    end
  end

  defp lens_in([], [acc = [key | _] | _], data, data_rest, fun) do
    data_rest |> IO.inspect(limit: :infinity, label: "DATAA REST")
    data |> IO.inspect(limit: :infinity, label: "DATAA")
    key |> IO.inspect(limit: :infinity, label: "major key")

    fetched =
      Map.fetch!(data, key)
      |> IO.inspect(limit: :infinity, label: "fetching")

    remaining =
      %{key => data_rest}
      |> Map.merge(Map.delete(data, key))
      |> IO.inspect(limit: :infinity, label: "remainin")

    case fun.(fetched) |> IO.inspect(limit: :infinity, label: "") do
      {:cont, result} -> backtrack(acc, [], result, remaining)
      halt = {:halt, _} -> halt
      _ -> raise KeywordLens.InvalidReducingFunctionError
    end
  end

  defp lens_in(key, [acc | _], data, data_rest, fun) do
    "lens_in" |> IO.inspect(limit: :infinity, label: "10")
    key |> IO.inspect(limit: :infinity, label: "KEYY")

    fetched = Map.fetch!(data, key)

    remaining = %{key => data_rest} |> Map.merge(Map.delete(data, key))

    case fun.(fetched) |> IO.inspect(limit: :infinity, label: "") do
      {:cont, result} -> backtrack([key | acc], [], result, remaining)
      halt = {:halt, _} -> halt
      _ -> raise KeywordLens.InvalidReducingFunctionError
    end
  end

  defp backtrack([], _visited, data, data_rest) do
    {:cont, Map.merge(data, data_rest)}
  end

  defp backtrack([key | rest], visited, data, data_rest) do
    data = Map.merge(Map.delete(data_rest, key), %{key => data})
    backtrack(rest, [key | visited], data, Map.fetch!(data_rest, key))
  end
end
