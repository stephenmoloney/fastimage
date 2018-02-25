defmodule Fastimage.Error do
  @moduledoc """
  Representations of various errors potentially returned by Fastimage.

  Types of errors which may occur include:

  - Function execution for unsupported image types eg .tiff
  - Errors occurring during streaming
  - Errors emanating from the :hackney library, eg an
  attempt to access an unauthorized file.
  - Exceeding the maximum number of redirects for a url - the
  max number of redirects is hardcoded as 3.
  - Entering invalid input, Fastimage accepts only valid urls, a
   valid file path or a binary which is an image.

  ## Exception fields

  This exception has the following public fields:
    * `:message` - (atom) the error reason.  This can be a Fastimage
    specific reason such as `:invalid_input` or something emanating
    from the :hackney library such as an unauthorized file error.

  ## Error reasons

  Fastimage specific reasons:

    * `{:unsupported, value}`: may occur when the file type is not supported by Fastimage,
    value can be a url or nil when handling a file or a binary.

    * `:unexpected_end_of_stream_error`: may occur when the end of a stream
    is reached unexpectedly without having determined the image type.

    * `:unexpected_binary_streaming_error`: may occur when an unexpected error
    occurred whilst streaming bytes from a binary.

    * `:unexpected_file_streaming_error`: may occur when an unexpected error
    occurred whilst streaming bytes from a file.

    * `:invalid_input`: may occur when an invalid type is entered as an
    argument to the `size/1` or `type/1` functions. Only a valid url, file path
    or binary. Any other type is considered invalid input.

  :hackney specific reasons:

    * `{:unexpected_http_streaming_error, url}`: may occur when a streaming
    error occurs for the given url.

    * `{:hackney_response_error, {url, status_code, reason}}`: may occur when
    a response error is returned from :hackney. For example, access to the
    given url is forbidden without authorization.

    * `{:max_redirects_exceeded, {url, num_redirects, max_redirects}}`:  may
    occur when the maximum number of redirects has been reached. This is
    currently programmatically hardcoded as 3 redirects.

  unknown reasons:

    `reason` may occur when an unknown error occurs.
  """
  defexception [:reason]
  @supported_types ["gif", "png", "jpg", "bmp"]
  alias Fastimage.Stream

  def exception(reason) do
    %Fastimage.Error{reason: reason}
  end

  def message(%Fastimage.Error{reason: reason}) do
    format_error(reason)
  end

  # private

  defp format_error({:unsupported, %Stream.Acc{source_type: source_type} = acc}) do
    unsupported_error(acc, source_type)
  end

  defp format_error(
         {:unexpected_end_of_stream_error, %Stream.Acc{source_type: source_type} = acc}
       ) do
    end_of_stream_error(acc, source_type)
  end

  defp format_error(:unexpected_binary_streaming_error) do
    binary_streaming_error()
  end

  defp format_error({:unexpected_file_streaming_error, filepath}) do
    file_streaming_error(filepath)
  end

  defp format_error({:unexpected_http_streaming_error, url, hackney_reason}) do
    streaming_error(url, hackney_reason)
  end

  defp format_error({:hackney_response_error, {url, status_code, reason}}) do
    hackney_response_error(url, status_code, reason)
  end

  defp format_error({:max_redirects_exceeded, {url, num_redirects, max_redirects}}) do
    max_redirects_error(url, num_redirects, max_redirects)
  end

  defp format_error(:invalid_input) do
    invalid_input_error()
  end

  defp format_error(reason) do
    unexpected_error(reason)
  end

  defp end_of_stream_error(acc, :binary) do
    """
    An unexpected streaming error has occurred.

    All data in the source has been fetched without
    yet determining an image type.

    Is the source actuallya supported image type?
    """
  end

  defp end_of_stream_error(source, source_type)
       when source_type in [:file, :url] do
    """
    An unexpected streaming error has occurred while
    streaming #{source}.

    All data from #{source} has been fetched without
    determining an image type.

    Is the source actually supported image type?
    """
  end

  defp streaming_error(url, hackney_reason) do
    """
    An unexpected http streaming error has occurred while
    streaming url #{url}.

    Hackney reason:

    #{hackney_reason}
    """
  end

  defp binary_streaming_error do
    """
    An unexpected binary streaming error has occurred while binary streaming.
    """
  end

  defp file_streaming_error(filepath) do
    """
    An unexpected file streaming error has occurred while
    streaming file #{filepath}.
    """
  end

  defp unsupported_error(_acc, :binary) do
    """
    The image type is currently unsupported.

    Only the types #{Enum.join(@supported_types, ", ")}are currently supported by this library.
    """
  end

  defp unsupported_error(acc, :file) do
    extension =
      acc.stream_ref.path
      |> Path.extname()
      |> String.trim_leading(".")

    """
    The image type #{extension} is currently unsupported.

    Only the types #{Enum.join(@supported_types, ", ")}are currently supported by this library.
    """
  end

  defp unsupported_error(acc, :url) do
    """
    The image type is currently unsupported for url #{acc.source}.

    Only the types #{Enum.join(@supported_types, ", ")}are currently supported by this library.
    """
  end

  defp unsupported_error(source, :file) do
    extension = String.trim_leading(source, ".")

    """
    The image type #{extension} is currently unsupported.

    Only the types #{Enum.join(@supported_types, ", ")}are currently supported by this library.
    """
  end

  defp max_redirects_error(url, num_directs, max_redirects) do
    """
    #{num_directs} redirects were executed and the
    max_redirects threshold of #{max_redirects} has been exceeded.

    Is the image url #{url} is valid and reachable?
    """
  end

  defp invalid_input_error do
    """
    An invalid input type was found.

    Fastimage expects input as a valid binary, url or file.
    """
  end

  defp hackney_response_error(url, status_code, reason) do
    """
    An error occurred when attempting get the size or type of the url:

    #{url}.

    ***HTTP status code:***

    #{status_code}.

    ***Reason:***

    #{reason}
    """
  end

  defp unexpected_error(reason) do
    """
    An unexpected error occurred.

    #{inspect(reason)}
    """
  end
end
