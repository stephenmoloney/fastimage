defmodule Fastimage.Utils do
  @moduledoc false
  alias Fastimage.Error

  @doc false
  def get_source_type(source) do
    cond do
      is_file?(source) -> {:ok, :file}
      is_url?(source) -> {:ok, :url}
      is_binary(source) -> {:ok, :binary}
      true -> {:error, %Error{reason: :invalid_input}}
    end
  end

  @doc false
  def is_url?(url) when is_binary(url) do
    url
    |> URI.parse()
    |> is_url?()
  rescue
    _error -> false
  end

  def is_url?(%URI{scheme: nil}) do
    false
  end

  def is_url?(%URI{host: nil}) do
    false
  end

  def is_url?(%URI{path: nil}) do
    false
  end

  def is_url?(%URI{}) do
    true
  end

  @doc false
  def is_file?(file) do
    File.exists?(file)
  end

  @doc false
  def close_stream(stream_ref) when is_reference(stream_ref) do
    :hackney.cancel_request(stream_ref)
    :hackney.close(stream_ref)
  end

  def close_stream(%File.Stream{} = stream_ref) do
    File.close(stream_ref.path)
  end

  def close_stream(_stream_ref) do
    :ok
  end
end
