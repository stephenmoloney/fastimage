defmodule Fastimage do
  @moduledoc false
#  alias Fastimage.{Binary, Dimensions, File, Url, Utils}
  alias __MODULE__
  alias Fastimage.{Dimensions, Error, Url, Utils}

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
  """
  @spec type(binary()) :: {:ok, image_type()} | {:error, Error.t()}
  def type(source) when is_binary(source) do
    cond do
#      Utils.is_file?(source) -> File.type(source)
      Utils.is_url?(source) -> Url.type(source)
#      is_binary(source) -> Binary.type(source)
      true -> {:error, %Error{reason: :invalid_input}}
    end
  end

  @doc ~S"""
  Returns the type of image. Accepts a source as a url, binary
  object or file path.

  Supports ".bmp", ".gif", ".jpeg" or ".png" image types only.
  """
  @spec type!(binary()) :: image_type() | no_return()
  def type!(source) when is_binary(source) do
    case type(source) do
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
  """
  @spec info(binary()) :: {:ok, Fastimage.t()} | {:error, Error.t()}
    def info(source) when is_binary(source) do
      cond do
  #      Utils.is_file?(source) -> File.size(source)
        Utils.is_url?(source) -> Url.info(source)
  #      is_binary(source) -> Binary.size(source)
        true -> {:error, %Error{reason: :invalid_input}}
      end
    end

  @doc """
  Returns a `%Fastimage{}` struct with information such as
  type and dimensions. Accepts a source as a url, binary
  object or file path.

  Supports ".bmp", ".gif", ".jpeg" or ".png" image types only.
  """
  @spec info!(binary()) :: Fastimage.t() | no_return()
  def info!(source) when is_binary(source) do
    case info(source) do
      {:ok, info} -> info
      {:error, %Error{} = error} -> raise(error)
      {:error, reason} -> raise(Error, reason)
    end
  end

  @doc """
  Returns the dimensions of the image. Accepts a source as a url, binary
  object or file path.

  Supports ".bmp", ".gif", ".jpeg" or ".png" image types only.
  """
  @spec size(binary()) :: {:ok, Dimensions.t()} | {:error, Error.t()}
  def size(source) when is_binary(source) do
    with {:ok, %Fastimage{dimensions: %Fastimage.Dimensions{} = dimensions}} <- info(source) do
      {:ok, dimensions}
    end
  end

  @doc """
  Returns the dimensions of the image. Accepts a source as a url, binary
  object or file path.

  Supports ".bmp", ".gif", ".jpeg" or ".png" image types only.
  """
  @spec size!(binary()) :: Dimensions.t() | no_return()
  def size!(source) when is_binary(source) do
    case size(source) do
      {:ok, dimensions} -> dimensions
      {:error, %Error{} = error} -> raise(error)
      {:error, reason} -> raise(Error, reason)
    end
  end

  # callbacks

  @doc false
  @callback type(binary()) :: {:ok, image_type()} | {:error, Error.t()}

  @doc false
  @callback info(binary()) :: {:ok, Dimensions.t()} | {:error, Error.t()}
end