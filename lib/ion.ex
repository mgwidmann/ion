defmodule Ion do
  @moduledoc """
  """

  @spec parse(binary | Ion.Parse.ion_binary) :: any
  defdelegate parse(binary), to: Ion.Parse
  @spec parse_file(binary) :: any
  defdelegate parse_file(filename), to: Ion.Parse
end
