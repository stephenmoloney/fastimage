defmodule FastimageTest do
  use ExUnit.Case
  @expected_size %{width: 283, height: 142}

  @jpg_url "https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv/test.jpg"
  @png_url "https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv/test.png"
  @gif_url "https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv/test.gif"
  @bmp_url "https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv/test.bmp"

  @jpg_file "./priv/test.jpg"
  @png_file "./priv/test.png"
  @gif_file "./priv/test.gif"
  @bmp_file "./priv/test.bmp"


  test "Get type and size of remote jpeg url" do
    assert(Fastimage.type(@jpg_url) == "jpeg")
    assert(Fastimage.size(@jpg_url) == @expected_size)
  end
  test "Get type and size of local jpeg file" do
    assert(Fastimage.type(@jpg_file) == "jpeg")
    assert(Fastimage.size(@jpg_file) == @expected_size)
  end


  test "Get type and size of remote png url" do
    assert(Fastimage.type(@png_url) == "png")
    assert(Fastimage.size(@png_url) == @expected_size)
  end
  test "Get type and size of local png file" do
    assert(Fastimage.type(@png_file) == "png")
    assert(Fastimage.size(@png_file) == @expected_size)
  end


  test "Get type and size of remote gif url" do
    assert(Fastimage.type(@gif_url) == "gif")
    assert(Fastimage.size(@gif_url) == @expected_size)
  end
  test "Get type and size of local gif file" do
    assert(Fastimage.type(@gif_file) == "gif")
    assert(Fastimage.size(@gif_file) == @expected_size)
  end


  test "Get type and size of remote bmp url" do
    assert(Fastimage.type(@bmp_url) == "bmp")
    assert(Fastimage.size(@bmp_url) == @expected_size)
  end
  test "Get type and size of local bmp file" do
    assert(Fastimage.type(@bmp_file) == "bmp")
    assert(Fastimage.size(@bmp_file) == @expected_size)
  end

end