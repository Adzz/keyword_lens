defprotocol KeywordLens do
  @moduledoc """
  A keyword lens is a nested keyword-like structure used to describe paths into certain data types.
  It is similar to the list you can provide to Ecto's Repo.preload/2

  You can describe a KeywordLens like this:
  [a: :b, c: [d: :e]]

  Such a list is handy for describing a subset of a nested map structure. For example, you can
  imagine the following path: [a: :b] applied to this map: %{a: %{b: 1}} points to the value 1.

  It's not a proper Keyword list because we allow string keys for convenience, so this is valid:

  [{"a", :b}]

  In effect the list is a list of paths to values contained in a given data structure. This is
  useful for describing changes that should apply to a subset of a nested data structure.

  ### Examples

  Here are some examples of different KeywordLenses and the unique set of paths they represent.

  ```elixir
  lens = [a: :b]
  paths = [:a, :b]

  lens = [a: [b: [:c, :d]]]
  paths = [[:a, :b, :c], [:a, :b, :d]]

  lens = [a: [:z, b: [:c, d: :e]]]
  paths = [[:a, :z], [:a, :b, :c], [:a, :b, :d, :e]]

  lens = [:a, "b", :c]
  paths = [[:a], ["b"], [:c]]
  ```
  """

  @doc """
  Should replace the values found at the end of each of the paths in data with the result of fun
  called with the data found at the end of that path. An example for maps is shown below.

  ### Examples

      iex> KeywordLens.map(%{a: %{b: 1}}, [a: :b], &(&1 + 1))
      %{a: %{b: 2}}
  """
  def map(data, paths, fun)
end
