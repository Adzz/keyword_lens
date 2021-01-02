defmodule KeywordLens.InvalidPathError do
  defexception message:
                 "a KeywordLens requires that each key in the path points " <>
                   "to a map until the last key in the path. It looks like your path is wrong, please check."
end
