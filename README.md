# Fastimage [![Build Status](https://travis-ci.org/stephenmoloney/fastimage.svg)](https://travis-ci.org/stephenmoloney/fastimage) [![Hex Version](http://img.shields.io/hexpm/v/fastimage.svg?style=flat)](https://hex.pm/packages/fastimage) [![Hex docs](http://img.shields.io/badge/hex.pm-docs-green.svg?style=flat)](https://hexdocs.pm/fastimage)


## Description

Fastimage finds the dimensions/size or file type of a remote or local image file given the file path or uri respectively.
It streams the smallest amount of data necessary to ascertain the file size. This aspect is useful when getting the
file size for very large images.



## Features

- Supports `bmp`, `jpeg`, `png` and `gif` files
- Supports remote files by using the uri of the image
- Follows up to three redirects for a given uri
- Supports local files by using the file path of the image
- Yields the file size as a map `%{width: _w, height: _h}`
- Yields the file type as a string `"bmp", "jpeg", "gif" or "png"`


## Examples

```elixir
Fastimage.type("https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv/test.jpg")
# => "jpeg"
Fastimage.size("https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv/test.jpg")
# => %{height: 142, width: 283}
```


## Installation

Add fastimage to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:fastimage, "~> 0.0.5"}]
end
```

Ensure fastimage is started before your application:

```elixir
def application do
  [applications: [:fastimage]]
end
```


## Tests

```elixir
mix test
```


## Credit/Acknowledgements

- Based on [Ruby Fastimage](https://github.com/sdsykes/fastimage) by [Stephen Sykes](https://github.com/sdsykes)
- Influenced by a [PHP version of fastimage](https://github.com/tommoor/fastimage) by [Tom Moor](https://github.com/tommoor)


## Licence

[MIT Licence](LICENCE.md)