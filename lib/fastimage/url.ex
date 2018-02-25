defmodule Fastimage.Url do
  @moduledoc false
  alias Fastimage.{Error, Parser, Stream, Utils}
  @behaviour Fastimage

  @doc ~S"""
  Returns the type of file. Only "bmp", "gif", "jpeg" or "png" files are currently detected.
  """
  @spec type(url :: String.t()) :: String.t() | :unknown_type
  def type(url) do
    with {:ok, %Stream.Acc{} = acc} <- Stream.stream_data(%Stream.Acc{source: url}),
         bytes <- :erlang.binary_part(acc.acc_data, {0, 2}) do
      type(bytes, acc, close_stream: true)
    end
  end

  @doc ~S"""
  Returns the dimensions of the image as a map in the form `%{width: _w, height: _h}`. Supports "bmp", "gif", "jpeg"
  or "png" image files only. Returns :unknown_type if the image file type is not supported.
  """
  @spec size(url :: String.t()) :: map | :unknown_type
  def size(url) do
    with {:ok, acc} <- Stream.stream_data(%Stream.Acc{source: url}),
         bytes <- :erlang.binary_part(acc.acc_data, {0, 2}),
         {:ok, type} <- type(bytes, acc, close_stream: false),
         {:ok, size} = Parser.size(type, acc) do
      Utils.close_stream(acc.stream_ref)
      {:ok, size}
    end
  end

  # private

  defp type(bytes, %Stream.Acc{source: url, stream_ref: stream_ref}, opts) do
    stream_to_be_closed? = Keyword.get(opts, :close_stream, false)
    stream_to_be_closed? && Utils.close_stream(stream_ref)

    cond do
      bytes == "BM" ->
        {:ok, :bmp}

      bytes == "GI" ->
        {:ok, :gif}

      bytes == <<255, 216>> ->
        {:ok, :jpeg}

      bytes == <<137>> <> "P" ->
        {:ok, :png}

      true ->
        stream_to_be_closed? || Utils.close_stream(stream_ref)
        reason = {:unsupported, url}
        {:error, Error.exception(reason)}
    end
  end
end
