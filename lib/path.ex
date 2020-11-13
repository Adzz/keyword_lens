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
  def to_lenses(paths) do
    to_lenses(paths, [[]])
  end

  def to_lenses(value, [acc | _]) when is_atom(value) or is_binary(value) do
    [acc ++ [value]]
  end

  def to_lenses({key, value}, [acc | _]) when is_atom(value) or is_binary(value) do
    [acc ++ [key, value]]
  end

  def to_lenses({key, value}, [current | acc]) when is_list(value) do
    to_lenses(value, [current ++ [key] | acc])
  end

  def to_lenses([{key, value}], [current | acc]) when is_list(value) do
    to_lenses(value, [current ++ [key] | acc])
  end

  def to_lenses([{key, value}], [current | acc]) when is_atom(value) or is_binary(value) do
    [current ++ [key, value] | acc]
  end

  def to_lenses([value], [current | acc]) do
    [current ++ [value] | acc]
  end

  def to_lenses([value | rest], [current | acc]) do
    to_lenses(rest, [current | [current ++ [value] | acc]])
  end
end
