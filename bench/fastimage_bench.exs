defmodule FastimageBench do
  use Benchfella

  @gh_raw_url "https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv"

  @jpg_url "#{@gh_raw_url}/test.jpg"
  @png_url "#{@gh_raw_url}/test.png"
  @gif_url "#{@gh_raw_url}/test.gif"
  @bmp_url "#{@gh_raw_url}/test.bmp"
  @webp_vp8_url "#{@gh_raw_url}/test_lossy.webp"
  @webp_vp8l_url "#{@gh_raw_url}/test_lossless.webp"
  @webp_vp8x_url "#{@gh_raw_url}/test_extended.webp"

  @jpg_file "./priv/test.jpg"
  @png_file "./priv/test.png"
  @gif_file "./priv/test.gif"
  @bmp_file "./priv/test.bmp"
  @webp_vp8_file "./priv/test_lossy.webp"
  @webp_vp8l_file "./priv/test_lossless.webp"
  @webp_vp8x_file "./priv/test_extended.webp"

  setup_all do
    Application.ensure_all_started(:fastimage, :temporary)
  end

  bench "Get size of a jpeg url" do
    Fastimage.size(@jpg_url)
  end

  bench "Get size of a jpeg file" do
    Fastimage.size(@jpg_file)
  end

  bench "Get size of a png url" do
    Fastimage.size(@png_url)
  end

  bench "Get size of a png file" do
    Fastimage.size(@png_file)
  end

  bench "Get size of a gif url" do
    Fastimage.size(@gif_url)
  end

  bench "Get size of a gif file" do
    Fastimage.size(@gif_file)
  end

  bench "Get size of a bmp url" do
    Fastimage.size(@bmp_url)
  end

  bench "Get size of a bmp file" do
    Fastimage.size(@bmp_file)
  end

  bench "Get size of web vp8 url" do
    Fastimage.size(@webp_vp8_url)
  end

  bench "Get size of a web vp8x file" do
    Fastimage.size(@webp_vp8x_file)
  end

  bench "Get size of a web vp8l url" do
    Fastimage.size(@webp_vp8l_url)
  end

  bench "Get size of a web vp8l file" do
    Fastimage.size(@webp_vp8l_file)
  end

  bench "Get size of a web vp8 file" do
    Fastimage.size(@webp_vp8_file)
  end

  bench "Get size of a web vp8x url" do
    Fastimage.size(@webp_vp8x_url)
  end
end
