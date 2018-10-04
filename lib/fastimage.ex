defmodule Fastimage do
  @moduledoc """
  Fastimage finds the dimensions/size or file type of a remote url,
  local image file or a binary object given the url, file path or
  binary itself respectively.

  It streams the smallest amount of data necessary to ascertain the file size.

  Supports ".bmp", ".gif", ".jpeg", ".webp" or ".png" image types only.
  """
  alias __MODULE__
  alias Fastimage.{Dimensions, Error, Parser, Stream, Utils}

  @typedoc """
    * `:stream_timeout` - Applies to a url only.
    An override for the after `:stream_timeout` field
    in the `Fastimage.Stream.Acc` struct which in turn determines the timeout in the
    processing of the hackney stream. By default the @default_stream_timeout
    is used in `Fastimage.Stream.Acc`.

    * `:max_error_retries` - Applies to a url only.
    An override for the `:max_error_retries` field
    in the `Fastimage.Stream.Acc` struct which in turn determines the maximum number
    of retries that will be attempted before giving up and returning an error.
    By default the @default_max_error_retries is used in `Fastimage.Stream.Acc`.

    * `:max_redirect_retries` - Applies to a url only.
    An override for the `:max_redirect_retries` field
    in the `Fastimage.Stream.Acc` struct which in turn determines the maximum number
    of redirects that will be attempted before giving up and returning an error.
    By default the @default_max_redirect_retries is used in `Fastimage.Stream.Acc`.
  """
  @type fastimage_opts :: [
          stream_timeout: non_neg_integer,
          max_error_retries: non_neg_integer,
          max_redirect_retries: non_neg_integer
        ]
  @type image_type :: :bmp | :gif | :jpeg | :png | :webp
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

  ## Example

      iex> Fastimage.type("https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv/test.jpg")
      {:ok, :jpeg}

  """
  @spec type(binary(), fastimage_opts()) :: {:ok, image_type()} | {:error, Error.t()}
  def type(source, opts \\ []) when is_binary(source) do
    with {:ok, source_type} <- Utils.get_source_type(source),
         {:ok, %Stream.Acc{image_type: type, stream_ref: stream_ref}} <-
           get_acc_with_type(source, source_type, opts) do
      Utils.close_stream(stream_ref)
      {:ok, type}
    end
  end

  @doc ~S"""
  Returns the type of image. Accepts a source as a url, binary
  object or file path.

  ## Example

      iex> Fastimage.type!("https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv/test.jpg")
      :jpeg

  """
  @spec type!(binary(), fastimage_opts()) :: image_type() | no_return()
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
  @spec info(binary(), fastimage_opts()) :: {:ok, Fastimage.t()} | {:error, Error.t()}
  def info(source, opts \\ []) when is_binary(source) do
    with {:ok, source_type} <- Utils.get_source_type(source) do
      info(source, source_type, opts)
    end
  end

  @doc """
  Returns a `%Fastimage{}` struct with information such as
  type and dimensions. Accepts a source as a url, binary
  object or file path.

  ## Example

      iex> Fastimage.info!("https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv/test.jpg")
      %Fastimage{
        dimensions: %Fastimage.Dimensions{height: 142, width: 283},
        image_type: :jpeg,
        source: "https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv/test.jpg",
        source_type: :url
      }

  """
  @spec info!(binary(), fastimage_opts()) :: Fastimage.t() | no_return()
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

  ## Example

      iex> Fastimage.size("https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv/test.jpg")
      {:ok, %Fastimage.Dimensions{height: 142, width: 283}}

  """
  @spec size(binary(), fastimage_opts()) :: {:ok, Dimensions.t()} | {:error, Error.t()}
  def size(source, opts \\ []) when is_binary(source) do
    with {:ok, %Fastimage{dimensions: %Fastimage.Dimensions{} = dimensions}} <- info(source, opts) do
      {:ok, dimensions}
    end
  end

  @doc """
  Returns the dimensions of the image. Accepts a source as a url, binary
  object or file path.

  ## Example

      iex> Fastimage.size!("https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv/test.jpg")
      %Fastimage.Dimensions{height: 142, width: 283}
  """
  @spec size!(binary(), fastimage_opts()) :: Dimensions.t() | no_return()
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

    acc =
      if source_type == :url do
        acc
        |> maybe_put_option(:stream_timeout, stream_timeout)
        |> maybe_put_option(:max_error_retries, max_error_retries)
        |> maybe_put_option(:max_redirect_retries, max_redirect_retries)
      else
        acc
      end

    with {:ok, %Stream.Acc{} = updated_acc} <- Stream.stream_data(acc),
         bytes <- :erlang.binary_part(updated_acc.acc_data, {0, 2}),
         {:ok, image_type} <- Parser.type(bytes, updated_acc) do
      {:ok, %{updated_acc | image_type: image_type}}
    else
      {:error, {:closed, :timeout}} = reason ->
        Error.exception(reason)

      {:error, %Error{} = error} ->
        {:error, error}
    end
  end

  defp info(source, source_type, opts) do
    with {:ok, %Stream.Acc{image_type: type} = acc} <-
           get_acc_with_type(source, source_type, opts),
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

  defp maybe_put_option(%Stream.Acc{} = acc, _option_key, false) do
    acc
  end

  defp maybe_put_option(%Stream.Acc{} = acc, option_key, option_val) do
    Map.put(acc, option_key, option_val)
  end
end
