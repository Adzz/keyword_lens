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
  def map(data, keyword_lens, fun) do
    fun = fn value -> {:cont, fun.(value)} end
    {:cont, result} = lens_in(keyword_lens, data, fun)
    result
  end

  defp lens_in(paths, data, fun), do: lens_in(paths, [[]], data, %{}, fun)

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
    lens_in(next, [current | [[key | current] | acc]], data, data_rest, fun)
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
