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
    # THERE ARE TWO OPTIONS HERE WE NEED TO BENCHMARK
    # 1. do lens_in but at the end of the paths call the fun with acc.
    # 2. Expand paths and then do the work.
    # If we get the expanding of paths working this is an alternative approach to benchmark
    # against:
    # Enum.reduce_while(keyword_lens, accumulator, fn lens, acc ->
    # paths = KeywordLens.Helpers.expand(lens)
    # result =
    #   Enum.reduce_while(paths, acc, fn path, accum ->
    #     lens_in_while(path, [], data, accum, %{}, fun)
    #   end)
    # {:cont, result}
    # end)

    # defp lens_in_while([], [key | _], data, accumulator, _data_rest, fun) do
    #   fun.({key, data}, accumulator)
    # end

    # defp lens_in_while([key | rest], visited, data, accumulator, data_rest, fun)
    #      when is_map(data) do
    #   fetched = Map.fetch!(data, key)
    #   remaining = %{key => data_rest} |> Map.merge(Map.delete(data, key))
    #   lens_in_while(rest, [key | visited], fetched, accumulator, remaining, fun)
    # end
    case lens_in_reduce(keyword_lens, data, accumulator, fun) do
      {:cont, {_, result}} -> result
      {:halt, result} -> result
    end
  end

  defp lens_in_reduce(paths, data, acc, fun) do
    lens_in_reduce(paths, [[]], data, %{}, acc, fun)
  end

  defp lens_in_reduce({key, value}, [current | acc], data, data_rest, accu, fun)
       when is_list(value) do
    {fetched, remaining} = step_forward(data, key, data_rest)
    lens_in_reduce(value, [[key | current] | acc], fetched, remaining, accu, fun)
  end

  defp lens_in_reduce({key, value = {_, _}}, [current | acc], data, data_rest, accu, fun) do
    {fetched, remaining} = step_forward(data, key, data_rest)
    lens_in_reduce(value, [[key | current] | acc], fetched, remaining, accu, fun)
  end

  defp lens_in_reduce({key, value}, [acc | _], data, data_rest, accu, fun) do
    {fetched, remaining} = step_forward(data, key, data_rest)
    {fetched, remaining} = step_forward(fetched, value, remaining)

    case fun.({value, fetched}, accu) do
      {:cont, result} -> backtrack_reduce([value, key | acc], [], result, remaining, result)
      halt = {:halt, _} -> halt
      _ -> raise KeywordLens.InvalidReducingFunctionError
    end
  end

  defp lens_in_reduce([{key, value}], [current | acc], data, data_rest, accu, fun)
       when is_list(value) do
    {fetched, remaining} = step_forward(data, key, data_rest)
    lens_in_reduce(value, [[key | current] | acc], fetched, remaining, accu, fun)
  end

  defp lens_in_reduce([{key, value = {_, _}}], [current | acc], data, data_rest, accu, fun) do
    {fetched, remaining} = step_forward(data, key, data_rest)
    lens_in_reduce(value, [[key | current] | acc], fetched, remaining, accu, fun)
  end

  defp lens_in_reduce([{key, value}], [current | _], data, data_rest, accu, fun) do
    {fetched, remaining} = step_forward(data, key, data_rest)
    {fetched, remaining} = step_forward(fetched, value, remaining)

    case fun.({value, fetched}, accu) do
      {:cont, result} -> backtrack_reduce([value, key | current], [], result, remaining, result)
      halt = {:halt, _} -> halt
      _ -> raise KeywordLens.InvalidReducingFunctionError
    end
  end

  defp lens_in_reduce([key], [current | _], data, data_rest, acc, fun) do
    {fetched, remaining} = step_forward(data, key, data_rest)

    case fun.({key, fetched}, acc) do
      {:cont, result} -> backtrack_reduce([key | current], [], result, remaining, result)
      halt = {:halt, _} -> halt
      _ -> raise KeywordLens.InvalidReducingFunctionError
    end
  end

  defp lens_in_reduce([{key, value} | next], [current | acc], data, data_rest, accu, fun) do
    {:cont, {leg, accum}} =
      lens_in_reduce({key, value}, [current | acc], data, data_rest, accu, fun)

    data = Enum.reduce(Enum.reverse(current), leg, &Map.fetch!(&2, &1))
    lens_in_reduce(next, [current | [[value, key | current] | acc]], data, data_rest, accum, fun)
  end

  defp lens_in_reduce([key | rest], [current | acc], data, data_rest, accu, fun) do
    {fetched, remaining} = step_forward(data, key, data_rest)

    with {:cont, result} <- fun.({key, fetched}, accu),
         {:cont, {dataa, accum}} <-
           backtrack_reduce([key | current], [], result, remaining, result) do
      data = Enum.reduce(Enum.reverse(current), dataa, &Map.fetch!(&2, &1))
      lens_in_reduce(rest, [current | [[key | current] | acc]], data, data_rest, accum, fun)
    else
      halt = {:halt, _} -> halt
      _ -> raise KeywordLens.InvalidReducingFunctionError
    end
  end

  defp lens_in_reduce(key, [acc | _], data, data_rest, accu, fun) do
    {fetched, remaining} = step_forward(data, key, data_rest)

    case fun.({key, fetched}, accu) do
      {:cont, result} -> backtrack_reduce([key | acc], [], result, remaining, result)
      halt = {:halt, _} -> halt
      _ -> raise KeywordLens.InvalidReducingFunctionError
    end
  end

  defp backtrack_reduce([], _visited, data, data_rest, acc) do
    {:cont, {Map.merge(data, data_rest), acc}}
  end

  defp backtrack_reduce([key | rest], visited, data, data_rest, acc) do
    data = Map.merge(Map.delete(data_rest, key), %{key => data})
    backtrack_reduce(rest, [key | visited], data, Map.fetch!(data_rest, key), acc)
  end

  @doc """
  Maps until the mapping fun returns {:halt, term}, or until we reach the end of the data being
  mapped over. The mapping function must return {:cont, term} to continue to the next iteration.
  Returns data where each value pointed to by the KeywordLens has been replaced by the result
  of calling the fun with that value.
  """
  def map_while(data, keyword_lens, fun) do
    case lens_in(keyword_lens, data, fun) do
      {:cont, result} -> result
      {:halt, result} -> result
    end
  end

  @doc """
  Returns data where each value pointed to by the KeywordLens has been replaced by the result
  of calling the fun with that value.

  ### Examples

      iex> KeywordLens.map(%{a: %{b: 1}}, [a: :b], &(&1 + 1))
      %{a: %{b: 2}}
  """
  # Is this really map_values
  # map would follow elixir convention of returning list... That would mean we need to do an into
  # But would allow us to map keys. Or we could add a map_keys function. The issue would be
  # you now need to map twice to change the key and value... Maybe that's not bad.
  # probably no worse than an into though.... But can get tricky.

  # We can't expand then map values if we want to give a different error message than
  # invalid map - which I sort of feel like we do (to make things clearer). The tradeoff
  # is that it's slower. HOWEVER, users could do it themselves maybe ?
  def map(data, keyword_lens, fun) do
    fun = fn value -> {:cont, fun.(value)} end
    # KeywordLens.Helpers.expand(keyword_lens)
    # |> Enum.reduce(data, fn path, accum ->
    #   {_, res} = get_and_update_in(accum, path, &{&1, fun.(&1)})
    #   res
    # end)
    {:cont, result} = lens_in(keyword_lens, data, fun)
    result
  end

  defp lens_in(paths, data, fun) do
    lens_in(paths, [[]], data, %{}, fun)
  end

  defp lens_in({key, value}, [current | acc], data, data_rest, fun) when is_list(value) do
    {fetched, remaining} = step_forward(data, key, data_rest)
    lens_in(value, [[key | current] | acc], fetched, remaining, fun)
  end

  defp lens_in({key, value = {_, _}}, [current | acc], data, data_rest, fun) do
    {fetched, remaining} = step_forward(data, key, data_rest)
    lens_in(value, [[key | current] | acc], fetched, remaining, fun)
  end

  defp lens_in({key, value}, [acc | _], data, data_rest, fun) do
    {fetched, remaining} = step_forward(data, key, data_rest)
    {fetched, remaining} = step_forward(fetched, value, remaining)

    case fun.(fetched) do
      {:cont, result} -> backtrack([value, key | acc], [], result, remaining)
      halt = {:halt, _} -> halt
      _ -> raise KeywordLens.InvalidReducingFunctionError
    end
  end

  defp lens_in([{key, value}], [current | acc], data, data_rest, fun) when is_list(value) do
    {fetched, remaining} = step_forward(data, key, data_rest)
    lens_in(value, [[key | current] | acc], fetched, remaining, fun)
  end

  defp lens_in([{key, value = {_, _}}], [current | acc], data, data_rest, fun) do
    {fetched, remaining} = step_forward(data, key, data_rest)
    lens_in(value, [[key | current] | acc], fetched, remaining, fun)
  end

  defp lens_in([{key, value}], [current | _], data, data_rest, fun) do
    {fetched, remaining} = step_forward(data, key, data_rest)
    {fetched, remaining} = step_forward(fetched, value, remaining)

    case fun.(fetched) do
      {:cont, result} -> backtrack([value, key | current], [], result, remaining)
      halt = {:halt, _} -> halt
      _ -> raise KeywordLens.InvalidReducingFunctionError
    end
  end

  defp lens_in([key], [current | _], data, data_rest, fun) do
    {fetched, remaining} = step_forward(data, key, data_rest)

    case fun.(fetched) do
      {:cont, result} -> backtrack([key | current], [], result, remaining)
      halt = {:halt, _} -> halt
      _ -> raise KeywordLens.InvalidReducingFunctionError
    end
  end

  defp lens_in([{key, value} | next], [current | acc], data, data_rest, fun) do
    {:cont, leg} = lens_in({key, value}, [current | acc], data, data_rest, fun)
    data = Enum.reduce(Enum.reverse(current), leg, fn key, acc -> Map.fetch!(acc, key) end)
    lens_in(next, [current | [[value, key | current] | acc]], data, data_rest, fun)
  end

  defp lens_in([key | rest], [current | acc], data, data_rest, fun) do
    {fetched, remaining} = step_forward(data, key, data_rest)

    with {:cont, result} <- fun.(fetched),
         {:cont, dataa} <- backtrack([key | current], [], result, remaining) do
      data = Enum.reduce(Enum.reverse(current), dataa, fn key, acc -> Map.fetch!(acc, key) end)
      lens_in(rest, [current | [[key | current] | acc]], data, data_rest, fun)
    else
      halt = {:halt, _} -> halt
      _ -> raise KeywordLens.InvalidReducingFunctionError
    end
  end

  defp lens_in(key, [acc | _], data, data_rest, fun) do
    {fetched, remaining} = step_forward(data, key, data_rest)

    case fun.(fetched) do
      {:cont, result} -> backtrack([key | acc], [], result, remaining)
      halt = {:halt, _} -> halt
      _ -> raise KeywordLens.InvalidReducingFunctionError
    end
  end

  def step_forward(data, key, data_rest \\ %{}) do
    fetched =
      try do
        # Do we fetch or get? Can we have an API to pick each one?
        # If you do this then we get autovivication which IS PRETTY WILD.
        # Map.get(data, key, %{})
        Map.fetch!(data, key)
      rescue
        BadMapError -> raise KeywordLens.InvalidPathError
      end

    remaining = %{key => data_rest} |> Map.merge(Map.delete(data, key))
    {fetched, remaining}
  end

  defp backtrack([], _visited, data, data_rest), do: {:cont, Map.merge(data, data_rest)}

  defp backtrack([key | rest], visited, data, data_rest) do
    data = Map.merge(Map.delete(data_rest, key), %{key => data})
    backtrack(rest, [key | visited], data, Map.fetch!(data_rest, key))
  end
end
