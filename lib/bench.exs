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

generated_lists_xl =
  StreamData.integer()
  |> StreamData.keyword_of()
  |> StreamData.keyword_of()
  # |> StreamData.keyword_of()
  |> Enum.take(100)

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
          Map.merge(accum, res)
        end)
      end)
    end,
    "3 deep KeywordLens.map/3" => fn {map, generated_lists} ->
      Enum.reduce(generated_lists, map, fn lens, acc ->
        Map.merge(acc, KeywordLens.map(acc, lens, &(&1 * 2)))
      end)
    end,
    "3 deep get_in then put_in" => fn {map, generated_lists} ->
      Enum.reduce(generated_lists, map, fn lens, acc ->
        KeywordLens.Helpers.expand(lens)
        |> Enum.reduce(acc, fn path, accum ->
          value = get_in(accum, path)
          Map.merge(accum, put_in(accum, path, value * 2))
        end)
      end)
    end
  },
  inputs: inputs,
  memory_time: 2
)

### Results / Notes

# If we use a large list (i.e. lots of paths) KeywordLens is much quicker which makes sense
# because I think it does less work. It does use significantly more mems though.

# On a smaller list it was similar / split the two implementations pretty regularly.

# On a deeper maps it's the same.

# Operating System: macOS
# CPU Information: Intel(R) Core(TM) i7-4850HQ CPU @ 2.30GHz
# Number of Available Cores: 8
# Available memory: 16 GB
# Elixir 1.11.1
# Erlang 23.1.1

# Benchmark suite executing with the following configuration:
# warmup: 2 s
# time: 5 s
# memory time: 2 s
# parallel: 1
# inputs: large list
# Estimated total run time: 27 s

# Benchmarking 3 deep KeywordLens.map/3 with input large list...
# Benchmarking 3 deep get_and_update_in with input large list...
# Benchmarking 3 deep get_in then put_in with input large list...

# ##### With input large list #####
# Name                                ips        average  deviation         median         99th %
# 3 deep KeywordLens.map/3           6.35        0.158 s     ±9.94%        0.152 s         0.20 s
# 3 deep get_and_update_in           0.45         2.25 s     ±1.52%         2.24 s         2.28 s
# 3 deep get_in then put_in          0.44         2.26 s     ±1.00%         2.27 s         2.28 s

# Comparison:
# 3 deep KeywordLens.map/3           6.35
# 3 deep get_and_update_in           0.45 - 14.26x slower +2.09 s
# 3 deep get_in then put_in          0.44 - 14.36x slower +2.11 s

# Memory usage statistics:

# Name                         Memory usage
# 3 deep KeywordLens.map/3        198.84 MB
# 3 deep get_and_update_in         93.49 MB - 0.47x memory usage -105.35484 MB
# 3 deep get_in then put_in        98.44 MB - 0.50x memory usage -100.40558 MB

# **All measurements for memory usage were the same**
