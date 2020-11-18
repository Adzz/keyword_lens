defmodule KeywordLens.InvalidReducingFunctionError do
  defexception message: "The reducing function should return {:cont, term} or {:halt, term}"
end
