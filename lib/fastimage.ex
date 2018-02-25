defmodule Fastimage do
  @moduledoc false
  alias __MODULE__
  alias Fastimage.{Dimensions, Error, Parser, Stream, Utils}

  @type image_type :: :bmp | :gif | :jpeg | :png
  @type source_type :: :url | :file | :binary

  defstruct source: nil,
            source_type: nil,
            image_type: nil,
            dimensions: %Dimensions{}

  @type t :: %Fastimage{
               source: binary() | nil,
               source_type: source_type() | nil,
               image_type: image_type() | nil,
               dimensions: Dimensions.t()
             }

  @doc ~S"""
  Returns the type of image. Accepts a source as a url, binary
  object or file path.

  Supports ".bmp", ".gif", ".jpeg" or ".png" image types only.

  ## Options

    * `:stream_timeout` - An override for the after `:stream_timeout` field
    in the `Fastimage.Stream.Acc` struct which in turn determines the timeout in the
    processing of the hackney stream. By default the @default_stream_timeout
    is used in `Fastimage.Stream.Acc`.

    * `:max_error_retries` - An override for the `:max_error_retries` field
    in the `Fastimage.Stream.Acc` struct which in turn determines the maximum number
    of retries that will be attempted before giving up and returning an error.
    By default the @default_max_error_retries is used in `Fastimage.Stream.Acc`.

    * `:max_redirect_retries` - An override for the `:max_redirect_retries` field
    in the `Fastimage.Stream.Acc` struct which in turn determines the maximum number
    of redirects that will be attempted before giving up and returning an error.
    By default the @default_max_redirect_retries is used in `Fastimage.Stream.Acc`.

  ## Example

      iex> Fastimage.type("https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv/test.jpg")
      {:ok, :jpeg}

  """
  @spec type(binary()) :: {:ok, image_type()} | {:error, Error.t()}
  def type(source, opts \\ []) when is_binary(source) do
    case Utils.get_source_type(source) do
      :other ->
        {:error, %Error{reason: :invalid_input}}
     source_type ->
        {:ok, %Stream.Acc{image_type: type, stream_ref: stream_ref}} = get_acc_with_type(source, source_type, opts)
        Utils.close_stream(stream_ref)
        {:ok, type}
    end
  end

  @doc ~S"""
  Returns the type of image. Accepts a source as a url, binary
  object or file path.

  Supports ".bmp", ".gif", ".jpeg" or ".png" image types only.

  ## Options - see `type/1`

  ## Example

      iex> Fastimage.type!("https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv/test.jpg")
      :jpeg

  """
  @spec type!(binary()) :: image_type() | no_return()
  def type!(source, opts \\ []) when is_binary(source) do
    case type(source, opts) do
      {:ok, type} -> type
      {:error, %Error{} = error} -> raise(error)
      {:error, reason} -> raise(Error, reason)
    end
  end

  @doc """
  Returns a `%Fastimage{}` struct with information such as
  type and dimensions. Accepts a source as a url, binary
  object or file path.

  Supports ".bmp", ".gif", ".jpeg" or ".png" image types only.

  ## Options

    * `:stream_timeout` - An override for the after `:stream_timeout` field
    in the `Fastimage.Stream.Acc` struct which in turn determines the timeout in the
    processing of the hackney stream. By default the @default_stream_timeout
    is used in `Fastimage.Stream.Acc`.

    * `:max_error_retries` - An override for the `:max_error_retries` field
    in the `Fastimage.Stream.Acc` struct which in turn determines the maximum number
    of retries that will be attempted before giving up and returning an error.
    By default the @default_max_error_retries is used in `Fastimage.Stream.Acc`.

    * `:max_redirect_retries` - An override for the `:max_redirect_retries` field
    in the `Fastimage.Stream.Acc` struct which in turn determines the maximum number
    of redirects that will be attempted before giving up and returning an error.
    By default the @default_max_redirect_retries is used in `Fastimage.Stream.Acc`.

  ## Example

      iex> Fastimage.info("https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv/test.jpg")
      {:ok,
        %Fastimage{
         dimensions: %Fastimage.Dimensions{height: 142, width: 283},
         image_type: :jpeg,
         source: "https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv/test.jpg",
         source_type: :url
        }}

  """
  @spec info(binary()) :: {:ok, Fastimage.t()} | {:error, Error.t()}
    def info(source, opts \\ []) when is_binary(source) do
      case Utils.get_source_type(source) do
        :other ->
          {:error, %Error{reason: :invalid_input}}
        source_type ->
          info(source, source_type, opts)
      end
    end

  @doc """
  Returns a `%Fastimage{}` struct with information such as
  type and dimensions. Accepts a source as a url, binary
  object or file path.

  Supports ".bmp", ".gif", ".jpeg" or ".png" image types only.

  ## Options - see `info/1`

  ## Example

      iex> Fastimage.info!("https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv/test.jpg")
      %Fastimage{
        dimensions: %Fastimage.Dimensions{height: 142, width: 283},
        image_type: :jpeg,
        source: "https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv/test.jpg",
        source_type: :url
      }

  """
  @spec info!(binary()) :: Fastimage.t() | no_return()
  def info!(source, opts \\ []) when is_binary(source) do
    case info(source, opts) do
      {:ok, info} -> info
      {:error, %Error{} = error} -> raise(error)
      {:error, reason} -> raise(Error, reason)
    end
  end

  @doc """
  Returns the dimensions of the image. Accepts a source as a url, binary
  object or file path.

  Supports ".bmp", ".gif", ".jpeg" or ".png" image types only.

  ## Options

    * `:stream_timeout` - An override for the after `:stream_timeout` field
    in the `Fastimage.Stream.Acc` struct which in turn determines the timeout in the
    processing of the hackney stream. By default the @default_stream_timeout
    is used in `Fastimage.Stream.Acc`.

    * `:max_error_retries` - An override for the `:max_error_retries` field
    in the `Fastimage.Stream.Acc` struct which in turn determines the maximum number
    of retries that will be attempted before giving up and returning an error.
    By default the @default_max_error_retries is used in `Fastimage.Stream.Acc`.

    * `:max_redirect_retries` - An override for the `:max_redirect_retries` field
    in the `Fastimage.Stream.Acc` struct which in turn determines the maximum number
    of redirects that will be attempted before giving up and returning an error.
    By default the @default_max_redirect_retries is used in `Fastimage.Stream.Acc`.

  ## Example

      iex> Fastimage.size("https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv/test.jpg")
      {:ok, %Fastimage.Dimensions{height: 142, width: 283}}

  """
  @spec size(binary()) :: {:ok, Dimensions.t()} | {:error, Error.t()}
  def size(source, opts \\ []) when is_binary(source) do
    with {:ok, %Fastimage{dimensions: %Fastimage.Dimensions{} = dimensions}} <- info(source, opts) do
      {:ok, dimensions}
    end
  end

  @doc """
  Returns the dimensions of the image. Accepts a source as a url, binary
  object or file path.

  Supports ".bmp", ".gif", ".jpeg" or ".png" image types only.

  ## Options - see `size/1`

  ## Example

      iex> Fastimage.size!("https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv/test.jpg")
      %Fastimage.Dimensions{height: 142, width: 283}
  """
  @spec size!(binary()) :: Dimensions.t() | no_return()
  def size!(source, opts \\ []) when is_binary(source) do
    case size(source, opts) do
      {:ok, dimensions} -> dimensions
      {:error, %Error{} = error} -> raise(error)
      {:error, reason} -> raise(Error, reason)
    end
  end

  # private

  defp get_acc_with_type(source, source_type, opts) do
    stream_timeout = Keyword.get(opts, :stream_timeout, false)
    max_error_retries = Keyword.get(opts, :max_error_retries, false)
    max_redirect_retries = Keyword.get(opts, :max_redirect_retries, false)

    acc = %Stream.Acc{
      source: source,
      source_type: source_type
    }
    |> maybe_put_option(:stream_timeout, stream_timeout)
    |> maybe_put_option(:max_error_retries, max_error_retries)
    |> maybe_put_option(:max_redirect_retries, max_redirect_retries)

    with {:ok, %Stream.Acc{} = acc} <- Stream.stream_data(acc),
         bytes <- :erlang.binary_part(acc.acc_data, {0, 2}),
         {:ok, image_type} <- Parser.type(bytes, acc) do
      {:ok, %{acc | image_type: image_type}}
    end
  end

  defp info(source, source_type, opts) do
    with {:ok, %Stream.Acc{image_type: type} = acc} <- get_acc_with_type(source, source_type, opts),
         {:ok, %Dimensions{} = size} = Parser.size(type, acc) do
      Utils.close_stream(acc.stream_ref)

      {:ok,
        %Fastimage{
          source: source,
          source_type: source_type,
          image_type: type,
          dimensions: size
        }}
    end
  end

  defp maybe_put_option(%Stream.Acc{} = acc, option_key, false) do
    acc
  end

  defp maybe_put_option(%Stream.Acc{} = acc, option_key, option_val) do
    Map.put(acc, option_key, option_val)
  end
end