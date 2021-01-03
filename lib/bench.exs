# this creates some nested Keyword Lists which we will use as our Keyword Lenses. The more
# |> StreamData.keyword_of() we add the deeper the nesting. A bit manual,
# we could randomize it I suppose.
generated_lists =
  StreamData.integer()
  |> StreamData.keyword_of()
  |> StreamData.keyword_of()
  |> StreamData.keyword_of()
  |> Enum.take(10)

# generated_lists = [[a: :b], [c: :d]]

# This expands the the KeywordLenses created above so we can autovivificate below
generated_list = generated_lists |> Enum.map(&KeywordLens.Helpers.expand/1)
# This autovivificates essentially creating a map that will have the paths created above within
# it.
map =
  Enum.reduce(generated_list, %{}, fn p, acc ->
    Map.merge(
      acc,
      Enum.reduce(p, %{}, fn z, accum -> put_in(accum, Enum.map(z, &Access.key(&1, %{})), 42) end)
    )
  end)

Benchee.run(%{
  "3 deep KeywordLens.map/3" => fn ->
    Enum.reduce(generated_lists, map, fn lens, acc ->
      Map.merge(acc, KeywordLens.map(acc, lens, &(&1 * 2)))
    end)
  end,
  "3 deep put_in" => fn ->
    Enum.reduce(generated_lists, map, fn lens, acc ->
      KeywordLens.Helpers.expand(lens) |> Enum.reduce(acc, fn path, accum ->
        {_, res} = get_and_update_in(accum, path, &{&1, &1 * 2})
        Map.merge(accum, res)
      end)
    end)
  end
})
