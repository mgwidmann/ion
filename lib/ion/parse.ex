defmodule Ion.Parse do
  @moduledoc """
  """
  use Bitwise, only_operators: true

  @doc """
  """
  def parse(binary)

  def parse(<<0xE0, 1, 0, 0xEA, values::bitstring>>) do
    case parse_document(values) do
      {:ok, [result]} ->
        {:ok, result}

      {:ok, results} ->
        {:ok, results}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def parse(<<0xE0, major, minor, 0xEA, _values::bitstring>>) do
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
    @bool_type,
    @pos_int_type,
    @neg_int_type,
    @float_type,
    @decimal_type,
    @timestamp_type,
    @symbol_type,
    @string_type,
    @clob_type,
    @blob_type,
    @list_type,
    @sexp_type,
    @struct_type,
    @annotation_type
  ]

  # System symbols
  @symbol_ion 1
  @symbol_ion_1_0 2
  @symbol_table 3
  @symbol_name 4
  @symbol_version 5
  @symbol_imports 6
  @symbol_symbols 7
  @symbol_max_id 8
  @symbol_shared_table 9

  @all_system_symbols [
    @symbol_ion,
    @symbol_ion_1_0,
    @symbol_table,
    @symbol_name,
    @symbol_version,
    @symbol_imports,
    @symbol_symbols,
    @symbol_max_id,
    @symbol_shared_table
  ]

  # nil for all types
  defp parse_value(<<type::size(4), @null_type::size(4), 0, values::bitstring>>, result)
       when type in @all_types do
    {:ok, nil, values}
  end

  defp parse_value(<<type::size(4), @null_type::size(4), values::bitstring>>, result)
       when type in @all_types do
    {:ok, nil, values}
  end

  defp parse_value(<<0::size(4), @null_type::size(4), values::bitstring>>, result) do
    {:ok, nil, values}
  end

  defp parse_value(<<@bool_type::size(4), 0::size(4), values::bitstring>>, result) do
    {:ok, false, values}
  end

  defp parse_value(<<@bool_type::size(4), 1::size(4), values::bitstring>>, result) do
    {:ok, true, values}
  end

  defp parse_value(<<@bool_type::size(4), @null_type::size(4), values::bitstring>>, result) do
    {:ok, nil, values}
  end

  defp parse_value(<<@pos_int_type::size(4), 0::size(4), values::bitstring>>, result) do
    {:ok, 0, values}
  end

  defp parse_value(<<@pos_int_type::size(4), 1::size(4), value, values::bitstring>>, result) do
    {:ok, value, values}
  end

  defp parse_value(
         <<@pos_int_type::size(4), l::size(4), value::binary-size(l), values::bitstring>>,
         result
       )
       when l < 14 do
    bytes = l * 8
    # Using binary-size keeps the value as a binary
    <<x::size(bytes)>> = value
    {:ok, x, values}
  end

  defp parse_value(<<@pos_int_type::size(4), l::size(4), length_and_values::bitstring>>, result)
       when l == 14 do
    with {:ok, length, magnitude_and_values} <- parse_varuint(length_and_values),
         <<value::binary-size(length), values::bitstring>> <- magnitude_and_values do
      bytes = length * 8
      # Using binary-size keeps the value as a binary
      <<x::size(bytes)>> = value
      {:ok, x, values}
    else
      e -> parse_value_error(e)
    end
  end

  defp parse_value(<<@neg_int_type::size(4), 0::size(4), values::bitstring>>, result) do
    {:error, "Encountered illegal negative 0 with #{byte_size(values)} bytes remaining to parse"}
  end

  defp parse_value(<<@neg_int_type::size(4), 1::size(4), value, values::bitstring>>, result) do
    {:ok, -value, values}
  end

  defp parse_value(
         <<@neg_int_type::size(4), l::size(4), value::binary-size(l), values::bitstring>>,
         result
       )
       when l < 14 do
    bytes = l * 8
    <<x::size(bytes)>> = value
    {:ok, -x, values}
  end

  defp parse_value(<<@neg_int_type::size(4), l::size(4), length_and_values::bitstring>>, result)
       when l == 14 do
    with {:ok, length, magnitude_and_values} <- parse_varuint(length_and_values),
         <<value::binary-size(length), values::bitstring>> <- magnitude_and_values do
      bytes = length * 8
      # Using binary-size keeps the value as a binary
      <<x::size(bytes)>> = value
      {:ok, -x, values}
    else
      e -> parse_value_error(e)
    end
  end

  defp parse_value(<<@float_type::size(4), 0::size(4), values::bitstring>>, result) do
    {:ok, 0.0, values}
  end

  # Infinity
  defp parse_value(
         <<@float_type::size(4), 8::size(4), 127, 240, 0, 0, 0, 0, 0, 0, values::bitstring>>,
         result
       ) do
    {:ok, :infinity, values}
  end

  # Neg Infinity
  defp parse_value(
         <<@float_type::size(4), 8::size(4), 255, 240, 0, 0, 0, 0, 0, 0, values::bitstring>>,
         result
       ) do
    {:ok, :neg_infinity, values}
  end

  # NaN
  defp parse_value(
         <<@float_type::size(4), 8::size(4), 127, 248, 0, 0, 0, 0, 0, 0, values::bitstring>>,
         result
       ) do
    {:ok, :nan, values}
  end

  defp parse_value(
         <<@float_type::size(4), l::size(4), value::size(l)-unit(8)-float, values::bitstring>>,
         result
       ) do
    {:ok, value, values}
  end

  defp parse_value(<<@decimal_type::size(4), 0::size(4), values::bitstring>>, result) do
    {:ok, 0.0, values}
  end

  defp parse_value(
         <<@decimal_type::size(4), l::size(4), exponent_and_coefficient::binary-size(l), values::bitstring>>,
         result
       )
       when l == 2 do
    with {:ok, exponent, coeff} <- parse_int(exponent_and_coefficient),
         {:ok, coefficient, <<>>} <- parse_int(coeff) do
      {:ok, coefficient * :math.pow(10, exponent), values}
    else
      e -> parse_value_error(e)
    end
  end

  defp parse_value(
         <<@decimal_type::size(4), l::size(4), exponent_and_coefficient::binary-size(l), values::bitstring>>,
         result
       )
       when l > 2 and l < 14 do
    exponent_and_coefficient(exponent_and_coefficient, values)
  end

  defp parse_value(<<@decimal_type::size(4), l::size(4), length_and_values::bitstring>>, result)
       when l == 14 do
    with {:ok, length, values} <- parse_varint(length_and_values),
         <<exponent_and_coefficient::size(length)-unit(8), values::bitstring>> <- values do
      exponent_and_coefficient(<<exponent_and_coefficient::size(length)-unit(8)>>, values)
    else
      e -> parse_value_error(e)
    end
  end

  defp parse_value(
         <<@timestamp_type::size(4), l::size(4), value::size(l)-unit(8), values::bitstring>>,
         result
       ) do
    IO.inspect(l)
    IO.inspect(value, base: :hex)
    IO.inspect(values, base: :hex)
  end

  defp parse_value(<<@struct_type::size(4), 0::size(4), values::bitstring>>, result) do
    {:ok, %{}, values}
  end

  defp parse_value(
         <<@struct_type::size(4), l::size(4), value::size(l)-unit(8)-binary, values::bitstring>>,
         result
       )
       when l != 14 do
    {:ok, value, values}
  end

  defp parse_value(
         <<@annotation_type::size(4), l::size(4), annotation::size(l)-unit(8)-binary, values::bitstring>>,
         result
       )
       when l != 14 do
    with {:ok, annotation_length, annot_and_value} <- parse_varuint(annotation) do
      IO.puts("#{annotation_length} separating annot and values #{inspect(annot_and_value, base: :hex)}")

      {annots, value} =
        Enum.reduce(0..(annotation_length - 1), {[], annot_and_value}, fn _, acc ->
          IO.puts("Reducing with #{inspect(acc, base: :hex)}")

          with {annots, annot_and_value} <- acc,
               {:ok, annot, rest} <- parse_varuint(annot_and_value) do
            {[annot | annots], rest}
          else
            e -> parse_value_error(e)
          end
        end)

      {:ok, {@annotation_type, annots, value}, values}
    else
      e -> parse_value_error(e)
    end
  end

  ### VarInt ###
  defp parse_varint(binary, sign \\ nil, acc \\ nil)

  defp parse_varint(<<0::size(1), sign::size(1), value::size(6), values::bitstring>>, nil, nil) do
    parse_varint(values, sign, value)
  end

  defp parse_varint(<<0::size(1), value::size(7), values::bitstring>>, sign, total) do
    parse_varint(values, sign, value + total)
  end

  defp parse_varint(<<1::size(1), sign::size(1), value::size(6), values::bitstring>>, nil, nil) do
    value = if(sign == 0, do: value, else: -value)
    {:ok, value, values}
  end

  defp parse_varint(<<1::size(1), value::size(7), values::bitstring>>, sign, total) do
    value = if(sign == 0, do: value + total, else: -(value + total))
    {:ok, value, values}
  end

  defp parse_varint(binary, _, _), do: {:error, binary}

  ### VarUInt ###
  defp parse_varuint(binary, acc \\ nil)

  defp parse_varuint(<<0::size(1), value::size(7), values::bitstring>>, nil) do
    parse_varuint(values, value)
  end

  defp parse_varuint(<<0::size(1), value::size(7), values::bitstring>>, total) do
    parse_varuint(values, value + total)
  end

  defp parse_varuint(<<1::size(1), value::size(7), values::bitstring>>, nil) do
    {:ok, value, values}
  end

  defp parse_varuint(<<1::size(1), value::size(7), values::bitstring>>, total) do
    {:ok, value + total, values}
  end

  # defp parse_varuint(binary, _), do: {:error, binary}

  defp parse_varuints(varuints, count, acc \\ [])
  defp parse_varuints(rest, 0, acc), do: {:ok, Enum.reverse(acc), rest}

  defp parse_varuints(varuints, count, acc) do
    {:ok, value, varuints} = parse_varuint(varuints)
    parse_varuints(varuints, count - 1, [value | acc])
  end

  defp parse_int(<<sign::size(1), int::size(7), values::bitstring>>) do
    {:ok, if(sign == 0, do: int, else: -int), values}
  end

  defp parse_value_error({:ok, _, binary}) do
    {:error, "Error found: #{inspect(binary, base: :hex)}"}
  end

  defp parse_value_error({:error, binary}) do
    {:error, "Error found: #{inspect(binary, base: :hex)}"}
  end

  defp parse_value_error(binary) do
    {:error, "Error found: #{inspect(binary, base: :hex)}"}
  end

  defp exponent_and_coefficient(exponent_and_coefficient, values) do
    with {:ok, exponent, coeff} <- parse_varint(exponent_and_coefficient),
         coefficient_size <- byte_size(coeff),
         # Doesn't work correctly for negatives, -signed uses inverse negatives instead of a sign bit
         # << coefficient :: size(coefficient_size)-unit(8)-signed >> <- coeff do
         coefficient_size <- coefficient_size * 8 - 1,
         <<sign::size(1), coefficient::size(coefficient_size)>> <- coeff,
         coefficient <- if(sign == 0, do: coefficient, else: -coefficient) do
      {:ok, coefficient * :math.pow(10, exponent), values}
    else
      e -> parse_value_error(e)
    end
  end

  defp parse_metadata(values) do
    IO.puts("parse_metadata #{inspect(values)}")

    with {:ok, first_result, values} <- parse_value(values, %Ion.Metadata{}) do
      case first_result do
        {@annotation_type, annots, value} ->
          IO.puts("got annotation of #{inspect(annots, base: :hex)} with value #{inspect(value, base: :hex)}")
          {:ok, struct, <<>>} = parse_value(value, %Ion.Metadata{})
          {:ok, Enum.reduce(annots, %Ion.Metadata{}, &parse_metadata(&1, &2, struct)), values, []}

        _ ->
          IO.puts("Got someting else #{inspect(first_result)}")
          {:ok, %Ion.Metadata{}, values, [first_result]}
      end
    end
  end

  defp parse_metadata(@symbol_table, metadata, <<1::size(1), @symbol_symbols::size(7), value::bitstring>>) do
    IO.puts("Got symbol table: #{inspect(metadata)} with value #{inspect(value, base: :hex)}")
    nil
  end

  defp parse_document(document) do
    IO.puts("parsing document")

    with {:ok, metadata, values, result} <- parse_metadata(document) do
      parse_values(values, metadata, result)
    else
      e -> e
    end
  end

  defp parse_values(<<>>, _metadata, result) do
    {:ok, Enum.reverse(result)}
  end

  defp parse_values(values, metadata, result) do
    with {:ok, value, values} <- parse_value(values, metadata) do
      parse_values(values, metadata, [value | result])
    else
      e -> e
    end
  end
end
