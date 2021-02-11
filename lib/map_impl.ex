defimpl KeywordLens, for: Map do
  @moduledoc """
  A map implementation of the KeywordLens protocol.
  """

  # Zip would be cool. Zip two subsets of maps together.
  # count is just the size of the path? So seems pointless. Long as the path is accurate
  # Reverse ? Filter ? reject ? contains? take ? is take just reduce ?
  # map_keys, map_value, map (which raises if you don't return a {key, value} pair?)

  @doc """
  Takes an element from left and an element from right and passes them to fun. Creates a new WHAT
  (list?) with the result of that function. The elements taken from left are determined by the left
  lens, and the elements taken from right are determined by right lens.

  ### Examples

      iex> left = %{a: %{b: 1}}
      ...> left_lens = [a: :b]
      ...> right = %{c: %{d: 2}}
      ...> right_lens = [c: :d]
      ...> zip_fn = fn left, right, acc -> [left + right| acc] end
      ...> zip_with_while(left, left_lens, right, right_lens, [], zip_fn)
      [3]
  """
  def zip_with_while(left, left_lens, right, right_lens, acc, fun) when is_function(fun, 2) do
    # ...
  end

  @doc """
  Maps until the mapping fun returns {:halt, term}, or until we reach the end of the data being
  mapped over. The mapping function must return {:cont, term} to continue to the next iteration.
  Returns data where each value pointed to by the KeywordLens has been replaced by the result
  of calling the fun with that value.
  """
  def map_while(data, keyword_lens, fun) do
    funn = fn {_key, value}, _acc -> fun.(value) end

    case lens_in_reduce(data, keyword_lens, {:cont, %{}}, funn) do
      {:done, {result, _}} -> result
      {:suspended, so_far, _continue} -> so_far
      {:halted, result} -> result
    end
  end

  @doc """
  Returns data where each value pointed to by the KeywordLens has been replaced by the result
  of calling the fun with that value.

  ### Examples

      iex> KeywordLens.map(%{a: %{b: 1}}, [a: :b], &(&1 + 1))
      %{a: %{b: 2}}
  """
  def map(data, keyword_lens, fun) do
    fun = fn {_key, value}, _acc -> {:cont, fun.(value)} end
    # Alternate implementation... except this isn't semantically the same as we can't cancel
    # early and we currently raise when we can't lens in, this returns nil.

    # KeywordLens.Helpers.expand(keyword_lens)
    # |> Enum.reduce(data, fn path, accum ->
    #   {_, res} = get_and_update_in(accum, path, &{&1, fun.(&1)})
    #   res
    # end)
    case lens_in_reduce(data, keyword_lens, {:cont, %{}}, fun) do
      {:done, {result, _}} -> result
    end
  end

  @doc """
  Calls the reducing function with the value pointed to by each of the lenses encoded within the
  keyword_lens.

  ### Examples

      iex> reducer = fn {key, value}, acc ->
      ...>   {:cont, Map.merge(acc, %{key => value + 1})}
      ...> end
      ...> KeywordLens.reduce_while(data, [:a, :b], %{}, reducer)
      %{a: 2, b: 3}

      iex> reducer = fn {_key, _value}, _acc ->
      ...>   {:halt, {:error, "Oh no!"}}
      ...> end
      ...> KeywordLens.reduce_while(data, [:a, :b], %{}, reducer)
      {:error, "Oh no!"}
  """
  def reduce_while(data, keyword_lens, accumulator, fun) do
    case lens_in_reduce(data, keyword_lens, {:cont, accumulator}, fun) do
      {:done, {_, result}} -> result
      {:suspended, so_far, _continue} -> so_far
      {:halted, result} -> result
    end
  end

  # Lens in reduce enforces that the reducer be wrapped in a tagged tuple
  # The same way Enumerable.reduce does. That allows us to mirror elixir core
  # in some ways. If we implement this for KeywordLens (maybe that's what the protocol is)
  # then we get a lot of the other enum funs for free.
  # The protocol probably also needs a map of some sort.

  def lens_in_reduce(_data, [], acc, _fun), do: acc

  def lens_in_reduce(data, paths, acc, fun) do
    unwrap_continue(acc, &lens_in_reduce(paths, [[]], data, %{}, &1, fun))
  end

  def lens_in_reduce({key, value}, [current | acc], data, data_rest, accu, fun)
      when is_list(value) do
    {fetched, remaining} = step_forward(data, key, data_rest)
    lens_in_reduce(value, [[key | current] | acc], fetched, remaining, accu, fun)
  end

  def lens_in_reduce({key, value = {_, _}}, [current | acc], data, data_rest, accu, fun) do
    {fetched, remaining} = step_forward(data, key, data_rest)
    lens_in_reduce(value, [[key | current] | acc], fetched, remaining, accu, fun)
  end

  def lens_in_reduce({key, value}, [acc | _], data, data_rest, accu, fun) do
    {fetched, remaining} = step_forward(data, key, data_rest)
    {fetched, remaining} = step_forward(fetched, value, remaining)

    continue = fn result ->
      backtrack_reduce([value, key | acc], [], result, remaining, result)
    end

    unwrap_continue(fun.({value, fetched}, accu), continue)
  end

  def lens_in_reduce([{key, value}], [current | acc], data, data_rest, accu, fun)
      when is_list(value) do
    {fetched, remaining} = step_forward(data, key, data_rest)
    lens_in_reduce(value, [[key | current] | acc], fetched, remaining, accu, fun)
  end

  def lens_in_reduce([{key, value = {_, _}}], [current | acc], data, data_rest, accu, fun) do
    {fetched, remaining} = step_forward(data, key, data_rest)
    lens_in_reduce(value, [[key | current] | acc], fetched, remaining, accu, fun)
  end

  def lens_in_reduce([{key, value}], [current | _], data, data_rest, accu, fun) do
    {fetched, remaining} = step_forward(data, key, data_rest)
    {fetched, remaining} = step_forward(fetched, value, remaining)

    continue = fn result ->
      backtrack_reduce([value, key | current], [], result, remaining, result)
    end

    unwrap_continue(fun.({value, fetched}, accu), continue)
  end

  def lens_in_reduce([key], [current | _], data, data_rest, acc, fun) do
    {fetched, remaining} = step_forward(data, key, data_rest)
    continue = &backtrack_reduce([key | current], [], &1, remaining, &1)
    unwrap_continue(fun.({key, fetched}, acc), continue)
  end

  def lens_in_reduce([{key, value} | next], [current | acc], data, data_rest, accu, fun) do
    {:done, {leg, accum}} =
      lens_in_reduce({key, value}, [current | acc], data, data_rest, accu, fun)

    data = Enum.reduce(Enum.reverse(current), leg, &Map.fetch!(&2, &1))
    lens_in_reduce(next, [current | [[value, key | current] | acc]], data, data_rest, accum, fun)
  end

  def lens_in_reduce([key | rest], [current | acc], data, data_rest, accu, fun) do
    {fetched, remaining} = step_forward(data, key, data_rest)

    continue = fn result ->
      {:done, {dataa, accum}} = backtrack_reduce([key | current], [], result, remaining, result)
      data = Enum.reduce(Enum.reverse(current), dataa, &Map.fetch!(&2, &1))
      lens_in_reduce(rest, [current | [[key | current] | acc]], data, data_rest, accum, fun)
    end

    unwrap_continue(fun.({key, fetched}, accu), continue)
  end

  def lens_in_reduce(key, [acc | _], data, data_rest, accu, fun) do
    {fetched, remaining} = step_forward(data, key, data_rest)
    continue = &backtrack_reduce([key | acc], [], &1, remaining, &1)
    unwrap_continue(fun.({key, fetched}, accu), continue)
  end

  def step_forward(data, key, data_rest \\ %{}) do
    fetched =
      try do
        # Do we fetch or get? Can we have an API to pick each one?
        # Map.get(data, key, %{})
        # Also what happens if we hit a node that isn't a map. Right now we just error
        # But that means we can't lens into this:
        # Whereas we could if we were to use the Keyword lens at... what each node ?
        # Really you need access. Then at each step you can say "do this to access the data structure"
        # Notice how we are essentially using two protocols then...But get_in and the like only
        # require one - Access.

        # So the thing we need implemented is how to access each node I guess.Then at each step
        # we can be like lens in like this, or error if it's not implemented. The extra tricky thing
        # is how to split the things when you lens in / out. Like how would that work for a tuple?
        # Need to implement for list to answer this.....
        # %{a: %{b: [c: :d]}}, [a: [b: :c]]
        # I guess this is why access exists.
        Map.fetch!(data, key)
      rescue
        BadMapError -> raise KeywordLens.InvalidPathError
      end

    remaining = %{key => data_rest} |> Map.merge(Map.delete(data, key))
    {fetched, remaining}
  end

  defp backtrack_reduce([], _visited, data, data_rest, acc) do
    {:done, {Map.merge(data, data_rest), acc}}
  end

  defp backtrack_reduce([key | rest], visited, data, data_rest, acc) do
    # This enforces that we do map values.... How do we make it so we can change the key?
    # We have to enforce the return type of the reducer / mapping fn to be a tuple of key / value
    # when mapping a map..... which ergh. For now it's a map_values I guess.
    data = Map.merge(Map.delete(data_rest, key), %{key => data})
    backtrack_reduce(rest, [key | visited], data, Map.fetch!(data_rest, key), acc)
  end

  defp unwrap_continue({:cont, acc}, continue), do: continue.(acc)
  defp unwrap_continue({:halt, acc}, _continue), do: {:halted, acc}

  defp unwrap_continue({:suspend, acc}, continue) do
    {:suspended, acc, &unwrap_continue(&1, continue)}
  end

  defp unwrap_continue(_, _continue), do: raise(KeywordLens.InvalidReducingFunctionError)
end
