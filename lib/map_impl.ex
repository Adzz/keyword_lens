defimpl KeywordLens, for: Map do
  @moduledoc """
  A map implementation of the KeywordLens protocol.
  """

  def map(data, paths, fun) do
    Enum.reduce(paths, data, fn path, acc ->
      lenses = to_lenses(path, fun)
      # Creating the lenses then running through them is simpler but slower I presume
      # we could execute the function at the end of the path and merge the result there anyway.
      Enum.reduce(lenses, acc, fn lens, accum ->
        lens_in(lens, [], accum, %{}, fun)
      end)
    end)
  end

  defp lens_in([], visited, data, data_rest, fun) do
    backtrack(visited, [], fun.(data), data_rest)
  end

  defp lens_in([key | rest], visited, data, data_rest, fun) do
    remaining = %{key => data_rest} |> Map.merge(Map.delete(data, key))
    lens_in(rest, [key | visited], Map.fetch!(data, key), remaining, fun)
  end

  defp backtrack([], _visited, data, data_rest) do
    Map.merge(data, data_rest)
  end

  defp backtrack([key | rest], visited, data, data_rest) do
    data = Map.merge(Map.delete(data_rest, key),%{key => data})
    backtrack(rest, [key | visited], data, Map.fetch!(data_rest, key))
  end

  defp to_lenses(paths, fun) do
    to_lenses(paths, [[]], fun)
  end

  defp to_lenses(value, [acc | _], _fun) when is_atom(value) or is_binary(value) do
    [acc ++ [value]]
  end

  defp to_lenses({key, value}, [acc | _], _fun) when is_atom(value) or is_binary(value) do
    [acc ++ [key, value]]
  end

  defp to_lenses({key, value}, [current | acc], fun) when is_list(value) do
    to_lenses(value, [current ++ [key] | acc], fun)
  end

  defp to_lenses([{key, value}], [current | acc], fun) when is_list(value) do
    to_lenses(value, [current ++ [key] | acc], fun)
  end

  defp to_lenses([{key, value}], [current | acc], _fun) when is_atom(value) or is_binary(value) do
    [current ++ [key, value] | acc]
  end

  defp to_lenses([value], [current | acc], _fun) do
    [current ++ [value] | acc]
  end

  defp to_lenses([value | rest], [current | acc], fun) do
    to_lenses(rest, [current | [current ++ [value] | acc]], fun)
  end
end
