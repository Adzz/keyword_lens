defimpl KeywordLens, for: Map do
  @moduledoc """
  A map implementation of the KeywordLens protocol.
  """

  def map(data, paths, fun) do
    Enum.reduce(paths, data, fn path, acc ->
      lenses =
        to_lenses(path, fun)
        |> IO.inspect(limit: :infinity, label: "lens")

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

  defp lens_in([key | rest], visited, data, data_rest, fun) when is_map(data) do
    data |> IO.inspect(limit: :infinity, label: "D")
    data_rest |> IO.inspect(limit: :infinity, label: "DR")
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

  defp to_lenses(paths, fun) do
    "i" |> IO.inspect(limit: :infinity, label: "1")
    to_lenses(paths, [[]], fun)
  end

  defp to_lenses({key, value = {_, _}}, [current | acc], fun) when not is_list(value) do
    "i" |> IO.inspect(limit: :infinity, label: "1.5")
    to_lenses(value, [current ++ [key] | acc], fun)
  end

  defp to_lenses({key, value}, [acc | _], _fun) when not is_list(value) do
    "i" |> IO.inspect(limit: :infinity, label: "2")
    [acc ++ [key, value]]
  end

  defp to_lenses({key, value}, [current | acc], fun) when is_list(value) do
    "i" |> IO.inspect(limit: :infinity, label: "3")
    to_lenses(value, [current ++ [key] | acc], fun)
  end

  defp to_lenses([{key, value}], [current | acc], fun) when is_list(value) do
    "i" |> IO.inspect(limit: :infinity, label: "4")
    to_lenses(value, [current ++ [key] | acc], fun)
  end

  defp to_lenses([{key, value}], [current | acc], _fun) when not is_list(value) do
    "i" |> IO.inspect(limit: :infinity, label: "5")
    [current ++ [key, value] | acc]
  end

  defp to_lenses([value], [current | acc], _fun) do
    "i" |> IO.inspect(limit: :infinity, label: "6")
    [current ++ [value] | acc]
  end

  defp to_lenses([value | rest], [current | acc], fun) do
    "i" |> IO.inspect(limit: :infinity, label: "7")
    to_lenses(rest, [current | [current ++ [value] | acc]], fun)
  end

  defp to_lenses(value, [acc | _], _fun) do
    "i" |> IO.inspect(limit: :infinity, label: "8")
    [acc ++ [value]]
  end
end
