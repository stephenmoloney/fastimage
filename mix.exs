defmodule Fastimage.Mixfile do
  use Mix.Project
  @name "Fastimage"
  @version "1.0.0-rc1"
  @source "https://github.com/stephenmoloney/fastimage"
  @maintainers ["Stephen Moloney"]
  @elixir_versions ">= 1.4.0"
  @allowed_hackney_versions ~w|1.6.0 1.7.0 1.8.0 1.9.0 1.10.0|
  @hackney_versions "~> " <> Enum.join(@allowed_hackney_versions, " or ~> ")

  def project do
    [
      app: :fastimage,
      name: @name,
      version: @version,
      source_url: @source,
      elixir: @elixir_versions,
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      preferred_cli_env: coveralls(),
      test_coverage: [
        tool: ExCoveralls
      ],
      description: description(),
      deps: deps(),
      package: package(),
      docs: docs(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp deps do
    [
      {:hackney, "== 1.10.1"},
      {:og, "~> 1.0"},

      # dev/test only
      {:excoveralls, "~> 0.8.0", only: [:test], runtime: false},
      {:benchfella, "~> 0.3", only: [:dev], runtime: false},
      {:credo, "~> 0.9.0-rc6", only: [:dev, :test], runtime: false},
      {:earmark, "~> 1.2", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.18", only: [:dev], runtime: false}
    ]
  end

  defp description do
    """
    #{@name} finds the dimensions/size or file type of a remote
    or local image file given the file path or uri respectively.
    """
  end

  defp package do
    %{
      licenses: ["MIT"],
      maintainers: @maintainers,
      links: %{"GitHub" => @source},
      files: ~w(priv bench/fastimage_bench.exs lib mix.exs README* LICENCE* CHANGELOG*)
    }
  end

  defp docs do
    [
      main: "api-reference"
    ]
  end

  defp aliases do
    [
      prep: ["clean", "format #{format_args()}", "compile", "credo #{credo_args()}"]
    ]
  end

  defp credo_args do
    "--strict --ignore maxlinelength,cyclomaticcomplexity,todo"
  end

  defp format_args do
    "mix.exs lib/**/*.{ex,exs}test/**/*.{ex,exs}"
  end

  def coveralls do
    [
      coveralls: :test,
      "coveralls.detail": :test,
      "coveralls.post": :test,
      "coveralls.html": :test
    ]
  end
end
