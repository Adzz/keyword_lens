defimpl KeywordLens, for: Map do
  @moduledoc """
  A map implementation of the KeywordLens protocol.
  """

  @doc """
  Returns a new map where each value pointed to by the KeywordLens

  Maps over the provided data passing each value at the end of every path in the KeywordLens to the
  fun,
  """
  def map(data, keyword_lens, fun) do
    Enum.reduce(keyword_lens, data, fn lens, acc ->
      paths = KeywordLens.Helpers.expand(lens)
      # TODO:
      # Creating the lenses then running through them is simpler but slower I presume
      # we could execute the function at the end of the path and merge the result there anyway.
      # I'm pretty sure we can do this in one pass so we should do that.
      Enum.reduce(paths, acc, fn path, accum ->
        lens_in(path, [], accum, %{}, fun)
      end)
    end)
  end

  defp lens_in([], visited, data, data_rest, fun) do
    backtrack(visited, [], fun.(data), data_rest)
  end

  defp lens_in([key | rest], visited, data, data_rest, fun) when is_map(data) do
    fetched = Map.fetch!(data, key)
    remaining = %{key => data_rest} |> Map.merge(Map.delete(data, key))
    lens_in(rest, [key | visited], fetched, remaining, fun)
  end

  defp lens_in(_lens, _visited, _, _, _) do
    raise KeywordLens.InvalidPathError
  end

  defp backtrack([], _visited, data, data_rest) do
    Map.merge(data, data_rest)
  end

  defp backtrack([key | rest], visited, data, data_rest) do
    data = Map.merge(Map.delete(data_rest, key), %{key => data})
    backtrack(rest, [key | visited], data, Map.fetch!(data_rest, key))
  end

  defp to_paths(paths, fun) do
    to_paths(paths, [[]], fun)
  end

  defp to_paths({key, value = {_, _}}, [current | acc], fun) when not is_list(value) do
    to_paths(value, [current ++ [key] | acc], fun)
  end

  defp to_paths({key, value}, [acc | _], _fun) when not is_list(value) do
    # Instead of this we should call the fun and backtrack. But that requires
    [acc ++ [key, value]]
  end

  defp to_paths({key, value}, [current | acc], fun) when is_list(value) do
    to_paths(value, [current ++ [key] | acc], fun)
  end

  defp to_paths([{key, value}], [current | acc], fun) when is_list(value) do
    to_paths(value, [current ++ [key] | acc], fun)
  end

  defp to_paths([{key, value}], [current | acc], _fun) when not is_list(value) do
    [current ++ [key, value] | acc]
  end

  defp to_paths([value], [current | acc], _fun) do
    [current ++ [value] | acc]
  end

  defp to_paths([value | rest], [current | acc], fun) do
    to_paths(rest, [current | [current ++ [value] | acc]], fun)
  end

  defp to_paths(value, [acc | _], _fun) do
    [acc ++ [value]]
  end
end
