defmodule FastimageTest do
  use ExUnit.Case, async: true
  doctest Fastimage

  @expected_size %Fastimage.Dimensions{width: 283, height: 142}
  @fastimage_task_timeout 3_000
  @jpg_url_with_query "https://avatars0.githubusercontent.com/u/12668653?v=2&s=40"
  @jpg_with_redirect "http://seanmoloney.com/images/cover1.jpg"
  @gh_raw_url "https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv"

  test "Get type and size of jpeg images" do
    for type <- ~w(file url binary)a do
      type
      |> image_fixture("test.jpg")
      |> assert_size_and_type(@expected_size, :jpeg)
    end
  end

  test "Get type and size of remote image with query in url" do
    expected_size = %Fastimage.Dimensions{width: 40, height: 40}
    assert_size_and_type(@jpg_url_with_query, expected_size, :jpeg)
  end

  test "Get the size of an image behind a redirect" do
    actual_size = Fastimage.size(@jpg_with_redirect)
    expected_size = {:ok, %Fastimage.Dimensions{width: 1200, height: 1230}}

    assert(actual_size == expected_size)
  end

  test "Get type and size of png images" do
    for type <- ~w(file url binary)a do
      type
      |> image_fixture("test.png")
      |> assert_size_and_type(@expected_size, :png)
    end
  end

  test "Get type and size of gif images" do
    for type <- ~w(file url binary)a do
      type
      |> image_fixture("test.gif")
      |> assert_size_and_type(@expected_size, :gif)
    end
  end

  test "Get type and size of bmp images" do
    for type <- ~w(file url binary)a do
      type
      |> image_fixture("test.bmp")
      |> assert_size_and_type(@expected_size, :bmp)
    end
  end

  test "Get type and size of webp lossy images" do
    for type <- ~w(file url binary)a do
      type
      |> image_fixture("test_lossy.webp")
      |> assert_size_and_type(@expected_size, :webp)
    end
  end

  test "Get type and size of webp lossless images" do
    for type <- ~w(file url binary)a do
      type
      |> image_fixture("test_lossless.webp")
      |> assert_size_and_type(@expected_size, :webp)
    end
  end

  test "Get type and size of webp extended images" do
    for type <- ~w(file url binary)a do
      type
      |> image_fixture("test_extended.webp")
      |> assert_size_and_type(@expected_size, :webp)
    end
  end

  test "Get the size of multiple image urls synchronously" do
    n = :rand.uniform(20)

    list_results =
      n
      |> list()
      |> Enum.map(fn image -> {:ok, Kernel.elem(Fastimage.size(image), 1)} end)

    assert list_results == list_expected_results(n)
  end

  test "Get the size of multiple image urls asynchronously" do
    n = :rand.uniform(20)

    list_results =
      n
      |> list()
      |> Enum.map(&Task.async(Fastimage, :size, [&1]))
      |> Enum.map(&handle_task/1)

    assert list_results == list_expected_results(n)
  end

  test "403 on remote file request returns error tuple" do
    assert {:error, %Fastimage.Error{}} = Fastimage.type("http://httpstat.us/403")
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
      image_fixture(:url, "test.jpg"),
      @jpg_url_with_query,
      @jpg_with_redirect,
      image_fixture(:url, "test.png"),
      image_fixture(:url, "test.gif"),
      image_fixture(:url, "test.bmp"),
      image_fixture(:url, "test_lossy.webp"),
      image_fixture(:url, "test_extended.webp"),
      image_fixture(:url, "test_lossless.webp")
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

  defp image_fixture(:url, name) do
    "#{@gh_raw_url}/#{name}"
  end

  defp image_fixture(:file, name) do
    "./priv/#{name}"
  end

  defp image_fixture(:binary, name) do
    File.read!("./priv/#{name}")
  end
end
