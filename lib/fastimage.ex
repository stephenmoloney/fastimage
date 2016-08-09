defmodule Fastimage do
  @file_chunk_size 500

  @type recv_error :: :timeout | :no_file_found | :no_file_or_url_found | any
  @type stream_ref :: {pid, reference, atom} | File.Stream


  @doc ~S"""
  Returns the type of file. Only "bmp", "gif", "jpeg" or "png" files are currently detected.
  """
  @spec type(url_or_file :: String.t) :: String.t | :unknown_type
  def type(url_or_file) do
    {:ok, data, stream_ref} = recv(url_or_file)
    bytes = :erlang.binary_part(data, {0, 2})
    type(bytes, stream_ref, [close_stream: :true])
  end
  defp type(bytes, stream_ref, opts) do
    case Keyword.get(opts, :close_stream, :false) do
      :true -> close_stream(stream_ref)
      :false -> :ok
    end
    cond do
      bytes == "BM" -> "bmp"
      bytes == "GI" -> "gif"
      bytes == <<255, 216>> -> "jpeg"
      bytes == (<<137>> <> "P") -> "png"
      :true -> :unknown_type
    end
  end


  @doc ~S"""
  Returns the dimensions of the image as a map of the form %{width: w, height: h}. Supports "bmp", "gif", "jpeg"
   or "png" image files only.
  """
  @spec size(url_or_file :: String.t) :: map | :unknown_type
  def size(url_or_file) do
    {:ok, data, stream_ref} = recv(url_or_file)
    bytes = :erlang.binary_part(data, {0, 2})
    type = type(bytes, stream_ref, [close_stream: :false])
    dimensions = size(type, data, stream_ref)
    close_stream(stream_ref)
    dimensions
  end


  # private or docless


  defp size("bmp", data, _stream_ref), do: parse_bmp(data)
  defp size("gif", data, _stream_ref), do: parse_gif(data)
  defp size("png", data, _stream_ref), do: parse_png(data)
  defp size("jpeg", data, stream_ref) do
    chunk_size = :erlang.byte_size(data)
    parse_jpeg(stream_ref, {1, data}, data, 0, chunk_size, :initial)
  end
  defp size(:unknown_type, _data, _stream_ref), do: :unknown_type

  @doc :false
  @spec recv(url_or_file :: String.t | URI.t) ::  {:ok, binary, stream_ref, atom} | {:error, recv_error}
  def recv(url_or_file) do
    {:ok, _data, _stream_ref} =
    cond do
      is_url(url_or_file) == :true ->
        {:ok, data, {conn_pid, ref, fin}} = recv(URI.parse(url_or_file), :url, 1)
        {:ok, data, {conn_pid, ref, fin}}
      File.exists?(url_or_file) == :true ->
        {:ok, data, file_stream} = recv(url_or_file, :file, 1)
        {:ok, data, file_stream}
      File.exists?(url_or_file) == :false ->
        {:error, :no_file_found}
      :true ->
        {:error, :no_file_or_url_found}
    end
  end


  defp recv(file_path, :file, num_chunks) do
    case File.exists?(file_path) do
      :true ->
        file_stream = File.stream!(file_path, [:read, :compressed, :binary], @file_chunk_size)
        stream_chunks(file_stream, num_chunks, {0, <<>>}) # {:ok, data, file_stream}
      :false ->
        {:error, :file_not_found}
    end
  end


  defp recv(%URI{host: host, path: path, scheme: scheme, port: port}, :url, num_chunks) do
    transport = if scheme == "https", do: :ssl, else: :tcp
    host = String.to_char_list(host)
    {:ok, _data, {_conn_pid, _ref, _fin}} =
    with {:ok, conn_pid} = :gun.open(host, port, %{protocols: [:http], transport: transport}),
      {:ok, :http} = :gun.await_up(conn_pid),
      ref = :gun.get(conn_pid, path) do
      stream_chunks({conn_pid, ref, :no_fin}, num_chunks) # returns {:ok, data, {conn_pid, ref, fin}}
    end
  end


  defp stream_chunks(stream_ref, num_chunks_to_fetch, {acc_num_chunks, acc_data} \\ {0, ""}) do
    case stream_ref do
      {conn_pid, ref, fin?} -> stream_chunks_url({conn_pid, ref, fin?}, num_chunks_to_fetch, {acc_num_chunks, acc_data})
      file_stream -> stream_chunks_file(%File.Stream{} = file_stream, num_chunks_to_fetch, {acc_num_chunks, acc_data})
    end
  end

  defp stream_chunks_url({conn_pid, ref, fin?}, num_chunks_to_fetch, {acc_num_chunks, acc_data}) do
    cond do
      fin? == :fin ->
        cancel_remaining(conn_pid, ref)
        {:ok, acc_data, {conn_pid, ref, :fin}}
      num_chunks_to_fetch == 0 ->
        {:ok, acc_data, {conn_pid, ref, :nofin}}
      num_chunks_to_fetch > 0 ->
        receive do
          {:gun_data, conn_pid, ref, fin, data} ->
            stream_chunks({conn_pid, ref, fin}, num_chunks_to_fetch - 1, {acc_num_chunks + 1, <<acc_data::binary, data::binary>>})
        after
          5000 ->
            "error, timeout #{5000} exceeded" |> raise()
        end
      :true -> {:error, :unexpected_streaming_error}
    end
  end


  @doc :false
  def stream_chunks_file(%File.Stream{} = file_stream, num_chunks_to_fetch, {acc_num_chunks, acc_data}) do
    cond do
      num_chunks_to_fetch == 0 ->
        {:ok, acc_data, file_stream}
      num_chunks_to_fetch > 0 ->
        data = Enum.slice(file_stream, acc_num_chunks, num_chunks_to_fetch)
        |> Enum.join()
        stream_chunks(file_stream, 0, {acc_num_chunks + num_chunks_to_fetch, <<acc_data::binary, data::binary>>})
      :true -> {:error, :unexpected_streaming_error}
    end
  end

  @doc :false
  def parse_jpeg(stream_ref, {acc_num_chunks, acc_data}, next_data, num_chunks_to_fetch, chunk_size, state \\ :initial) do

    if :erlang.byte_size(next_data) < 4 do # get more data if less that 4 bytes remaining
      num_chunks_to_fetch = acc_num_chunks + 2
      parse_jpeg_with_more_data(stream_ref, {acc_num_chunks, acc_data}, next_data, num_chunks_to_fetch, chunk_size, state)
    end

    case state do
      :initial ->
        skip = 2
        next_bytes = :erlang.binary_part(next_data, {skip, :erlang.byte_size(next_data) - skip})
        parse_jpeg(stream_ref, {acc_num_chunks, acc_data}, next_bytes, num_chunks_to_fetch, chunk_size, :start)

      :start ->
        next_bytes = next_bytes_until_match(<<255>>, next_data)
        parse_jpeg(stream_ref, {acc_num_chunks, acc_data}, next_bytes, num_chunks_to_fetch, chunk_size, :sof)

      :sof ->
        <<next_byte::8, next_bytes::binary>> = next_data
        cond do
          :true == next_byte in (224..239) ->
            parse_jpeg(stream_ref, {acc_num_chunks, acc_data}, next_bytes, num_chunks_to_fetch, chunk_size, :skip)
          :true == [(192..195), (197..199), (201..203), (205..207)] |>
                   Enum.any?(fn(range) -> next_byte in range end) ->
            parse_jpeg(stream_ref, {acc_num_chunks, acc_data}, next_bytes, num_chunks_to_fetch, chunk_size, :read)
          :true == next_byte == 255 ->
            parse_jpeg(stream_ref, {acc_num_chunks, acc_data}, next_bytes, num_chunks_to_fetch, chunk_size, :sof)
          :true == next_byte == 225 ->
            parse_jpeg(stream_ref, {acc_num_chunks, acc_data}, next_bytes, num_chunks_to_fetch, chunk_size, :skip)
          :true ->
            parse_jpeg(stream_ref, {acc_num_chunks, acc_data}, next_bytes, num_chunks_to_fetch, chunk_size, :skip)
        end


      :skip ->
        <<u_int::unsigned-integer-size(16), next_bytes::binary>> = next_data
        skip = (u_int - 2)
        next_data_size = :erlang.byte_size(next_data)

        case skip >= (next_data_size - 10) do
          :true ->
            num_chunks_to_fetch = (acc_num_chunks + Float.ceil(skip/chunk_size)) |> :erlang.round()
            parse_jpeg_with_more_data(stream_ref, {acc_num_chunks, acc_data}, next_data, num_chunks_to_fetch, chunk_size, :skip)
          :false ->
            next_bytes = :erlang.binary_part(next_bytes, {skip, :erlang.byte_size(next_bytes) - skip})
            parse_jpeg(stream_ref, {acc_num_chunks, acc_data}, next_bytes, num_chunks_to_fetch, chunk_size, :start)
        end

      :read ->
        next_bytes = :erlang.binary_part(next_data, {3, :erlang.byte_size(next_data) - 3})
        <<height::unsigned-integer-size(16), next_bytes::binary>> = next_bytes
        <<width::unsigned-integer-size(16), _next_bytes::binary>> = next_bytes
        %{width: width, height: height}
    end
  end

  @doc :false
  defp parse_jpeg_with_more_data(stream_ref, {acc_num_chunks, acc_data}, next_data, num_chunks_to_fetch, chunk_size, state) do
    {:ok, new_acc_data, _file_stream} = stream_chunks(stream_ref, num_chunks_to_fetch, {acc_num_chunks, acc_data})
    num_bytes_old_data = :erlang.byte_size(acc_data) - :erlang.byte_size(next_data)
    new_next_data = :erlang.binary_part(new_acc_data, {num_bytes_old_data, :erlang.byte_size(new_acc_data) - num_bytes_old_data})
    parse_jpeg(stream_ref, {acc_num_chunks + num_chunks_to_fetch, new_acc_data}, new_next_data, 0, chunk_size, state)
  end


  @doc :false
  def parse_png(data) do
    next_bytes = :erlang.binary_part(data, {16, 8})
    <<width::unsigned-integer-size(32), next_bytes::binary>> = next_bytes
    <<height::unsigned-integer-size(32), _next_bytes::binary>> = next_bytes
    %{width: width, height: height}
  end



  @doc :false
  def parse_gif(data) do
    next_bytes = :erlang.binary_part(data, {6, 4})
    <<width::little-unsigned-integer-size(16), rest::binary>> = next_bytes
    <<height::little-unsigned-integer-size(16), _rest::binary>> = rest
    %{width: width, height: height}
  end


  @doc :false
  def parse_bmp(data) do
    new_bytes = :erlang.binary_part(data, {14, 14})
    <<char::8, _rest::binary>> = new_bytes
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


  defp is_url(url) when is_binary(url), do: (try do is_url(URI.parse(url)) rescue _error -> :false end)
  defp is_url(%URI{scheme: :nil}), do: :false
  defp is_url(%URI{host: :nil}), do: :false
  defp is_url(%URI{path: :nil}), do: :false
  defp is_url(%URI{}), do: :true


  defp cancel_remaining(conn_pid, ref) do
    :gun.cancel(conn_pid, ref)
    :gun.flush(conn_pid)
    :gun.close(conn_pid)
  end


  defp close_stream(stream_ref) do
    case stream_ref do
      {conn_pid, ref, _fin?} -> cancel_remaining(conn_pid, ref)
      filestream -> File.close(filestream.path)
    end
  end



end
