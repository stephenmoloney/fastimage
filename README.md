# Fastimage [![Hex Version](http://img.shields.io/hexpm/v/fastimage.svg?style=flat-square)](https://hex.pm/packages/fastimage) [![Hex docs](http://img.shields.io/badge/hex.pm-docs-green.svg?style=flat-square)](https://hexdocs.pm/fastimage) [![License](https://img.shields.io/hexpm/l/fastimage.svg?style=flat-square)](https://github.com/stephenmoloney/fastimage/blob/master/LICENSE.md) [![Build Status](https://travis-ci.org/stephenmoloney/fastimage.svg)](https://travis-ci.org/stephenmoloney/fastimage) [![Code coverage status](https://coveralls.io/repos/github/stephenmoloney/fastimage/badge.svg?branch=master)](https://coveralls.io/github/stephenmoloney/fastimage?branch=master)

## Description

Fastimage finds the dimensions/size or file type of a remote or local image file given the file path or uri respectively.
It streams the smallest amount of data necessary to ascertain the file size. This aspect is useful when getting the
file size for very large images.

## Features

- Supports `bmp`, `jpeg`, `png` and `gif` files
- Supports local files by using the file path of the image
- Supports blobs/objects by using the binary of the image
- Supports remote files by using the uri of the image
- Follows up to three redirects for a given uri
- Yields the file size as a struct `%Fastimage.Dimensions{width: _w, height: _h}`
- Yields the file type as an atom `:bmp, :jpeg, :gif or :png`

## Examples

```elixir
Fastimage.type("https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv/test.jpg")
# => {:ok, :jpeg}

Fastimage.type!("https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv/test.jpg")
# => :jpeg

Fastimage.size("https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv/test.jpg")
# => {:ok, %Fastimage.Dimensions{height: 142, width: 283}}

Fastimage.size!("https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv/test.jpg")
# => %Fastimage.Dimensions{height: 142, width: 283}
```

## Installation

Add fastimage to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:fastimage, "~> 1.0.0-rc1"}
  ]
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