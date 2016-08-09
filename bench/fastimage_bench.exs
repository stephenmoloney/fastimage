defmodule FastimageBench do
  use Benchfella

  @jpg_url "https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv/test.jpg"
  @png_url "https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv/test.png"
  @gif_url "https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv/test.gif"
  @bmp_url "https://raw.githubusercontent.com/stephenmoloney/fastimage/master/priv/test.bmp"

  @jpg_file "./priv/test.jpg"
  @png_file "./priv/test.png"
  @gif_file "./priv/test.gif"
  @bmp_file "./priv/test.bmp"


  setup_all do
    Application.ensure_all_started(:fastimage, :temporary)
  end


  bench "Get size of remote jpeg url" do
    Fastimage.size(@jpg_url)
  end
  bench "Get size of local jpeg file" do
    Fastimage.size(@jpg_file)
  end


  bench "Get size of remote png url" do
    Fastimage.size(@png_url)
  end
  bench "Get size of local png file" do
    Fastimage.size(@png_file)
  end


  bench "Get size of remote gif url" do
    Fastimage.size(@gif_url)
  end
  bench "Get size of local gif file" do
    Fastimage.size(@gif_file)
  end


  bench "Get size of remote bmp url" do
    Fastimage.size(@bmp_url)
  end
  bench "Get size of local bmp file" do
    Fastimage.size(@bmp_file)
  end


end