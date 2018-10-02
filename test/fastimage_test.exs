defmodule FastimageTest do
  use ExUnit.Case, async: true
  doctest Fastimage

  @expected_size %Fastimage.Dimensions{width: 283, height: 142}

  @fastimage_task_timeout 3_000

  @gh_raw_url "https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv/"
  @jpg_url "#{@gh_raw_url}test.jpg"
  @jpg_url_with_query "https://avatars0.githubusercontent.com/u/12668653?v=2&s=40"
  @jpg_with_redirect "http://seanmoloney.com/images/cover1.jpg"
  @png_url "#{@gh_raw_url}test.png"
  @gif_url "#{@gh_raw_url}test.gif"
  @bmp_url "#{@gh_raw_url}test.bmp"
  @webp_vp8l_url "#{@gh_raw_url}webp_vp8l.webp"
  @webp_vp8_url "#{@gh_raw_url}webp_vp8.webp"
  @webp_vp8x_url "#{@gh_raw_url}webp_vp8x.webp"

  @jpg_file "./priv/test.jpg"
  @png_file "./priv/test.png"
  @gif_file "./priv/test.gif"
  @bmp_file "./priv/test.bmp"
  @webp_vp8_file "./priv/test_vp8.webp"
  @webp_vp8x_file "./priv/test_vp8x.webp"
  @webp_vp8l_file "./priv/test_vp8l.webp"

  @jpg_binary File.read!(@jpg_file)
  @png_binary File.read!(@png_file)
  @gif_binary File.read!(@gif_file)
  @bmp_binary File.read!(@bmp_file)
  @webp_vp8_binary File.read!(@webp_vp8_file)
  @webp_vp8x_binary File.read!(@webp_vp8x_file)
  @webp_vp8l_binary File.read!(@webp_vp8l_file)

  @tag :jpeg
  test "Get type and size of remote jpeg url" do
    actual_type = Fastimage.type(@jpg_url)
    actual_size = Fastimage.size(@jpg_url)

    expected_type = {:ok, :jpeg}
    expected_size = {:ok, @expected_size}

    assert(actual_type == expected_type)
    assert(actual_size == expected_size)
  end

  test "Get type and size of remote image with query in url" do
    expected_size = %Fastimage.Dimensions{width: 40, height: 40}
    assert_size_and_type(@jpg_url_with_query, expected_size, :jpeg)
  end

  test "Get type and size of local jpeg file" do
    assert_size_and_type(@jpg_file, @expected_size, :jpeg)
  end

  test "Get type and size of a binary jpeg object" do
    assert_size_and_type(@jpg_binary, @expected_size, :jpeg)
  end

  test "Get type and size of remote png url" do
    assert_size_and_type(@png_url, @expected_size, :png)
  end

  test "Get type and size of local png file" do
    assert_size_and_type(@png_file, @expected_size, :png)
  end

  test "Get type and size of binary png object" do
    assert_size_and_type(@png_binary, @expected_size, :png)
  end

  test "Get type and size of remote gif url" do
    assert_size_and_type(@gif_url, @expected_size, :gif)
  end

  test "Get type and size of local gif file" do
    assert_size_and_type(@gif_file, @expected_size, :gif)
  end

  test "Get type and size of a binary gif object" do
    assert_size_and_type(@gif_binary, @expected_size, :gif)
  end

  test "Get type and size of remote bmp url" do
    assert_size_and_type(@bmp_url, @expected_size, :bmp)
  end

  test "Get type and size of local bmp file" do
    assert_size_and_type(@bmp_file, @expected_size, :bmp)
  end

  test "Get type and size of a binary bmp object" do
    assert_size_and_type(@bmp_binary, @expected_size, :bmp)
  end

  test "Get type and size of remote webp vp8 url" do
    assert_size_and_type(@webp_vp8_url, @expected_size, :webp)
  end

  test "Get type and size of local webp vp8 file" do
    assert_size_and_type(@webp_vp8_file, @expected_size, :webp)
  end

  test "Get type and size of a binary webp vp8 object" do
    assert_size_and_type(@webp_vp8_binary, @expected_size, :webp)
  end

  test "Get type and size of remote webp vp8l url" do
    assert_size_and_type(@webp_vp8l_url, @expected_size, :webp)
  end

  test "Get type and size of local webp vp8l file" do
    assert_size_and_type(@webp_vp8l_file, @expected_size, :webp)
  end

  test "Get type and size of a binary webp vp8l object" do
    assert_size_and_type(@webp_vp8l_binary, @expected_size, :webp)
  end

  test "Get type and size of remote webp vp8x url" do
    assert_size_and_type(@webp_vp8x_url, @expected_size, :webp)
  end

  test "Get type and size of local webp vp8x file" do
    assert_size_and_type(@webp_vp8x_file, @expected_size, :webp)
  end

  test "Get type and size of a binary webp vp8x object" do
    assert_size_and_type(@webp_vp8x_binary, @expected_size, :webp)
  end

  test "Get the size of multiple image files synchronously" do
    n = :rand.uniform(20)

    list_results =
      n
      |> list()
      |> Enum.map(fn image -> {:ok, Kernel.elem(Fastimage.size(image), 1)} end)

    assert list_results == list_expected_results(n)
  end

  test "Get the size of multiple image files asynchronously" do
    n = :rand.uniform(20)

    list_results =
      n
      |> list()
      |> Enum.map(&Task.async(Fastimage, :size, [&1]))
      |> Enum.map(&handle_task/1)

    assert list_results == list_expected_results(n)
  end

  test "Get the size of an image behind a redirect" do
    actual_size = Fastimage.size(@jpg_with_redirect)
    expected_size = {:ok, %Fastimage.Dimensions{width: 1200, height: 1230}}

    assert(actual_size == expected_size)
  end

  # private

  defp assert_size_and_type(input, expected_size, expected_type) do
    actual_type = Fastimage.type(input)
    actual_size = Fastimage.size(input)

    assert actual_type == {:ok, expected_type}
    assert actual_size == {:ok, expected_size}
  end

  defp list(n) do
    [
      @jpg_url,
      @jpg_url_with_query,
      @jpg_with_redirect,
      @png_url,
      @gif_url,
      @bmp_url,
      @webp_vp8_url,
      @webp_vp8x_url,
      @webp_vp8l_url
    ]
    |> Stream.cycle()
    |> Enum.take(n)
  end

  # order should match list/1
  defp list_expected_results(n) do
    [
      @expected_size,
      %Fastimage.Dimensions{width: 40, height: 40},
      %Fastimage.Dimensions{width: 1200, height: 1230},
      @expected_size,
      @expected_size,
      @expected_size,
      @expected_size,
      @expected_size,
      @expected_size
    ]
    |> Stream.cycle()
    |> Stream.flat_map(&[{:ok, &1}])
    |> Enum.take(n)
  end

  defp handle_task(task) do
    with {:ok, {:error, error}} <-
           Task.yield(task, @fastimage_task_timeout) || Task.shutdown(task) do
      {:error, error}
    else
      {:ok, val} ->
        val

      other ->
        other
    end
  end
end
