# Changelog

## v1.0.0-rc2

[changes]

- remove og dep, forgot to remove it.

## v1.0.0-rc1

[breaking changes]
- `type/1` and `type!/1` functions now return the image types as 
atoms instead of `String.t()`. image_types = `:bmp | :gif | :jpeg | :png`
- `size/1` returns `{:ok, Fastimage.Dimensions.t()}` whereas 
before it returned `map()`. To achieve the same behaviour as before, now
`size!/1` is now available.
- `type/1` returns `{:ok, result}` whereas 
before it returned `result`. To achieve the same behaviour as before, now
`type!/1` is now available.
- add options to `type/2`, `size/2` and `info/2` as a second argument 
to allow manual overrides on the otherwise hard-coded values 
for `stream_timeout`, `max_redirect_retries` and `max_error_retries`

[changes]
- Separate the parser functions into their own module.
- Separate Stream into into own module and create a `%Stream.Acc{}` to
bring structured format to the stream processing entity.
- Simplify points of implementation of `Utils.close_stream/1`

[bug fixes]
- `close_stream` bug fixed where `:hackney` streams were not properly closed. 

[enhancements]
- Introduce `Fastimage.info/1` function that gets the type and size in a 
single streaming pass and return a `Fastimage` struct with various infos.
- Added ability to get size and type for binaries
- Added Fastimage.Error exception structs for improved error handling
- Improved readme

## v0.0.7

[bug fixes]
- Fix for [issue #9](https://github.com/stephenmoloney/fastimage/issues/9)

[changes]
- remove dependency on [Og](https://hex.pm/packages/og)


## v0.0.6

- Remove compile warnings.


## v0.0.5

- Allow up to 5 retry attempts to stream the url in the event of a timeout (enhancement/bug fix)


## v0.0.4

- Follow up to three redirects for image files
- Increase timeout for `test "Get the size of multiple image files asynchronously"` from `5000` -> `10000`


## v0.0.3

- Remove warning messages


## v0.0.2

- Change client from `:gun` to `:hackney`.
- Add more extensive tests.


## v0.0.1

- Initial release.