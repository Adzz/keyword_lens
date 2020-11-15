defmodule KeywordLens.Paths do
  @moduledoc """
  The naming is a bit strange because I can't use the same name as the procotol. This is essentially
  helper functions for KeywordLenses that might span protocol implementations.
  """

  @doc """
  Takes a KeywordLens and turns it into a list of all of the lenses the KeywordLens describes.

  ### Examples
      iex>  lens = [a: :b]
      [:a, :b]

      iex>lens = [a: [b: [:c, :d]]]
      paths = [[:a, :b, :c], [:a, :b, :d]]

      iex> lens = [a: [:z, b: [:c, d: :e]]]
      [[:a, :z], [:a, :b, :c], [:a, :b, :d, :e]]

      iex>lens = [:a, "b", :c]
      [[:a], ["b"], [:c]]

  """
  defp to_lenses(paths, fun) do
    to_lenses(paths, [[]], fun)
  end

  defp to_lenses({key, value = {_, _}}, [current | acc], fun) when not is_list(value) do
    to_lenses(value, [current ++ [key] | acc], fun)
  end

  defp to_lenses({key, value}, [acc | _], _fun) when not is_list(value) do
    [acc ++ [key, value]]
  end

  defp to_lenses({key, value}, [current | acc], fun) when is_list(value) do
    to_lenses(value, [current ++ [key] | acc], fun)
  end

  defp to_lenses([{key, value}], [current | acc], fun) when is_list(value) do
    to_lenses(value, [current ++ [key] | acc], fun)
  end

  defp to_lenses([{key, value}], [current | acc], _fun) when not is_list(value) do
    [current ++ [key, value] | acc]
  end

  defp to_lenses([value], [current | acc], _fun) do
    [current ++ [value] | acc]
  end

  defp to_lenses([value | rest], [current | acc], fun) do
    to_lenses(rest, [current | [current ++ [value] | acc]], fun)
  end

  defp to_lenses(value, [acc | _], _fun) do
    [acc ++ [value]]
  end
end
