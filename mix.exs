defmodule Fastimage.Mixfile do
  use Mix.Project
  @name "Fastimage"
  @version "0.0.1"
  @source "https://github.com/stephenmoloney/fastimage"
  @maintainers ["Stephen Moloney"]

  def project do
    [
    app: :fastimage,
    name: @name,
    version: @version,
    source_url: @source,
    elixir: "~> 1.2",
    build_embedded: Mix.env == :prod,
    start_permanent: Mix.env == :prod,
    description: description(),
    deps: deps(),
    package: package(),
    docs: docs()
    ]
  end

  def application do
    [
    applications: [:logger, :hackney]
    ]
  end

  defp deps do
    [
    {:hackney, "~> 1.6"},
    {:benchfella, "~> 0.3.0", only: [:dev]},
    {:earmark, "~> 1.0", only: :dev},
    {:ex_doc, "~> 0.13", only: :dev}
    ]
  end


  defp description() do
    @name <> " finds the dimensions/size or file type of a remote or local image file given the file path or uri respectively."
  end

  defp package() do
    %{
      licenses: ["MIT"],
      maintainers: @maintainers,
      links: %{ "GitHub" => @source},
      files: ~w(priv bench lib mix.exs README* LICENCE* CHANGELOG*)
     }
  end

  defp docs() do
    [
    main: "api-reference"
    ]
  end


end
