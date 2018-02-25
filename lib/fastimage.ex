defmodule Fastimage do
  @moduledoc false
#  alias Fastimage.{Binary, Dimensions, File, Url, Utils}
  alias Fastimage.{Dimensions, Error, Url, Utils}

  @type :: image_types :bmp | :gif | :jpeg | :png

  @doc ~S"""
  Returns the type of file.

  Only "bmp", "gif", "jpeg" or "png" files are currently supported.
  """
  @spec type(binary()) :: {:ok, image_types()} | {:error, Error.t()}
  def type(arg) when is_binary(arg) do
    cond do
#      Utils.is_file?(arg) -> File.type(arg)
      Utils.is_url?(arg) -> Url.type(arg)
#      is_binary(arg) -> Binary.type(arg)
      true -> {:error, %Error{reason: :invalid_input}}
    end
  end

  @doc ~S"""
  Returns the type of file.

  Only "bmp", "gif", "jpeg" or "png" files are currently supported.
  """
  @spec type!(binary()) :: image_types() | no_return()
  def type!(arg) when is_binary(arg) do
    case type(arg) do
      {:ok, type} -> type
      {:error, %Error{} = error} -> raise(error)
      {:error, reason} -> raise(Error, reason)
    end
  end

  @doc """
  Returns the dimensions of the image.

  Supports "bmp", "gif", "jpeg" or "png" image files only.
  """
  @spec size(binary()) :: {:ok, Dimensions.t()} | {:error, Error.t()}
  def size(arg) when is_binary(arg) do
    cond do
#      Utils.is_file?(arg) -> File.size(arg)
      Utils.is_url?(arg) -> Url.size(arg)
#      is_binary(arg) -> Binary.size(arg)
      true -> {:error, %Error{reason: :invalid_input}}
    end
  end

  @doc """
  Returns the dimensions of the image.

  Supports "bmp", "gif", "jpeg" or "png" image files only.
  """
  @spec size!(binary()) :: Dimensions.t() | no_return()
  def size!(arg) when is_binary(arg) do
    case size(arg) do
      {:ok, size} -> size
      {:error, %Error{} = error} -> raise(error)
      {:error, reason} -> raise(Error, reason)
    end
  end

  @doc false
  @callback type(binary()) :: {:ok, image_types()} | {:error, Error.t()}

  @doc false
  @callback size(binary()) :: {:ok, Dimensions.t()} | {:error, Error.t()}
end