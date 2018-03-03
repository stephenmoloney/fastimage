defmodule Fastimage.Dimensions do
  @moduledoc false
  alias __MODULE__

  defstruct width: nil,
            height: nil

  @type t :: %Dimensions{
          width: integer() | nil,
          height: integer() | nil
        }
end
