defprotocol KeywordLens do
  # Kernel.def test do
  # end

  @doc """
  Takes an element from left and an element from right and passes them to fun. Creates a new WHAT
  (list?) with the result of that function. The elements taken from left are determined by the left
  lens, and the elements taken from right are determined by right lens.

  ### Examples

      iex> left = %{a: %{b: 1}}
      ...> left_lens = [a: :b]
      ...> right = %{c: %{d: 2}}
      ...> right_lens = [c: :d]
      ...> zip_fn = fn [left, right], acc -> [left + right| acc] end
      ...> KeywordLens.zip_with_while(left, left_lens, right, right_lens, [], zip_fn)
      [3]
  """
  Kernel.def zip_with_while(left, left_lens, right, right_lens, acc, fun)
             when is_function(fun, 2) do
    step = fn x, _acc -> {:suspend, x |> IO.inspect(limit: :infinity, label: "x")} end
    af = &KeywordLens.lens_in_reduce(left, left_lens, &1, step)
    bf = &KeywordLens.lens_in_reduce(right, right_lens, &1, step)
    do_zip(af, bf, acc, fun)
  end

  Kernel.defp do_zip(left, right, acc, fun) do
    "HI do zip" |> IO.inspect(limit: :infinity, label: "")

    case left.({:cont, :ignored}) do
      {:suspended, left_next, left_continue} ->
        case right.({:cont, :ignored}) do
          {:suspended, right_next, right_continue} ->
            unwrap_continue(
              fun.(
                [
                  left_next |> IO.inspect(limit: :infinity, label: "L"),
                  right_next |> IO.inspect(limit: :infinity, label: "R")
                ],
                acc
              )
              |> IO.inspect(limit: :infinity, label: "FUNNNNNNNN"),
              &do_zip(left_continue, right_continue, &1, fun)
            )
        end

      # {:halted, _} ->
      #   acc

      {:done, stuff} ->
        stuff |> IO.inspect(limit: :infinity, label: "stuff")
        acc
    end
    |> IO.inspect(limit: :infinity, label: "unwrap")
  end

  Kernel.defp(unwrap_continue({:cont, acc}, continue), do: continue.(acc))
  Kernel.defp(unwrap_continue({:halt, acc}, _continue), do: {:halted, acc})

  Kernel.defp unwrap_continue({:suspend, acc}, continue) do
    {:suspended, acc, &unwrap_continue(&1, continue)}
  end

  Kernel.defp(unwrap_continue(_, _continue), do: raise(KeywordLens.InvalidReducingFunctionError))

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
  # def reduce(data, keyword_lens, acc, fun)
  # If we implement this correctly we get some funs for free
  # not map though.
  def lens_in_reduce(data, keyword_lens, acc, reducer)
  # Both need to be maps really (for map impl)
  # def zip_with_while(data, data_2, keyword_lens, fun)
  # def zip_while(data, data_2, keyword_lens, acc, fun)
end
