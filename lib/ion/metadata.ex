defmodule Ion.Metadata do
  defstruct symbols: %{}
  @type t(symbols) :: %Ion.Metadata{symbols: symbols}
  @type t :: %Ion.Metadata{symbols: %{pos_integer => atom}}
end
