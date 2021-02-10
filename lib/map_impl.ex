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
      ...> zip_with_while(left, left_lens, right, right_lens, fn left, right -> left + right end)
      [3]
  """
  def zip_with_while(left, left_lens, right, right_lens, acc, fun) when is_function(fun, 2) do
    # If we have an acc then we can build up any data structure that we like as we go.

    # We need to know how to consume a value from left and right. Well that is step_forward
    # plus the pattern matching. but... like how do we weave the fun down. Callback doesn't sound chill
    # because in this case we need different args passed to it?

    # Essentially we need a take_while first, so we can take an element from one, suspend that
    # take the next element from the second and continue until either has expired their paths.
    # each time call the reducer with all the values in.
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
    # THERE ARE TWO OPTIONS HERE WE NEED TO BENCHMARK
    # 1. do lens_in but at the end of the paths call the fun with acc.
    # 2. Expand paths and then do the work.
    # If we get the expanding of paths working this is an alternative approach to benchmark
    # against:
    # Enum.reduce_while(keyword_lens, accumulator, fn lens, acc ->
    # paths = KeywordLens.Helpers.expand(lens)
    # result =
    #   Enum.reduce_while(paths, acc, fn path, accum ->
    #     lens_in_while(path, [], data, accum, %{}, fun)
    #   end)
    # {:cont, result}
    # end)

    # defp lens_in_while([], [key | _], data, accumulator, _data_rest, fun) do
    #   fun.({key, data}, accumulator)
    # end

    # defp lens_in_while([key | rest], visited, data, accumulator, data_rest, fun)
    #      when is_map(data) do
    #   fetched = Map.fetch!(data, key)
    #   remaining = %{key => data_rest} |> Map.merge(Map.delete(data, key))
    #   lens_in_while(rest, [key | visited], fetched, accumulator, remaining, fun)
    # end
    case lens_in_reduce(data, keyword_lens, {:cont, accumulator}, fun) do
      {:done, {_, result}} -> result
      {:suspended, so_far, continue} -> so_far
      {:halt, result} -> result
    end
  end

  # Lens in reduce enforces that the reducer be wrapped in a tagged tuple
  # The same way Enumerable.reduce does. That allows us to mirror elixir core
  # in some ways. If we implement this for KeywordLens (maybe that's what the protocol is)
  # then we get a lot of the other enum funs for free.
  # The protocol probably also needs a map of some sort.

  def lens_in_reduce(data, [], acc, fun), do: acc

  def lens_in_reduce(data, paths, acc, fun) do
    unwrap_continue(acc, &lens_in_reduce(paths, [[]], data, %{}, &1, fun))
  end

  def lens_in_reduce(data, paths, acc, fun) do
    lens_in_reduce(paths, [[]], data, %{}, acc, fun)
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

  defp backtrack_reduce([], _visited, data, data_rest, acc) do
    {:done, {Map.merge(data, data_rest), acc}}
  end

  defp backtrack_reduce([key | rest], visited, data, data_rest, acc) do
    data = Map.merge(Map.delete(data_rest, key), %{key => data})
    backtrack_reduce(rest, [key | visited], data, Map.fetch!(data_rest, key), acc)
  end

  defp unwrap_continue({:cont, acc}, continue), do: continue.(acc)
  defp unwrap_continue({:halt, acc}, _continue), do: {:halted, acc}

  defp unwrap_continue({:suspend, acc}, continue) do
    {:suspended, acc, &unwrap_continue(&1, continue)}
  end

  defp unwrap_continue(_, _continue), do: raise(KeywordLens.InvalidReducingFunctionError)

  @doc """
  Maps until the mapping fun returns {:halt, term}, or until we reach the end of the data being
  mapped over. The mapping function must return {:cont, term} to continue to the next iteration.
  Returns data where each value pointed to by the KeywordLens has been replaced by the result
  of calling the fun with that value.
  """
  def map_while(data, keyword_lens, fun) do
    case lens_in(keyword_lens, data, fun) do
      {:cont, result} -> result
      {:halt, result} -> result
    end
  end

  @doc """
  Returns data where each value pointed to by the KeywordLens has been replaced by the result
  of calling the fun with that value.

  ### Examples

      iex> KeywordLens.map(%{a: %{b: 1}}, [a: :b], &(&1 + 1))
      %{a: %{b: 2}}
  """
  # Is this really map_values
  # map would follow elixir convention of returning list... That would mean we need to do an into
  # But would allow us to map keys. Or we could add a map_keys function. The issue would be
  # you now need to map twice to change the key and value... Maybe that's not bad.
  # probably no worse than an into though.... But can get tricky.

  # We could instead error if the mapping function doesn't return a tuple - especially given
  # that we know we are mapping a map... However I don't know how that changes when we introduce
  # other impls, like a list.

  # In fact what happens then. Do we automatically dispatch to the
  # This is why there is Access. Then instead of Map.get, we could Access

  # We can't expand then map values if we want to give a different error message than
  # invalid map - which I sort of feel like we do (to make things clearer). The tradeoff
  # is that it's slower. HOWEVER, users could do it themselves maybe ?
  def map(data, keyword_lens, fun) do
    fun = fn value -> {:cont, fun.(value)} end
    # KeywordLens.Helpers.expand(keyword_lens)
    # |> Enum.reduce(data, fn path, accum ->
    #   {_, res} = get_and_update_in(accum, path, &{&1, fun.(&1)})
    #   res
    # end)
    {:cont, result} = lens_in(keyword_lens, data, fun)
    result
  end

  defp lens_in(paths, data, fun) do
    lens_in(paths, [[]], data, %{}, fun)
  end

  defp lens_in({key, value}, [current | acc], data, data_rest, fun) when is_list(value) do
    {fetched, remaining} = step_forward(data, key, data_rest)
    lens_in(value, [[key | current] | acc], fetched, remaining, fun)
  end

  defp lens_in({key, value = {_, _}}, [current | acc], data, data_rest, fun) do
    {fetched, remaining} = step_forward(data, key, data_rest)
    lens_in(value, [[key | current] | acc], fetched, remaining, fun)
  end

  defp lens_in({key, value}, [acc | _], data, data_rest, fun) do
    {fetched, remaining} = step_forward(data, key, data_rest)
    {fetched, remaining} = step_forward(fetched, value, remaining)

    case fun.(fetched) do
      {:cont, result} -> backtrack([value, key | acc], [], result, remaining)
      halt = {:halt, _} -> halt
      _ -> raise KeywordLens.InvalidReducingFunctionError
    end
  end

  defp lens_in([{key, value}], [current | acc], data, data_rest, fun) when is_list(value) do
    {fetched, remaining} = step_forward(data, key, data_rest)
    lens_in(value, [[key | current] | acc], fetched, remaining, fun)
  end

  defp lens_in([{key, value = {_, _}}], [current | acc], data, data_rest, fun) do
    {fetched, remaining} = step_forward(data, key, data_rest)
    lens_in(value, [[key | current] | acc], fetched, remaining, fun)
  end

  defp lens_in([{key, value}], [current | _], data, data_rest, fun) do
    {fetched, remaining} = step_forward(data, key, data_rest)
    {fetched, remaining} = step_forward(fetched, value, remaining)

    case fun.(fetched) do
      {:cont, result} -> backtrack([value, key | current], [], result, remaining)
      halt = {:halt, _} -> halt
      _ -> raise KeywordLens.InvalidReducingFunctionError
    end
  end

  defp lens_in([key], [current | _], data, data_rest, fun) do
    {fetched, remaining} = step_forward(data, key, data_rest)

    case fun.(fetched) do
      {:cont, result} -> backtrack([key | current], [], result, remaining)
      halt = {:halt, _} -> halt
      _ -> raise KeywordLens.InvalidReducingFunctionError
    end
  end

  defp lens_in([{key, value} | next], [current | acc], data, data_rest, fun) do
    {:cont, leg} = lens_in({key, value}, [current | acc], data, data_rest, fun)
    data = Enum.reduce(Enum.reverse(current), leg, fn key, acc -> Map.fetch!(acc, key) end)
    lens_in(next, [current | [[value, key | current] | acc]], data, data_rest, fun)
  end

  defp lens_in([key | rest], [current | acc], data, data_rest, fun) do
    {fetched, remaining} = step_forward(data, key, data_rest)

    with {:cont, result} <- fun.(fetched),
         {:cont, dataa} <- backtrack([key | current], [], result, remaining) do
      data = Enum.reduce(Enum.reverse(current), dataa, fn key, acc -> Map.fetch!(acc, key) end)
      lens_in(rest, [current | [[key | current] | acc]], data, data_rest, fun)
    else
      halt = {:halt, _} -> halt
      _ -> raise KeywordLens.InvalidReducingFunctionError
    end
  end

  defp lens_in(key, [acc | _], data, data_rest, fun) do
    {fetched, remaining} = step_forward(data, key, data_rest)

    case fun.(fetched) do
      {:cont, result} -> backtrack([key | acc], [], result, remaining)
      halt = {:halt, _} -> halt
      _ -> raise KeywordLens.InvalidReducingFunctionError
    end
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

  defp backtrack([], _visited, data, data_rest), do: {:cont, Map.merge(data, data_rest)}

  defp backtrack([key | rest], visited, data, data_rest) do
    data = Map.merge(Map.delete(data_rest, key), %{key => data})
    backtrack(rest, [key | visited], data, Map.fetch!(data_rest, key))
  end
end
