defmodule Fastimage.Stream do
  @moduledoc false
  alias Fastimage.Stream.Acc
  alias Fastimage.{Error, Utils}
  @file_chunk_size 500
  @binary_chunk_size 500

  defmodule Acc do
    @moduledoc false
    alias __MODULE__
    @default_stream_timeout 3_000
    @default_max_error_retries 5
    @default_max_redirect_retries 3

    @type source_type :: :url | :file | :binary
    @type image_type :: :bmp | :file | :binary
    @type stream_state :: :unstarted | :processing | :done
    @type stream_ref :: reference() | File.Stream.t() | function()

    defstruct source: nil,
              source_type: nil,
              stream_ref: nil,
              stream_timeout: @default_stream_timeout,
              stream_state: :unstarted,
              image_type: nil,
              num_chunks_to_fetch: 1,
              acc_num_chunks: 0,
              acc_data: <<>>,
              num_redirects: 0,
              error_retries: 0,
              max_error_retries: @default_max_error_retries,
              max_redirect_retries: @default_max_redirect_retries

    @type t :: %Acc{
            source: binary(),
            source_type: source_type() | nil,
            stream_ref: stream_ref() | nil,
            stream_timeout: integer(),
            stream_state: stream_state(),
            image_type: image_type(),
            num_chunks_to_fetch: integer(),
            acc_num_chunks: integer(),
            acc_data: binary(),
            num_redirects: integer(),
            error_retries: integer(),
            max_error_retries: integer(),
            max_redirect_retries: integer()
          }

    def redraw(%Acc{} = existing) do
      redrawn =
        Map.take(existing, [
          :source,
          :source_type,
          :stream_timeout,
          :max_error_retries,
          :max_redirect_retries
        ])

      Map.merge(%Acc{}, redrawn)
    end
  end

  def stream_data(
        %Acc{
          source: source,
          source_type: :binary,
          stream_state: :unstarted
        } = acc
      ) do
    stream_data(
      %{acc |
        stream_ref: binary_stream(source),
        stream_state: :processing}
    )
  end

  def stream_data(
        %Acc{
          source_type: :binary,
          stream_ref: binary_stream,
          stream_state: :processing,
          num_chunks_to_fetch: num_chunks_to_fetch,
          acc_num_chunks: acc_num_chunks,
          acc_data: acc_data
        } = acc
      ) do
    cond do
      num_chunks_to_fetch == 0 ->
        {:ok, acc}

      num_chunks_to_fetch > 0 ->
        data =
          binary_stream
          |> Enum.slice(acc_num_chunks, num_chunks_to_fetch)
          |> Enum.join()

        stream_data(%{
          acc |
            num_chunks_to_fetch: 0,
            acc_num_chunks: acc_num_chunks + num_chunks_to_fetch,
            acc_data: <<acc_data::binary, data::binary>>
        })

      true ->
        reason = :unexpected_binary_streaming_error
        {:error, Error.exception(reason)}
    end
  end

  def stream_data(
        %Acc{
          source: source,
          source_type: :file,
          stream_state: :unstarted
        } = acc
      ) do
    stream_ref = File.stream!(source, [:read, :compressed], @file_chunk_size)
    stream_data(%{acc | stream_ref: stream_ref, stream_state: :processing})
  end

  def stream_data(
        %Acc{
          source_type: :file,
          stream_ref: %File.Stream{} = file_stream,
          stream_state: :processing,
          num_chunks_to_fetch: num_chunks_to_fetch,
          acc_num_chunks: acc_num_chunks,
          acc_data: acc_data
        } = acc
      ) do
    cond do
      num_chunks_to_fetch == 0 ->
        {:ok, acc}

      num_chunks_to_fetch > 0 ->
        data =
          file_stream
          |> Enum.slice(acc_num_chunks, num_chunks_to_fetch)
          |> Enum.join()

        stream_data(%{
          acc
          | num_chunks_to_fetch: 0,
            acc_num_chunks: acc_num_chunks + num_chunks_to_fetch,
            acc_data: <<acc_data::binary, data::binary>>
        })

      true ->
        Utils.close_stream(file_stream)
        reason = {:unexpected_file_streaming_error, acc}
        {:error, Error.exception(reason)}
    end
  end

  def stream_data(
        %Acc{
          source: source,
          source_type: :url,
          stream_state: :unstarted
        } = acc
      ) do
    with {:ok, stream_ref} <-
           :hackney.get(source, [], <<>>, [{:async, :once}, {:follow_redirect, true}]) do
      stream_data(%{
        acc
        | stream_ref: stream_ref,
          stream_state: :processing
      })
    end
  end

  def stream_data(
        %Acc{
          source_type: :url,
          stream_ref: stream_ref,
          stream_state: :processing,
          num_redirects: num_redirects,
          max_redirect_retries: max_redirect_retries
        } = _acc
      )
      when num_redirects > max_redirect_retries do
    Utils.close_stream(stream_ref)

    raise(
      "error, three redirects have already been attempted, are you sure this is the correct image uri?"
    )
  end

  def stream_data(
        %Acc{
          source_type: :url,
          stream_ref: stream_ref,
          stream_timeout: stream_timeout,
          stream_state: :processing,
          num_chunks_to_fetch: num_chunks_to_fetch,
          acc_num_chunks: acc_num_chunks,
          acc_data: acc_data,
          num_redirects: num_redirects,
          error_retries: error_retries,
          max_redirect_retries: _max_redirect_retries,
          max_error_retries: max_error_retries
        } = acc
      ) do
    cond do
      num_chunks_to_fetch == 0 ->
        {:ok, acc}

      num_chunks_to_fetch > 0 ->
        _next_chunk = :hackney.stream_next(stream_ref)

        receive do
          {:hackney_response, _stream_ref, {:status, status_code, reason}} ->
            cond do
              status_code > 400 ->
                error_msg =
                  "error, could not open image file with error #{status_code} due to reason, #{
                    reason
                  }"

                Utils.close_stream(stream_ref)
                raise(error_msg)

              true ->
                stream_data(acc)
            end

          {:hackney_response, _stream_ref, {:headers, _headers}} ->
            stream_data(acc)

          {:hackney_response, stream_ref, {:redirect, to_url, _headers}} ->
            Utils.close_stream(stream_ref)

            acc
            |> Acc.redraw()
            |> Map.merge(%{
              source: to_url,
              num_redirects: num_redirects + 1
            })
            |> stream_data()

          {:hackney_response, _stream_ref, :done} ->
            stream_data(%{acc | num_chunks_to_fetch: 0, stream_state: :done})

          {:hackney_response, _stream_ref, data} ->
            stream_data(%{
              acc
              | num_chunks_to_fetch: num_chunks_to_fetch - 1,
                acc_num_chunks: acc_num_chunks + 1,
                acc_data: <<acc_data::binary, data::binary>>
            })

          _ ->
            Utils.close_stream(stream_ref)
            raise("error, unexpected streaming error while streaming acc")
        after
          stream_timeout ->
            error = "error, uri stream timeout #{stream_timeout} exceeded too many times"

            case error_retries < max_error_retries do
              true ->
                Utils.close_stream(stream_ref)

                acc
                |> Acc.redraw()
                |> Map.merge(%{
                  error_retries: error_retries + 1
                })
                |> stream_data()

              false ->
                Utils.close_stream(stream_ref)
                raise(error)
            end
        end

      true ->
        Utils.close_stream(stream_ref)
        {:error, :unexpected_http_streaming_error}
    end
  end

  def stream_data(%Acc{stream_state: :done} = acc) do
    {:ok, acc}
  end

  # private

  defp binary_stream(binary_data) do
    Stream.resource(
      fn -> binary_data end,
      fn binary_data ->
        bin_size = :erlang.byte_size(binary_data)
        case bin_size > @binary_chunk_size do
          true ->
            chunk = Kernel.binary_part(binary_data, 0, @binary_chunk_size)
            next_binary_data = Kernel.binary_part(binary_data, @binary_chunk_size, bin_size - @binary_chunk_size)
            {[chunk], next_binary_data}

          false ->
            final_chunk = binary_data
            {:halt, final_chunk}
        end
      end,
      fn _last_chunk -> :ok end
    )
  end
end
