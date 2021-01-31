defprotocol KeywordLens do
  @moduledoc """
  A keyword lens is a nested keyword-like structure used to describe paths into certain data types.
  It is similar to the list you can provide to Ecto's Repo.preload/2

  You can describe a KeywordLens like this:
  `[a: :b, c: [d: :e]]`

  Such a list is handy for describing a subset of a nested map structure. For example, you can
  imagine the following path: `[a: :b]` applied to this map: `%{a: %{b: 1}}` points to the value 1.

  It's not a proper Keyword list because we allow string keys for convenience, so this is valid:

  `[{"a", :b}]`

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

zip_with(l, r, fun)
zip_with(stuff, fun)

# Fun here would need to be 3 airity
zip_with(l, r, acc, fun)
# Fun here would need to be 2 airity, the first is a list.
zip_with(stuff, acc, fun)


  You can implement this protocol for your own data types and therefore define different ways that
  the KeywordLens can be applied to your data structures. A map implementation is provided for
  convenience.
  """

  @doc """
  Should replace the values found at the end of each of the paths in data with the result of fun
  called with the data found at the end of that path. An example for maps is shown below.

  ### Examples

      iex> KeywordLens.map(%{a: %{b: 1}}, [a: :b], &(&1 + 1))
      %{a: %{b: 2}}
  """
  # As implemented right now, map takes a map and returns a map. That's problematic cause
  # the fun never gets the keys. Is that an issue? Who knows but it's different from elixir core
  # So we could instead do a map that gets the Key / Fun and returns a list of key fun,
  # then implement a deep Into fun I guess. but we'd have no way of knowing if the thing
  # nested or the value was what it is.... AHH.
  def map(data, keyword_lens, fun)
  def map_while(data, keyword_lens, fun)
  def reduce_while(data, keyword_lens, acc, fun)
  def reduce(data, keyword_lens, acc, fun)
  # Both need to be maps really (for map impl)
  def zip_with_while(data, data_2, keyword_lens, fun)
  def zip_while(data, data_2, keyword_lens, acc, fun)
end
