defmodule Fastimage.Parser do
  @moduledoc false
  alias Fastimage.{Dimensions, Error, Parser, Stream, Utils}
  use Bitwise

  @doc false
  def size(:bmp, %Stream.Acc{acc_data: data}) do
    Parser.parse_bmp(data)
  end

  def size(:gif, %Stream.Acc{acc_data: data}) do
    Parser.parse_gif(data)
  end

  def size(:png, %Stream.Acc{acc_data: data}) do
    Parser.parse_png(data)
  end

  def size(:jpeg, %Stream.Acc{acc_data: next_data} = acc) do
    chunk_size = :erlang.byte_size(next_data)
    Parser.parse_jpeg(acc, next_data, chunk_size, :initial)
  end

  def size(:webp, %Stream.Acc{acc_data: data}) do
    Parser.parse_webp(data)
  end

  @doc false
  def type(bytes, %Stream.Acc{acc_data: acc_data, stream_ref: stream_ref} = acc) do
    case {bytes, acc_data} do
      {"BM", _} ->
        {:ok, :bmp}

      {"GI", _} ->
        {:ok, :gif}

      {<<255, 216>>, _} ->
        {:ok, :jpeg}

      {<<137, 80>>, _} ->
        {:ok, :png}

      {"RI", <<_::binary-size(8), "WEBP", _rest::binary>>} ->
        {:ok, :webp}

      _ ->
        Utils.close_stream(stream_ref)
        {:error, Error.exception({:unsupported, acc})}
    end
  end

  @doc false
  def parse_jpeg(
        %Stream.Acc{acc_num_chunks: acc_num_chunks} = acc,
        next_data,
        chunk_size,
        state
      ) do
    # get more data if less that 4 bytes remaining
    if chunk_size < 4 do
      parse_jpeg_with_more_data(
        %{acc | num_chunks_to_fetch: acc_num_chunks + 2},
        next_data,
        chunk_size,
        state
      )
    end

    case state do
      :initial ->
        skip = 2
        next_bytes = :erlang.binary_part(next_data, {skip, :erlang.byte_size(next_data) - skip})
        parse_jpeg(acc, next_bytes, chunk_size, :start)

      :start ->
        next_bytes = next_bytes_until_match(<<255>>, next_data)
        parse_jpeg(acc, next_bytes, chunk_size, :sof)

      :sof ->
        <<next_byte::8, next_bytes::binary>> = next_data

        cond do
          true == (next_byte == 225) ->
            # TODO - add option for exif information parsing here
            parse_jpeg(acc, next_bytes, chunk_size, :skip)

          true == next_byte in 224..239 ->
            parse_jpeg(acc, next_bytes, chunk_size, :skip)

          true ==
              [192..195, 197..199, 201..203, 205..207]
              |> Enum.any?(fn range -> next_byte in range end) ->
            parse_jpeg(acc, next_bytes, chunk_size, :read)

          true == (next_byte == 255) ->
            parse_jpeg(acc, next_bytes, chunk_size, :sof)

          true ->
            parse_jpeg(acc, next_bytes, chunk_size, :skip)
        end

      :skip ->
        <<u_int::unsigned-integer-size(16), next_bytes::binary>> = next_data
        skip = u_int - 2
        compare_size = :erlang.byte_size(next_data) - 10

        case skip >= compare_size do
          true ->
            num_chunks_to_fetch =
              acc_num_chunks
              |> Kernel.+(Float.ceil(skip / chunk_size))
              |> :erlang.round()

            parse_jpeg_with_more_data(
              %{acc | num_chunks_to_fetch: num_chunks_to_fetch},
              next_data,
              chunk_size,
              :skip
            )

          false ->
            next_bytes =
              :erlang.binary_part(next_bytes, {skip, :erlang.byte_size(next_bytes) - skip})

            parse_jpeg(
              acc,
              next_bytes,
              chunk_size,
              :start
            )
        end

      :read ->
        next_bytes = :erlang.binary_part(next_data, {3, :erlang.byte_size(next_data) - 3})
        <<height::unsigned-integer-size(16), next_bytes::binary>> = next_bytes
        <<width::unsigned-integer-size(16), _next_bytes::binary>> = next_bytes
        {:ok, %Dimensions{width: width, height: height}}
    end
  end

  @doc false
  def parse_jpeg_with_more_data(
        %Stream.Acc{
          stream_state: :done
        } = acc,
        _next_data,
        _chunk_size,
        _state
      ) do
    reason = {:unexpected_end_of_stream_error, acc}
    {:error, Error.exception(reason)}
  end

  def parse_jpeg_with_more_data(
        %Stream.Acc{
          acc_data: acc_data
        } = acc,
        next_data,
        chunk_size,
        state
      ) do
    {:ok, new_acc} = Stream.stream_data(acc)

    num_bytes_old_data = :erlang.byte_size(acc_data) - :erlang.byte_size(next_data)

    new_next_data =
      :erlang.binary_part(
        new_acc.acc_data,
        {num_bytes_old_data, :erlang.byte_size(new_acc.acc_data) - num_bytes_old_data}
      )

    parse_jpeg(
      new_acc,
      new_next_data,
      chunk_size,
      state
    )
  end

  @doc false
  def parse_png(data) do
    next_bytes = :erlang.binary_part(data, {16, 8})
    <<width::unsigned-integer-size(32), next_bytes::binary>> = next_bytes
    <<height::unsigned-integer-size(32), _next_bytes::binary>> = next_bytes
    {:ok, %Dimensions{width: width, height: height}}
  end

  @doc false
  def parse_gif(data) do
    next_bytes = :erlang.binary_part(data, {6, 4})
    <<width::little-unsigned-integer-size(16), rest::binary>> = next_bytes
    <<height::little-unsigned-integer-size(16), _rest::binary>> = rest
    {:ok, %Dimensions{width: width, height: height}}
  end

  @doc false
  def parse_bmp(data) do
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

  @doc false
  def parse_webp(<<_::binary-size(12), type::binary-size(4), _len::binary-size(4), data::binary>>) do
    case type do
      "VP8 " -> parse_webp_vp8(data)
      "VP8L" -> parse_webp_vp8l(data)
      "VP8X" -> parse_webp_vp8x(data)
      other -> {:error, "unknown webp format: #{other}"}
    end
  end

  # Ref https://developers.google.com/speed/webp/docs/riff_container#simple_file_format_lossy
  defp parse_webp_vp8(
         <<_::binary-size(6), w::little-unsigned-integer-size(16),
           h::little-unsigned-integer-size(16), _rest::binary>>
       ) do
    width = w &&& 16_383
    height = h &&& 16_383
    {:ok, %Dimensions{width: width, height: height}}
  end

  # Ref https://developers.google.com/speed/webp/docs/riff_container#simple_file_format_lossless
  defp parse_webp_vp8l(
         <<_::binary-size(1), a::integer-size(8), b::integer-size(8), c::integer-size(8),
           d::integer-size(8), _rest::binary>>
       ) do
    width = 1 + ((b &&& 63) <<< 8 ||| a)
    height = 1 + ((d &&& 15) <<< 10 ||| c <<< 2 ||| (b &&& 192) >>> 6)

    {:ok, %Dimensions{width: width, height: height}}
  end

  # Ref https://developers.google.com/speed/webp/docs/riff_container#extended_file_format
  defp parse_webp_vp8x(
         <<_flags::binary-size(4), a::integer-size(8), b::integer-size(8), c::integer-size(8),
           d::integer-size(8), e::integer-size(8), f::integer-size(8), _rest::binary>>
       ) do
    width = 1 + a + (b <<< 8) + (c <<< 16)
    height = 1 + d + (e <<< 8) + (f <<< 16)

    {:ok, %Dimensions{width: width, height: height}}
  end

  defp next_bytes_until_match(byte, bytes) do
    case matching_byte(byte, bytes) do
      true ->
        next_bytes(byte, bytes)

      false ->
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
