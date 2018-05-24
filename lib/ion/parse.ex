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
  defp parse_value(<<type::size(4), @null_type::size(4), 0, values::bitstring>>, _metadata) when type in @all_types do
    {:ok, nil, values}
  end

  defp parse_value(<<type::size(4), @null_type::size(4), values::bitstring>>, _metadata) when type in @all_types do
    {:ok, nil, values}
  end

  defp parse_value(<<0::size(4), @null_type::size(4), values::bitstring>>, _metadata) do
    {:ok, nil, values}
  end

  defp parse_value(<<@bool_type::size(4), 0::size(4), values::bitstring>>, _metadata) do
    {:ok, false, values}
  end

  defp parse_value(<<@bool_type::size(4), 1::size(4), values::bitstring>>, _metadata) do
    {:ok, true, values}
  end

  defp parse_value(<<@bool_type::size(4), @null_type::size(4), values::bitstring>>, _metadata) do
    {:ok, nil, values}
  end

  defp parse_value(<<@pos_int_type::size(4), 0::size(4), values::bitstring>>, _metadata) do
    {:ok, 0, values}
  end

  defp parse_value(<<@pos_int_type::size(4), 1::size(4), value, values::bitstring>>, _metadata) do
    {:ok, value, values}
  end

  defp parse_value(<<@pos_int_type::size(4), l::size(4), value::binary-size(l), values::bitstring>>, _metadata) when l < 14 do
    bytes = l * 8
    # Using binary-size keeps the value as a binary
    <<x::size(bytes)>> = value
    {:ok, x, values}
  end

  defp parse_value(<<@pos_int_type::size(4), l::size(4), length_and_values::bitstring>>, _metadata) when l == 14 do
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

  defp parse_value(<<@neg_int_type::size(4), 0::size(4), values::bitstring>>, _metadata) do
    {:error, "Encountered illegal negative 0 with #{byte_size(values)} bytes remaining to parse"}
  end

  defp parse_value(<<@neg_int_type::size(4), 1::size(4), value, values::bitstring>>, _metadata) do
    {:ok, -value, values}
  end

  defp parse_value(<<@neg_int_type::size(4), l::size(4), value::binary-size(l), values::bitstring>>, _metadata) when l < 14 do
    bytes = l * 8
    <<x::size(bytes)>> = value
    {:ok, -x, values}
  end

  defp parse_value(<<@neg_int_type::size(4), l::size(4), length_and_values::bitstring>>, _metadata) when l == 14 do
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

  defp parse_value(<<@float_type::size(4), 0::size(4), values::bitstring>>, _metadata) do
    {:ok, 0.0, values}
  end

  # Infinity
  defp parse_value(<<@float_type::size(4), 8::size(4), 127, 240, 0, 0, 0, 0, 0, 0, values::bitstring>>, _metadata) do
    {:ok, :infinity, values}
  end

  # Neg Infinity
  defp parse_value(<<@float_type::size(4), 8::size(4), 255, 240, 0, 0, 0, 0, 0, 0, values::bitstring>>, _metadata) do
    {:ok, :neg_infinity, values}
  end

  # NaN
  defp parse_value(<<@float_type::size(4), 8::size(4), 127, 248, 0, 0, 0, 0, 0, 0, values::bitstring>>, _metadata) do
    {:ok, :nan, values}
  end

  defp parse_value(<<@float_type::size(4), l::size(4), value::size(l)-unit(8)-float, values::bitstring>>, _metadata) do
    {:ok, value, values}
  end

  defp parse_value(<<@decimal_type::size(4), 0::size(4), values::bitstring>>, _metadata) do
    {:ok, 0.0, values}
  end

  defp parse_value(<<@decimal_type::size(4), l::size(4), exponent_and_coefficient::binary-size(l), values::bitstring>>, _metadata) when l == 2 do
    with {:ok, exponent, coeff} <- parse_int(exponent_and_coefficient),
         {:ok, coefficient, <<>>} <- parse_int(coeff) do
      {:ok, coefficient * :math.pow(10, exponent), values}
    else
      e -> parse_value_error(e)
    end
  end

  defp parse_value(<<@decimal_type::size(4), l::size(4), exponent_and_coefficient::binary-size(l), values::bitstring>>, _metadata) when l > 2 and l < 14 do
    exponent_and_coefficient(exponent_and_coefficient, values)
  end

  defp parse_value(<<@decimal_type::size(4), l::size(4), length_and_values::bitstring>>, _metadata) when l == 14 do
    with {:ok, length, values} <- parse_varint(length_and_values),
         <<exponent_and_coefficient::size(length)-unit(8), values::bitstring>> <- values do
      exponent_and_coefficient(<<exponent_and_coefficient::size(length)-unit(8)>>, values)
    else
      e -> parse_value_error(e)
    end
  end

  defp parse_value(<<@timestamp_type::size(4), l::size(4), value::size(l)-unit(8)-binary, values::bitstring>>, _metadata) do
    with {:ok, offset, value} <- parse_varint(value),
         {:ok, year, value} <- parse_varuint(value) do
      case value do
        <<>> -> {:ok, %Date{year: year, month: nil, day: nil}, values} # offset only in DateTime
        value ->
          {:ok, month, value} = parse_varuint(value)
          case value do
            <<>> -> {:ok, %Date{year: year, month: month, day: nil}, values} # offset only in DateTime
            value ->
              {:ok, day, value} = parse_varuint(value)
              case value do
                <<>> -> {:ok, %Date{year: year, month: month, day: day}, values} # offset only in DateTime
                value ->
                  {:ok, hour, value} = parse_varuint(value)
                  {:ok, minute, value} = parse_varuint(value)
                  # case value do
                  #   <<>> -> {:ok, %DateTime{year: year, month: month, day: day, hour: hour, minute: minute}}

                  # end
              end
          end
      end
    else
      e -> e
    end
  end

  defp parse_value(<<@symbol_type::size(4), l::size(4), value::size(l)-unit(8), values::bitstring>>, %Ion.Metadata{symbols: symbols}) when l < 14 do
    {:ok, symbols[value], values}
  end

  defp parse_value(<<@symbol_type::size(4), l::size(4), length_and_values::bitstring>>, %Ion.Metadata{symbols: symbols}) when l == 14 do
    with {:ok, length, values} <- parse_varuint(length_and_values),
         <<value::size(length)-unit(8), values::bitstring>> <- values do
      {:ok, symbols[value], values}
    else
      e -> e
    end
  end

  defp parse_value(<<@string_type::size(4), l::size(4), value::size(l)-unit(8)-binary, values::bitstring>>, _metadata) when l < 14 do
    {:ok, value, values}
  end

  defp parse_value(<<@string_type::size(4), l::size(4), length_and_values::bitstring>>, _metadata) when l == 14 do
    with {:ok, length, values} <- parse_varuint(length_and_values),
         <<str::size(length)-unit(8)-binary, values::bitstring>> <- values do
      {:ok, str, values}
    else
      e -> e
    end
  end

  defp parse_value(<<clob_or_blob::size(4), l::size(4), value::size(l)-unit(8)-binary, values::bitstring>>, _metadata) when clob_or_blob in [@clob_type, @blob_type] and l < 14 do
    {:ok, value, values}
  end

  defp parse_value(<<clob_or_blob::size(4), l::size(4), length_and_values::bitstring>>, _metadata) when clob_or_blob in [@clob_type, @blob_type] and l == 14 do
    with {:ok, length, values} <- parse_varuint(length_and_values),
         <<bin::size(length)-unit(8)-binary, values::bitstring>> <- values do
      {:ok, bin, values}
    else
      e -> e
    end
  end

  defp parse_value(<<@list_type::size(4), l::size(4), value::size(l)-unit(8)-binary, values::bitstring>>, metadata) do
    case parse_values(value, metadata) do
      {:ok, list_values} ->
        {:ok, list_values, values}

      e ->
        {:error, "List with invalid elements: #{inspect(e)}"}
    end
  end

  defp parse_value(<<@sexp_type::size(4), l::size(4), value::size(l)-unit(8)-binary, values::bitstring>>, _metadata) do
    IO.puts("Sexp type")
    IO.inspect(l)
    IO.inspect(value, base: :hex)
    IO.inspect(values, base: :hex)
  end

  defp parse_value(<<@struct_type::size(4), 0::size(4), values::bitstring>>, _metadata) do
    {:ok, %{}, values}
  end

  defp parse_value(<<@struct_type::size(4), l::size(4), value::size(l)-unit(8)-binary, values::bitstring>>, metadata) when l != 14 do
    {:ok, parse_struct(value, metadata), values}
  end

  defp parse_value(<<@annotation_type::size(4), l::size(4), annotation::size(l)-unit(8)-binary, values::bitstring>>, _metadata) when l != 14 do
    with {:ok, annotation_length, annot_and_value} <- parse_varuint(annotation) do
      {annots, value} =
        Enum.reduce(0..(annotation_length - 1), {[], annot_and_value}, fn _, acc ->
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

  def parse_struct(struct, metadata, result \\ %{})

  def parse_struct(<<>>, _metadata, result), do: result

  def parse_struct(struct, %Ion.Metadata{symbols: symbols} = metadata, result) do
    with {:ok, field, values} <- parse_varuint(struct),
         {:ok, value, values} <- parse_value(values, metadata) do
      parse_struct(values, metadata, Map.put(result, symbols[field] || field, value))
    else
      e -> e
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
    use Bitwise
    parse_varuint(values, value <<< 8)
  end

  defp parse_varuint(<<0::size(1), value::size(7), values::bitstring>>, total) do
    use Bitwise
    parse_varuint(values, (value <<< 8) + (total <<< 8) )
  end

  defp parse_varuint(<<1::size(1), value::size(7), values::bitstring>>, nil) do
    {:ok, value, values}
  end

  defp parse_varuint(<<1::size(1), value::size(7), values::bitstring>>, total) do
    use Bitwise
    value = (total >>> 1) + value
    {:ok, value, values}
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
    with {:ok, first_result, values} <- parse_value(values, %Ion.Metadata{}) do
      case first_result do
        {@annotation_type, annots, value} ->
          {:ok, struct, <<>>} = parse_value(value, %Ion.Metadata{})
          {:ok, Enum.reduce(annots, %Ion.Metadata{}, &parse_metadata(&1, &2, struct)), values, []}

        _ ->
          {:ok, %Ion.Metadata{}, values, [first_result]}
      end
    end
  end

  @symbol_start_index 10
  defp parse_metadata(@symbol_table, metadata, %{@symbol_symbols => symbols}) do
    symbol_map = symbols |> Stream.with_index() |> Enum.reduce(%{}, fn {sym, i}, map -> Map.put(map, i + @symbol_start_index, sym) end)
    %Ion.Metadata{metadata | symbols: symbol_map}
  end

  defp parse_document(document) do
    with {:ok, metadata, values, result} <- parse_metadata(document) do
      parse_values(values, metadata, result)
    else
      e -> e
    end
  end

  defp parse_values(values, metadata, result \\ [])

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
