# this creates some nested Keyword Lists which we will use as our Keyword Lenses. The more
# |> StreamData.keyword_of() we add the deeper the nesting. A bit manual,
# we could randomize it I suppose.
# generated_lists_l =
#   StreamData.integer()
#   |> StreamData.keyword_of()
#   |> StreamData.keyword_of()
#   |> StreamData.keyword_of()
#   |> Enum.take(1)

# generated_lists_s =
#   StreamData.integer()
#   |> StreamData.keyword_of()
#   |> StreamData.keyword_of()
#   |> StreamData.keyword_of()
#   |> Enum.take(1)

generated_lists_xl = StreamData.integer() |> StreamData.keyword_of() |> Enum.take(1000)

# This expands the the KeywordLenses created above so we can autovivificate below
# generated_list_l = generated_lists_l |> Enum.map(&KeywordLens.Helpers.expand/1)
generated_list_xl = generated_lists_xl |> Enum.map(&KeywordLens.Helpers.expand/1)
# generated_list_s = generated_lists_s |> Enum.map(&KeywordLens.Helpers.expand/1)

default = fn ->
  hd(Enum.take(StreamData.map_of(StreamData.integer(), StreamData.integer()), 1))
end

# map_l =
#   Enum.reduce(generated_list_l, %{}, fn p, acc ->
#     Map.merge(
#       acc,
#       Enum.reduce(p, acc, fn z, accum ->
#         # This autovivificates - essentially creating a map that will have the paths generated
#         # above in it. It will also have extra keys from the default map.
#         put_in(accum, Enum.map(z, &Access.key(&1, default.())), 42)
#       end)
#     )
#   end)

map_xl =
  Enum.reduce(generated_list_xl, %{}, fn p, acc ->
    Map.merge(
      acc,
      Enum.reduce(p, acc, fn z, accum ->
        # This autovivificates - essentially creating a map that will have the paths generated
        # above in it. It will also have extra keys from the default map.
        put_in(accum, Enum.map(z, &Access.key(&1, default.())), 42)
      end)
    )
  end)

# map_s =
#   Enum.reduce(generated_list_s, %{}, fn p, acc ->
#     Map.merge(
#       acc,
#       Enum.reduce(p, acc, fn z, accum ->
#         # This autovivificates - essentially creating a map that will have the paths generated
#         # above in it. It will also have extra keys from the default map.
#         put_in(accum, Enum.map(z, &Access.key(&1, default.())), 42)
#       end)
#     )
#   end)

inputs = %{
  # "small list" => {map_s, generated_lists_s},
  # "medium list" => {map_l, generated_lists_l},
  "large list" => {map_xl, generated_lists_xl}
}

Benchee.run(
  %{
    "3 deep get_and_update_in" => fn {map, generated_lists} ->
      Enum.reduce(generated_lists, map, fn lens, acc ->
        KeywordLens.Helpers.expand(lens)
        |> Enum.reduce(acc, fn path, accum ->
          {_, res} = get_and_update_in(accum, path, &{&1, &1 * 2})
          res
        end)
      end)
    end,
    "3 deep KeywordLens.map/3" => fn {map, generated_lists} ->
      Enum.reduce(generated_lists, map, fn lens, acc ->
        KeywordLens.map(acc, lens, &(&1 * 2))
      end)
    end,
    "3 deep get_in then put_in" => fn {map, generated_lists} ->
      Enum.reduce(generated_lists, map, fn lens, acc ->
        KeywordLens.Helpers.expand(lens)
        |> Enum.reduce(acc, fn path, accum ->
          value = get_in(accum, path)
          put_in(accum, path, value * 2)
        end)
      end)
    end
  },
  inputs: inputs,
  memory_time: 2
)

### Results / Notes

# Seems like expanding then get_and_update_in is quickest. So we should use that for
# non cancelable functions. Map should expand / get / upate_in. map_while should zipper
# as I don't think you can cancel a traversal for get_in.
