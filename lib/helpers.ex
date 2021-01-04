defmodule KeywordLens.Helpers do
  @moduledoc """
  The naming is a bit strange because I can't use the same name as the procotol. This is essentially
  helper functions for KeywordLenses that might span protocol implementations.
  """

  @doc """
  Takes a KeywordLens and turns it into a list of all of the lenses the KeywordLens describes.

  ### Examples

      iex> KeywordLens.Helpers.expand([a: :b])
      [[:a, :b]]

      iex> KeywordLens.Helpers.expand([a: [b: [:c, :d]]])
      [[:a, :b, :c], [:a, :b, :d]]

      iex> KeywordLens.Helpers.expand([a: [b: [c: :d, e: :f]]])
      [[:a, :b, :c, :d], [:a, :b, :e, :f]]

      iex> KeywordLens.Helpers.expand([a: [:z, b: [:c, d: :e]]])
      [[:a, :z], [:a, :b, :c], [:a, :b, :d, :e]]

      iex> KeywordLens.Helpers.expand([:a, "b", :c])
      [[:a], ["b"], [:c]]
  """
  def expand(paths) do
    lens_in_reduce(paths, [[]])
    |> Enum.map(&Enum.reverse/1)
    |> Enum.reverse()
  end

  defp lens_in_reduce({key, value}, [current | acc]) when is_list(value) do
    lens_in_reduce(value, [[key | current] | acc])
  end

  defp lens_in_reduce({key, value = {_, _}}, [current | acc]) do
    lens_in_reduce(value, [[key | current] | acc])
  end

  defp lens_in_reduce({key, value}, [acc | rest]) do
    [[value, key | acc] | rest]
  end

  defp lens_in_reduce([{key, value}], [current | acc]) when is_list(value) do
    lens_in_reduce(value, [[key | current] | acc])
  end

  defp lens_in_reduce([{key, value = {_, _}}], [current | acc]) do
    lens_in_reduce(value, [[key | current] | acc])
  end

  defp lens_in_reduce([{key, value}], [current | rest]) do
    [[value, key | current] | rest]
  end

  defp lens_in_reduce([key], [current | rest]) do
    [[key | current] | rest]
  end

  defp lens_in_reduce([{key, value} | next], [current | acc]) do
    visited = lens_in_reduce({key, value}, [current | acc])
    lens_in_reduce(next, [current | visited])
  end

  defp lens_in_reduce([key | rest], [current | acc]) do
    lens_in_reduce(rest, [current | [[key | current] | acc]])
  end

  defp lens_in_reduce(key, [acc | rest]) do
    [[key | acc] | rest]
  end
end
