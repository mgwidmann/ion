defmodule Ion do
  @moduledoc """
  """

  defdelegate parse(binary), to: Ion.Parse
  defdelegate parse_file(filename), to: Ion.Parse
end
