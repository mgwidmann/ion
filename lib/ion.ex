defmodule Ion do
  @moduledoc """
  """

  @spec parse(binary | Ion.Parse.Binary.ion_binary) :: any
  defdelegate parse(binary), to: Ion.Parse.Binary
  @spec parse_file(binary) :: any
  defdelegate parse_file(filename), to: Ion.Parse.Binary
end
