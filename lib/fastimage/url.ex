defmodule Fastimage.Url do
  @moduledoc false
  import Fastimage.Utils
  alias Fastimage.{Dimensions, Error}

  @stream_timeout 3_000
  @max_error_retries 5


  @typep recv_error :: :timeout | :no_file_found | :no_file_or_url_found | any
  @typep stream_ref :: reference | File.Stream


  @doc ~S"""
  Returns the type of file. Only "bmp", "gif", "jpeg" or "png" files are currently detected.
  """
  @spec type(url :: String.t) :: String.t | :unknown_type
  def type(url) do
    with {:ok, data, stream_ref} <- recv(url, 0, 0),
        bytes <- :erlang.binary_part(data, {0, 2}) do
      type(bytes, stream_ref, url, close_stream: true)
    end
  end
  defp type(bytes, stream_ref, url, opts) do
    stream_to_be_closed? = Keyword.get(opts, :close_stream, false)
    stream_to_be_closed? && close_stream(stream_ref)

    cond do
      bytes == "BM" ->
        {:ok, "bmp"}

      bytes == "GI" ->
        {:ok, "gif"}

      bytes == <<255, 216>> ->
        {:ok, "jpeg"}

      bytes == <<137>> <> "P" ->
        {:ok, "png"}

      true ->
        stream_to_be_closed? || close_stream(stream_ref)
        reason = {:unsupported, url}
        {:error, Error.exception(reason)}
    end
  end

  @doc ~S"""
  Returns the dimensions of the image as a map in the form `%{width: _w, height: _h}`. Supports "bmp", "gif", "jpeg"
  or "png" image files only. Returns :unknown_type if the image file type is not supported.
  """
  @spec size(url :: String.t) :: map | :unknown_type
  def size(url) do
    with {:ok, data, stream_ref} <- recv(url, 0, 0),
        bytes <- :erlang.binary_part(data, {0, 2}),
         {:ok, type} <- type(bytes, stream_ref, url, [close_stream: :false]),
         {:ok, %Dimensions{width: _, height: _} = size} = size(type, data, stream_ref, url) do
      close_stream(stream_ref)
      {:ok, size}
    end
  end


  # private or docless


  defp size("bmp", data, _stream_ref, _url), do: parse_bmp(data)
  defp size("gif", data, _stream_ref, _url), do: parse_gif(data)
  defp size("png", data, _stream_ref, _url), do: parse_png(data)
  defp size("jpeg", data, stream_ref, url) do
    chunk_size = :erlang.byte_size(data)
    parse_jpeg(stream_ref, {1, data, url}, data, 0, chunk_size, :initial)
  end
  defp size(:unknown_type, _data, _stream_ref, _url), do: :unknown_type



  @doc false
  @spec recv(String.t(), integer(), integer) :: {:ok, binary(), reference()} | {:error, Error.t()}
  def recv(url, num_redirects, error_retries) do
    with {:ok, stream_ref} <- :hackney.get(url, [], <<>>, [{:async, :once}, {:follow_redirect, true}]) do
      stream_chunks(stream_ref, 1, {0, <<>>, url}, num_redirects, error_retries)
    end
  end
  def recv(_url, num_redirects, _error_retries) when num_redirects > 3 do
    raise("error, three redirects have already been attempted, are you sure this is the correct image uri?")
  end

  defp stream_chunks(stream_ref, num_chunks_to_fetch, {acc_num_chunks, acc_data, url}, num_redirects, error_retries) when is_reference(stream_ref) do
    cond do
      num_chunks_to_fetch == 0 ->
        {:ok, acc_data, stream_ref}
      num_chunks_to_fetch > 0 ->
        _next_chunk = :hackney.stream_next(stream_ref)
        receive do
          {:hackney_response, stream_ref, {:status, status_code, reason}} ->
            cond do
              status_code > 400 ->
                error_msg = "error, could not open image file with error #{status_code} due to reason, #{reason}"
                raise(error_msg)
              :true ->
                stream_chunks(stream_ref, num_chunks_to_fetch, {acc_num_chunks, acc_data, url}, num_redirects, error_retries)
            end
          {:hackney_response, stream_ref, {:headers, _headers}} ->
            stream_chunks(stream_ref, num_chunks_to_fetch, {acc_num_chunks, acc_data, url}, num_redirects, error_retries)
          {:hackney_response, stream_ref, {:redirect, to_url, _headers}} ->
            close_stream(stream_ref)
            recv(to_url, num_redirects + 1, error_retries)
          {:hackney_response, stream_ref, :done} ->
            {:ok, acc_data, stream_ref}
          {:hackney_response, stream_ref, data} ->
            stream_chunks(stream_ref, num_chunks_to_fetch - 1, {acc_num_chunks + 1, <<acc_data::binary, data::binary>>, url}, num_redirects, error_retries)
          _ ->
            raise("error, unexpected streaming error while streaming chunks")
        after @stream_timeout ->
          error = "error, uri stream timeout #{@stream_timeout} exceeded too many times"
          case error_retries < @max_error_retries do
            :true ->
              close_stream(stream_ref)
              recv(url, num_redirects, error_retries + 1)
            :false ->
              raise(error)
          end
        end
      :true -> {:error, :unexpected_http_streaming_error}
    end
  end
  defp stream_chunks(%File.Stream{} = stream_ref, num_chunks_to_fetch, {acc_num_chunks, acc_data, file_path}, 0, 0) do
    cond do
      num_chunks_to_fetch == 0 ->
        {:ok, acc_data, stream_ref}
      num_chunks_to_fetch > 0 ->
        data = Enum.slice(stream_ref, acc_num_chunks, num_chunks_to_fetch)
               |> Enum.join()
        stream_chunks(stream_ref, 0, {acc_num_chunks + num_chunks_to_fetch, <<acc_data::binary, data::binary>>, file_path}, 0, 0)
      :true -> {:error, :unexpected_file_streaming_error}
    end
  end


  defp parse_jpeg(stream_ref, {acc_num_chunks, acc_data, url}, next_data, num_chunks_to_fetch, chunk_size, state) do

    if :erlang.byte_size(next_data) < 4 do # get more data if less that 4 bytes remaining
      new_num_chunks_to_fetch = acc_num_chunks + 2
      parse_jpeg_with_more_data(stream_ref, {acc_num_chunks, acc_data, url}, next_data, new_num_chunks_to_fetch, chunk_size, state)
    end

    case state do
      :initial ->
        skip = 2
        next_bytes = :erlang.binary_part(next_data, {skip, :erlang.byte_size(next_data) - skip})
        parse_jpeg(stream_ref, {acc_num_chunks, acc_data, url}, next_bytes, num_chunks_to_fetch, chunk_size, :start)

      :start ->
        next_bytes = next_bytes_until_match(<<255>>, next_data)
        parse_jpeg(stream_ref, {acc_num_chunks, acc_data, url}, next_bytes, num_chunks_to_fetch, chunk_size, :sof)

      :sof ->
        <<next_byte::8, next_bytes::binary>> = next_data
        cond do
          :true == (next_byte == 225) ->
            # TODO - add option for exif information parsing here
            parse_jpeg(stream_ref, {acc_num_chunks, acc_data, url}, next_bytes, num_chunks_to_fetch, chunk_size, :skip)
          :true == (next_byte in (224..239)) ->
            parse_jpeg(stream_ref, {acc_num_chunks, acc_data, url}, next_bytes, num_chunks_to_fetch, chunk_size, :skip)
          :true == [(192..195), (197..199), (201..203), (205..207)] |>
            Enum.any?(fn(range) -> next_byte in range end) ->
            parse_jpeg(stream_ref, {acc_num_chunks, acc_data, url}, next_bytes, num_chunks_to_fetch, chunk_size, :read)
          :true == (next_byte == 255) ->
            parse_jpeg(stream_ref, {acc_num_chunks, acc_data, url}, next_bytes, num_chunks_to_fetch, chunk_size, :sof)
          :true ->
            parse_jpeg(stream_ref, {acc_num_chunks, acc_data, url}, next_bytes, num_chunks_to_fetch, chunk_size, :skip)
        end


      :skip ->
        <<u_int::unsigned-integer-size(16), next_bytes::binary>> = next_data
        skip = (u_int - 2)
        next_data_size = :erlang.byte_size(next_data)

        case skip >= (next_data_size - 10) do
          :true ->
            num_chunks_to_fetch = (acc_num_chunks + Float.ceil(skip/chunk_size)) |> :erlang.round()
            parse_jpeg_with_more_data(stream_ref, {acc_num_chunks, acc_data, url}, next_data, num_chunks_to_fetch, chunk_size, :skip)
          :false ->
            next_bytes = :erlang.binary_part(next_bytes, {skip, :erlang.byte_size(next_bytes) - skip})
            parse_jpeg(stream_ref, {acc_num_chunks, acc_data, url}, next_bytes, num_chunks_to_fetch, chunk_size, :start)
        end

      :read ->
        next_bytes = :erlang.binary_part(next_data, {3, :erlang.byte_size(next_data) - 3})
        <<height::unsigned-integer-size(16), next_bytes::binary>> = next_bytes
        <<width::unsigned-integer-size(16), _next_bytes::binary>> = next_bytes
        {:ok, %Dimensions{width: width, height: height}}
    end
  end


  defp parse_jpeg_with_more_data(stream_ref, {acc_num_chunks, acc_data, url}, next_data, num_chunks_to_fetch, chunk_size, state) do
    {:ok, new_acc_data, _stream_ref} = stream_chunks(stream_ref, num_chunks_to_fetch, {acc_num_chunks, acc_data, url}, 0, 0)
    num_bytes_old_data = :erlang.byte_size(acc_data) - :erlang.byte_size(next_data)
    new_next_data = :erlang.binary_part(new_acc_data, {num_bytes_old_data, :erlang.byte_size(new_acc_data) - num_bytes_old_data})
    parse_jpeg(stream_ref, {acc_num_chunks + num_chunks_to_fetch, new_acc_data, url}, new_next_data, 0, chunk_size, state)
  end


  defp parse_png(data) do
    next_bytes = :erlang.binary_part(data, {16, 8})
    <<width::unsigned-integer-size(32), next_bytes::binary>> = next_bytes
    <<height::unsigned-integer-size(32), _next_bytes::binary>> = next_bytes
    {:ok, %Dimensions{width: width, height: height}}
  end


  defp parse_gif(data) do
    next_bytes = :erlang.binary_part(data, {6, 4})
    <<width::little-unsigned-integer-size(16), rest::binary>> = next_bytes
    <<height::little-unsigned-integer-size(16), _rest::binary>> = rest
    {:ok, %Dimensions{width: width, height: height}}
  end


  defp parse_bmp(data) do
    new_bytes = :erlang.binary_part(data, {14, 14})
    <<char::8, _rest::binary>> = new_bytes
    %{width: width, height: height} =
      case char do
        40 ->
          part = :erlang.binary_part(new_bytes, {4, :erlang.byte_size(new_bytes) - 5})
          <<width::little-unsigned-integer-size(32), rest::binary>> = part
          <<height::little-unsigned-integer-size(32), _rest::binary>> = rest
          %{width: width, height: height}
        _ ->
          part = :erlang.binary_part(new_bytes, {4, 8})
          <<width::native-unsigned-integer-size(16), rest::binary>> = part
          <<height::native-unsigned-integer-size(16), _rest::binary>> = rest
          %{width: width, height: height}
      end
    {:ok, %Dimensions{width: width, height: height}}
  end


  defp next_bytes_until_match(byte, bytes) do
    case matching_byte(byte, bytes) do
      :true -> next_bytes(byte, bytes)
      :false ->
        <<_discarded_byte, next_bytes::binary>> = bytes
        next_bytes_until_match(byte, next_bytes)
    end
  end


  defp matching_byte(<<byte?>>, bytes) do
    <<first_byte, _next_bytes::binary>> = bytes
    first_byte == byte?
  end


  defp next_bytes(_byte, bytes) do
    <<_byte, next_bytes::binary>> = bytes
    next_bytes
  end
end
