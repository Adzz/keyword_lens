defmodule KeywordLens.Helpers do
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
  def to_paths(paths) do
    to_paths(paths, [[]])
  end

  defp to_paths({key, value = {_, _}}, [current | acc]) when not is_list(value) do
    # We should reverse these probably for perf.
    to_paths(value, [current ++ [key] | acc])
  end

  defp to_paths({key, value}, [acc | _]) when not is_list(value) do
    [acc ++ [key, value]]
  end

  defp to_paths({key, value}, [current | acc]) when is_list(value) do
    to_paths(value, [current ++ [key] | acc])
  end

  defp to_paths([{key, value}], [current | acc]) when is_list(value) do
    to_paths(value, [current ++ [key] | acc])
  end

  defp to_paths([{key, value}], [current | acc]) when not is_list(value) do
    [current ++ [key, value] | acc]
  end

  defp to_paths([value], [current | acc]) do
    [current ++ [value] | acc]
  end

  defp to_paths([value | rest], [current | acc]) do
    to_paths(rest, [current | [current ++ [value] | acc]])
  end

  defp to_paths(value, [acc | _]) do
    [acc ++ [value]]
  end
end
