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
      [[:a, :b, :d], [:a, :b, :c]]

      iex> KeywordLens.Helpers.expand([a: [:z, b: [:c, d: :e]]])
      [[:a, :b, :d, :e], [:a, :b, :c], [:a, :z]]

      iex> KeywordLens.Helpers.expand([:a, "b", :c])
      [[:c], ["b"], [:a]]

  """
  def expand(paths) do
    expand(paths, [[]])
  end

  defp expand({key, value = {_, _}}, [current | acc]) when not is_list(value) do
    "expand" |> IO.inspect(limit: :infinity, label: "1")
    # TODO: We should probably create these in reverse order ? Does that change anything
    # For this helper it's fine I think. IRL in the map function we do optimizations.
    expand(value, [current ++ [key] | acc])
  end

  defp expand({key, value}, [acc | _]) when not is_list(value) do
    "expand" |> IO.inspect(limit: :infinity, label: "2")
    [acc ++ [key, value]]
  end

  defp expand({key, value}, [current | acc]) when is_list(value) do
    "expand" |> IO.inspect(limit: :infinity, label: "3")
    expand(value, [current ++ [key] | acc])
  end

  defp expand([{key, value}], [current | acc]) when is_list(value) do
    "expand" |> IO.inspect(limit: :infinity, label: "4")
    expand(value, [current ++ [key] | acc])
  end

  defp expand([{key, value}], [current | acc]) when not is_list(value) do
    "expand" |> IO.inspect(limit: :infinity, label: "5")
    [current ++ [key, value] | acc]
  end

  defp expand([value], [current | acc]) do
    "expand" |> IO.inspect(limit: :infinity, label: "6")
    [current ++ [value] | acc]
  end

  defp expand([value | rest], [current | acc]) do
    "expand" |> IO.inspect(limit: :infinity, label: "7")
    expand(rest, [current | [current ++ [value] | acc]])
  end

  defp expand(value, [acc | _]) do
    "expand" |> IO.inspect(limit: :infinity, label: "8")
    [acc ++ [value]]
  end
end
