defmodule Ion.Parse do
  @moduledoc """
  """
  use Bitwise, only_operators: true

  @doc """
  """
  def parse(binary)
  def parse(<< 0xE0, 1, 0, 0xEA, values :: bitstring >>) do
    case parse_values(values) do
      {:ok, value, <<>>} ->
        {:ok, value}
      {:ok, _value, remaining} ->
        {:error, "Invalid file, found #{byte_size(remaining)} bytes remaining after parsing completed."}
      {:error, reason} ->
        {:error, reason}
    end
  end
  def parse(<< 0xE0, major, minor, 0xEA, _values :: bitstring >>) do
    {:error, "Unsupported Ion version #{major}.#{minor}"}
  end

  @doc """
  """
  def parse_file(filename) do
    
  end

  @bool_type 1
  @pos_int_type 2
  @neg_int_type 3
  @float_type 4
  @decimal_type 5
  @timestamp_type 6
  @symbol_type 7
  @string_type 8
  @clob_type 9
  @blob_type 10
  @list_type 11
  @sexp_type 12
  @struct_type 13
  @annotation_type 14
  @null_type 15

  @all_types [
    @bool_type, @pos_int_type, @neg_int_type,
    @float_type, @decimal_type, @timestamp_type,
    @symbol_type, @string_type, @clob_type,
    @blob_type, @list_type, @sexp_type,
    @struct_type, @annotation_type
  ]

  # nil for all types
  defp parse_value(<< type :: size(4), 15 :: size(4), 0, values :: bitstring>>) when type in @all_types do
    {:ok, nil, values}
  end
  defp parse_value(<< type :: size(4), 15 :: size(4), values :: bitstring>>) when type in @all_types do
    {:ok, nil, values}
  end
  defp parse_value(<< 0 :: size(4), @null_type :: size(4), values :: bitstring>>) do
    {:ok, nil, values}
  end

  defp parse_value(<< @bool_type :: size(4), 0 :: size(4), values :: bitstring>>) do
    {:ok, false, values}
  end
  defp parse_value(<< @bool_type :: size(4), 1 :: size(4), values :: bitstring>>) do
    {:ok, true, values}
  end
  defp parse_value(<< @bool_type :: size(4), 15 :: size(4), values :: bitstring>>) do
    {:ok, nil, values}
  end

  defp parse_value(<< @pos_int_type :: size(4), 0 :: size(4), values :: bitstring>>) do
    {:ok, 0, values}
  end
  defp parse_value(<< @pos_int_type :: size(4), 1 :: size(4), value, values :: bitstring>>) do
    {:ok, value, values}
  end
  defp parse_value(<< @pos_int_type :: size(4), l :: size(4), value :: binary-size(l), values :: bitstring>>) do
    bytes = l * 8
    <<x :: size(bytes)>> = value
    {:ok, x, values}
  end

  defp parse_value(<< @neg_int_type :: size(4), 0 :: size(4), values :: bitstring>>) do
    {:error, "Encountered illegal negative 0 with #{byte_size(values)} bytes remaining to parse"}
  end
  defp parse_value(<< @neg_int_type :: size(4), 1 :: size(4), value, values :: bitstring>>) do
    {:ok, -value, values}
  end
  defp parse_value(<< @neg_int_type :: size(4), l :: size(4), value :: binary-size(l), values :: bitstring>>) do
    bytes = l * 8
    <<x :: size(bytes)>> = value
    {:ok, -x, values}
  end

  defp parse_value(<< @float_type :: size(4), 0 :: size(4), values :: bitstring>>) do
    {:ok, 0.0, values}
  end
  # Infinity
  defp parse_value(<< @float_type :: size(4), 8 :: size(4), 127, 240, 0, 0, 0, 0, 0, 0, values :: bitstring>>) do
    {:ok, :infinity, values}
  end
  # Neg Infinity
  defp parse_value(<< @float_type :: size(4), 8 :: size(4), 255, 240, 0, 0, 0, 0, 0, 0, values :: bitstring>>) do
    {:ok, :neg_infinity, values}
  end
  # NaN
  defp parse_value(<< @float_type :: size(4), 8 :: size(4), 127, 248, 0, 0, 0, 0, 0, 0, values :: bitstring>>) do
    {:ok, :nan, values}
  end
  defp parse_value(<< @float_type :: size(4), l :: size(4), value :: size(l)-unit(8)-float, values :: bitstring>>) do
    {:ok, value, values}
  end

  defp parse_value(<< @decimal_type :: size(4), 0 :: size(4), values :: bitstring>>) do
    {:ok, 0.0, values}
  end
  defp parse_value(<< @decimal_type :: size(4), l :: size(4), exponent_and_coefficient :: binary-size(l), values :: bitstring>>) when l == 2 do
    with {:ok, exponent, coeff} <- parse_int(exponent_and_coefficient),
         {:ok, coefficient, <<>>} <- parse_int(coeff) do
      {:ok, coefficient * :math.pow(10, exponent), values}
    else
      e -> parse_value_error(e)
    end
  end
  defp parse_value(<< @decimal_type :: size(4), l :: size(4), exponent_and_coefficient :: binary-size(l), values :: bitstring>>) do
    with {:ok, exponent, coeff} <- parse_varint(exponent_and_coefficient),
         coefficient_size <- byte_size(coeff),
         # Doesn't work correctly for negatives, -signed uses inverse negatives instead of a sign bit
         # << coefficient :: size(coefficient_size)-unit(8)-signed >> <- coeff do
         coefficient_size <- coefficient_size * 8 - 1,
         << sign :: size(1), coefficient :: size(coefficient_size) >> <- coeff,
         coefficient <- if(sign == 0, do: coefficient, else: -coefficient) do
      {:ok, coefficient * :math.pow(10, exponent), values}
    else
      e -> parse_value_error(e)
    end
  end

  defp parse_value(<< @annotation_type :: size(4), l :: size(4), values :: bitstring>>) do
    with {:ok, length, << _excess :: binary-size(l), values :: bitstring >>} <- parse_varuint(values), # VarUInt length header
      {:ok, annot_length, annot} <- parse_varint(values) do
      {:ok, annot, values}
    end
  end

  ### VarInt ###
  defp parse_varint(binary, sign \\ nil, acc \\ nil)
  defp parse_varint(<< 0 :: size(1), sign :: size(1), value :: size(6), values :: bitstring>>, nil, nil) do
    parse_varint(values, sign, value)
  end
  defp parse_varint(<< 0 :: size(1), value :: size(7), values :: bitstring>>, sign, total) do
    parse_varint(values, sign, value + total)
  end
  defp parse_varint(<< 1 :: size(1), sign :: size(1), value :: size(6), values :: bitstring>>, nil, nil) do
    value = if(sign == 0, do: value, else: -value)
    {:ok, value, values}
  end
  defp parse_varint(<< 1 :: size(1), value :: size(7), values :: bitstring>>, sign, total) do
    value = if(sign == 0, do: value + total, else: -(value + total))
    {:ok, value, values}
  end
  defp parse_varint(binary, _, _), do: {:error, binary}

  ### VarUInt ###
  defp parse_varuint(binary, acc \\ nil)
  defp parse_varuint(<< 0 :: size(1), value :: size(7), values :: bitstring>>, nil) do
    parse_varuint(values, value)
  end
  defp parse_varuint(<< 0 :: size(1), value :: size(7), values :: bitstring>>, total) do
    parse_varuint(values, value + total)
  end
  defp parse_varuint(<< 1 :: size(1), value :: size(7), values :: bitstring>>, nil) do
    {:ok, value, values}
  end
  defp parse_varuint(<< 1 :: size(1), value :: size(7), values :: bitstring>>, total) do
    {:ok, value + total, values}
  end
  defp parse_varuint(binary, _), do: {:error, binary}

  defp parse_varuints(varuints, count, acc \\ [])
  defp parse_varuints(rest, 0, acc), do: {:ok, Enum.reverse(acc), rest}
  defp parse_varuints(varuints, count, acc) do
    {:ok, value, varuints} = parse_varuint(varuints)
    parse_varuints(varuints, count - 1, [value | acc])
  end

  def parse_int(<< sign :: size(1), int :: size(7), values :: bitstring >>) do
    {:ok, if(sign == 0, do: int, else: -int), values}
  end

  def parse_value_error({:ok, _, binary}) do
    {:error, "Expected to find VarInt coefficient but instead found: #{inspect(binary)}"}
  end
  def parse_value_error({:error, binary}) do
    {:error, "Expected to find VarInt exponent but instead found: #{inspect(binary)}"}
  end
  def parse_value_error(binary) do
    {:error, "Error converting Int found: #{inspect(binary)}"}
  end

  defp parse_values(values) do
    parse_value(values)
  end
end