defmodule KeywordLens.MixProject do
  use Mix.Project

  def project do
    [
      app: :keyword_lens,
      version: "0.1.1",
      elixir: "~> 1.9",
      description: description(),
      package: package(),
      start_permanent: Mix.env() == :prod,
      source_url: "https://github.com/Adzz/keyword_lens",
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:benchee, "~> 1.0", only: :dev},
      {:stream_data, "~> 0.5", only: [:test, :dev]}
    ]
  end

  defp description(), do: "A utility for working with nested data structures"

  defp package() do
    [
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/Adzz/keyword_lens"}
    ]
  end
end
