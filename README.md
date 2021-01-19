# KeywordLens

A keyword lens is a nested keyword-like structure used to describe paths into certain data types. It is similar to the list you can provide to Ecto's Repo.preload/2

You can describe a KeywordLens like this:
```elixir
[a: :b, c: [d: :e]]
```

Such a list is handy for describing subsets of nested data structures. For example, you can imagine the following KeywordLens: `[a: :b]` applied to this map: `%{a: %{b: 1}}` points to the value `1`. In contrast this KeywordLens: `[:a, :b]` applied to this map `%{a: 1, b: 2}` points to both values `1` and `2`.

It's not a proper Keyword list because we allow any key for convenience, so these are valid:

```elixir
[{"a", :b}]
[a: [{"b", [c: :d]}]
[{%{}, :b}]
[{1, {2, 3}}]
```

One KeywordLens can point to many different values inside a given data structure.

Here are some examples of different KeywordLenses and the unique set of lenses they represent.

```elixir
keyword_lens = [a: :b]
lenses = [[:a], [:b]]

keyword_lens = [a: [b: [:c, :d]]]
lenses = [[:a, :b, :c], [:a, :b, :d]]

keyword_lens = [a: [:z, b: [:c, d: :e]]]
lenses = [[:a, :z], [:a, :b, :c], [:a, :b, :d, :e]]

keyword_lens = [:a, "b", :c]
lenses = [[:a], ["b"], [:c]]
```

You can use `KeywordLens.Helpers.expand/1` to see which unique lenses are encoded in a given KeywordLens.

```elixir
KeywordLens.Helpers.expand([a: :b])
[[:a, :b]]

KeywordLens.Helpers.expand([a: [b: [:c, :d]]])
[[:a, :b, :c], [:a, :b, :d]]
```

This library provides a protocol you can implement for your own data structures and structs. We provide a map implementation to get started.

### Examples

```elixir
KeywordLens.map(%{a: %{b: 1}}, [a: :b], &(&1 + 1))
%{a: %{b: 2}}
```

### Can't I just use get_in / update_in

You could, but the syntax becomes a bit verbose and repetitive:

```elixir
(
  %{a: %{b: 1}, c: %{d: 1, e: 1}}
  |> update_in([:a, :b], & &1 + 1)
  |> update_in([:c, :d], & &1 + 1)
  |> update_in([:c, :e], & &1 + 1)
)
%{a: %{b: 2}, c: %{d: 2, e: 2}}

# Vs

KeywordLens.map(%{a: %{b: 1}, c: %{d: 1, e: 1}}, [a: :b, c: [:d, :e]], & &1+1)
%{a: %{b: 2}, c: %{d: 2, e: 2}}
```

Additionally `get_in` will return nil if you provide a path that doesn't point to a value:

```elixir
Kernel.get_in(%{}, [:a])
nil
```

This can be fine, but can make it tricky to distinguish between "the path you gave me doesn't point to a value" and "the path you gave me points to a value, and that value is nil":

```elixir
Kernel.get_in(%{}, [:a])
nil

Kernel.get_in(%{a: nil}, [:a])
nil
```

That might not matter to you. KeywordLens takes the following approach for now:

```elixir
KeywordLens.map(%{}, [:a], & &1)
** (KeyError) key :a not found in: %{}

KeywordLens.map(%{a: nil}, [:a], & &1)
%{a: nil}

KeywordLens.map(%{a: 1}, [a: :b], & &1)
** (KeywordLens.InvalidPathError) a KeywordLens requires that each key in the path points to a map until the last key in the path. It looks like your path is wrong, please check.
```

What's nice about this is you get a slightly clearer error message than what `get_in` can provide if you use an incorrect path. You can think of `KeywordLens.map` as being a `fetch!_and_update_in`.

For now, if you want to use the compact KeywordLens notation, but have the semantics of `get_and_update_in` you can do this:

```elixir
(
  data = %{a: %{b: 1}, c: %{d: 1, e: 1}}
  KeywordLens.Helpers.expand([a: :b, c: [:d, :e]])
  |> Enum.reduce(data, fn path, acc ->
    {_, result} = get_and_update_in(acc, path, &({&1, &1 + 1}))
    result
  end)
)
```

### Aside what is a zipper?

It's a way of traversing a structure without losing the parts you have visited, meaning you can step back or forwards through the traversal trivially. Let's take a list as an example
```
[1, 2, 3, 4, 5]
```
As we step through this we could break it into two halves, one side would have the nodes we haven't seen the other the ones we have:
```
unseen = [2, 3, 4, 5]; seen = [1]
```
Stepping forward is about taking the head of unseen and putting it on the head of seen:
```
unseen = [3, 4, 5]; seen = [2, 1]
unseen = [4, 5]; seen = [3, 2, 1]
```
Stepping backwards is the reverse:
```
unseen = [2, 3, 4, 5]; seen = [1]
unseen = [1, 2, 3, 4, 5]; seen = []
```

Internally we iterate through the nested data structures in this way.

TODO: expand this explanation.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `keyword_lens` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:keyword_lens, "~> 0.1.1"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/keyword_lens](https://hexdocs.pm/keyword_lens).

