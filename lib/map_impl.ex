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
  Returns data with each value pointed to by the KeywordLens has been replaced by the result
  of calling the fun with that value.

  ### Examples

      iex> KeywordLens.map(%{a: %{b: 1}}, [a: :b], &(&1 + 1))
      %{a: %{b: 2}}
  """
  def map(data, keyword_lens, fun) do
    Enum.reduce(keyword_lens, data, fn lens, acc ->
      lens_in(lens, acc, fun)
    end)
  end

  defp lens_in(paths, data, fun) do
    lens_in(paths, [[]], data, %{}, fun)
  end

  defp lens_in({key, value}, [current | acc], data, data_rest, fun) when is_list(value) do
    fetched = Map.fetch!(data, key)
    remaining = %{key => data_rest} |> Map.merge(Map.delete(data, key))
    lens_in(value, [[key | current] | acc], fetched, remaining, fun)
  end

  defp lens_in({key, value = {_, _}}, [current | acc], data, data_rest, fun) do
    fetched = Map.fetch!(data, key)
    remaining = %{key => data_rest} |> Map.merge(Map.delete(data, key))
    lens_in(value, [[key | current] | acc], fetched, remaining, fun)
  end

  defp lens_in({key, value}, [acc | _], data, data_rest, fun) do
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

    backtrack([value, key | acc], [], fun.(fetched), remaining)
  end

  defp lens_in([{key, value}], [current | acc], data, data_rest, fun) when is_list(value) do
    fetched = Map.fetch!(data, key)
    remaining = %{key => data_rest} |> Map.merge(Map.delete(data, key))
    lens_in(value, [[key | current] | acc], fetched, remaining, fun)
  end

  defp lens_in([{key, value}], [current | _], data, data_rest, fun) do
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

    backtrack([value, key | current], [], fun.(fetched), remaining)
  end

  defp lens_in([key], [current | _], data, data_rest, fun) do
    fetched = Map.fetch!(data, key)
    remaining = %{key => data_rest} |> Map.merge(Map.delete(data, key))
    backtrack([key | current], [], fun.(fetched), remaining)
  end

  # Here we have gotten to the end of one path, so we need to finish it off, then
  # move to the next path.
  defp lens_in([key | rest], [current | acc], data, data_rest, fun) do
    fetched = Map.fetch!(data, key)
    remaining = %{key => data_rest} |> Map.merge(Map.delete(data, key))
    dataa = backtrack([key | current], [], fun.(fetched), remaining)

    data =
      Enum.reduce(Enum.reverse(current), dataa, fn key, acc ->
        Map.fetch!(acc, key)
      end)

    lens_in(rest, [current | [[key | current] | acc]], data, data_rest, fun)
  end

  defp lens_in(key, [acc | _], data, data_rest, fun) do
    fetched = Map.fetch!(data, key)
    remaining = %{key => data_rest} |> Map.merge(Map.delete(data, key))
    backtrack([key | acc], [], fun.(fetched), remaining)
  end

  defp backtrack([], _visited, data, data_rest) do
    Map.merge(data, data_rest)
  end

  defp backtrack([key | rest], visited, data, data_rest) do
    data = Map.merge(Map.delete(data_rest, key), %{key => data})
    backtrack(rest, [key | visited], data, Map.fetch!(data_rest, key))
  end
end
