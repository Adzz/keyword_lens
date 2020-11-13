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
        put_in(accum, lens, fun.(get_in(data, lens)))
      end)
    end)
  end

  # Thread fun, and the end when you have the path, do Map.fetchs so you raise if you can't
  # get it and update the value there.

  defp to_lenses(paths, fun) do
    to_lenses(paths, [[]], fun)
  end

  defp to_lenses(value, [acc | _], fun) when is_atom(value) or is_binary(value) do
    # Here we are at the end of a path. We also need data then to do stuff with it.
    # lens = [acc ++ [value]]
    # Enum.reduce_while(lens)
    # fun.()
    [acc ++ [value]]
  end

  defp to_lenses({key, value}, [acc | _], fun) when is_atom(value) or is_binary(value) do
    [acc ++ [key, value]]
  end

  defp to_lenses({key, value}, [current | acc], fun) when is_list(value) do
    to_lenses(value, [current ++ [key] | acc], fun)
  end

  defp to_lenses([{key, value}], [current | acc], fun) when is_list(value) do
    to_lenses(value, [current ++ [key] | acc], fun)
  end

  defp to_lenses([{key, value}], [current | acc], fun) when is_atom(value) or is_binary(value) do
    [current ++ [key, value] | acc]
  end

  defp to_lenses([value], [current | acc], fun) do
    [current ++ [value] | acc]
  end

  defp to_lenses([value | rest], [current | acc], fun) do
    to_lenses(rest, [current | [current ++ [value] | acc]], fun)
  end
end
