defmodule Ion.Parse.Binary do
  @moduledoc """
  """

  @type ion_binary :: binary
  @typep basic_value :: nil | boolean | number | list | map | binary | Date.t | DateTime.t
  @type value :: basic_value | {:annotation, list(atom), basic_value}
  @type document :: value | nonempty_list(value)
  @typep parsed_value(type) :: {:ok, type, binary}
  @type error_partial_value :: {:error, binary, document}
  @typep error_parsed_value :: {:error, binary}
  @typep error_message :: {:error_message, binary}

  @doc """
  """
  @spec parse(ion_binary) :: {:ok, document} | error_partial_value
  def parse(binary)

  def parse(<<0xE0, 1, 0, 0xEA, values::bitstring>>) do
    case parse_document(values) do
      {:ok, [result]} ->
        {:ok, result}

      {:ok, results} ->
        {:ok, results}

      {:error, reason, partial_results} ->
        {:error, reason, partial_results}
    end
  end

  def parse(<<0xE0, major, minor, 0xEA, _values::bitstring>>) do
    {:error, "Unsupported Ion version #{major}.#{minor}"}
  end

  @doc """
  """
  @spec parse_file(IO.chardata) :: {:ok, document} | error_partial_value
  def parse_file(filename) do
    filename
    |> File.read!()
    |> parse()
  end

  @bool_type 0x1
  @pos_int_type 0x2
  @neg_int_type 0x3
  @float_type 0x4
  @decimal_type 0x5
  @timestamp_type 0x6
  @symbol_type 0x7
  @string_type 0x8
  @clob_type 0x9
  @blob_type 0xA
  @list_type 0xB
  @sexp_type 0xC
  @struct_type 0xD
  @annotation_type 0xE
  @null_type 0xF

  @type_to_name %{
    @bool_type => "boolean",
    @pos_int_type => "positive integer",
    @neg_int_type => "negative integer",
    @float_type => "float",
    @decimal_type => "decimal",
    @timestamp_type => "timestamp",
    @symbol_type => "symbol",
    @string_type => "string",
    @clob_type => "clob",
    @blob_type => "blob",
    @list_type => "list",
    @sexp_type => "sexp",
    @struct_type => "struct",
    @annotation_type => "annotation",
    @null_type => "null"
  }

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
  # @symbol_ion 1
  # @symbol_ion_1_0 2
  @symbol_table 3
  # @symbol_name 4
  # @symbol_version 5
  # @symbol_imports 6
  @symbol_symbols 7
  # @symbol_max_id 8
  # @symbol_shared_table 9
  @user_symbol_start_index 10

  @spec parse_value(ion_binary, Ion.Metadata.t()) :: parsed_value(value) | error_parsed_value
  # @spec parse_value(binary, %Ion.Metadata{:symbols => nil}) :: any()
  defp parse_value(binary, metadata)

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
         {:ok, year, value} <- parse_varuint(value),
         [offset, year, <<_::size(1), _::bitstring>>] <- [offset, year, value],
         {:ok, month, value} <- parse_varuint(value),
         [offset, year, month, <<_::size(1), _::bitstring>>] <- [offset, year, month, value],
         {:ok, day, value} <- parse_varuint(value),
         [offset, year, month, day, <<_::size(1), _::bitstring>>] <- [offset, year, month, day, value],
         {:ok, hour, value} <- parse_varuint(value),
         {:ok, minute, value} <- parse_varuint(value),
         [offset, year, month, day, hour, minute, <<_::size(1), _::bitstring>>] <- [offset, year, month, day, hour, minute, value],
         {:ok, second, value} <- parse_varuint(value),
         [offset, year, month, day, hour, minute, second, <<_::size(1), _::bitstring>>] <- [offset, year, month, day, hour, minute, second, value],
         {:ok, exponent, value} <- parse_varint(value),
         {:ok, coefficient, <<>>} <- parse_int(value) do
      _ = coefficient * :math.pow(10, exponent)
      {:ok, %DateTime{year: year, month: month, day: day, hour: hour, minute: minute, second: second, utc_offset: offset, time_zone: "", zone_abbr: "", std_offset: offset}, values}
    else
      {:error, message} ->
        {:error, message}

      [_offset, year, <<>>] ->
        {:ok, %Date{year: year, month: nil, day: nil}, values}

      [_offset, year, month, <<>>] ->
        {:ok, %Date{year: year, month: month, day: nil}, values}

      [_offset, year, month, day, <<>>] ->
        {:ok, %Date{year: year, month: month, day: day}, values}

      [offset, year, month, day, hour, minute, <<>>] ->
        {:ok, %DateTime{year: year, month: month, day: day, hour: hour, minute: minute, second: 0, utc_offset: offset, time_zone: "", zone_abbr: "", std_offset: offset}, values}

      [offset, year, month, day, hour, minute, second, <<>>] ->
        {:ok, %DateTime{year: year, month: month, day: day, hour: hour, minute: minute, second: second, utc_offset: offset, time_zone: "", zone_abbr: "", std_offset: offset}, values}

      other ->
        [remaining_binary | date_values] = Enum.reverse(other)
        other = Enum.reverse(date_values)
        {:error, "Unable to read binary timestamp #{inspect(other)} with remaining binary #{inspect(remaining_binary, base: :hex)}\nBinary is incorrect: #{inspect(value, base: :hex)}"}
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

  defp parse_value(<<@list_type::size(4), l::size(4), value::size(l)-unit(8)-binary, values::bitstring>>, metadata) when l != 14 do
    case parse_values(value, metadata) do
      {:ok, list_values} -> {:ok, list_values, values}
      error -> error
    end
  end

  defp parse_value(<<@list_type::size(4), l::size(4), values::bitstring>>, metadata) when l == 14 do
    with {:ok, length, values} <- parse_varuint(values),
         <<value::size(length)-unit(8)-binary, values::bitstring>> <- values,
         {:ok, list_values} <- parse_values(value, metadata) do
      {:ok, list_values, values}
    else
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

  defp parse_value(<<@struct_type::size(4), l::size(4), values::bitstring>>, metadata) when l == 14 do
    with {:ok, length, values} <- parse_varuint(values),
         <<value::size(length)-unit(8)-binary, values::bitstring>> <- values do
      {:ok, parse_struct(value, metadata), values}
    else
      e -> parse_value_error(e)
    end
  end

  defp parse_value(<<@annotation_type::size(4), l::size(4), annotation::size(l)-unit(8)-binary, values::bitstring>>, metadata) when l != 14 do
    with {:ok, annotation_length, annot_and_value} <- parse_varuint(annotation) do
      {:ok, parse_annotation(annotation_length, annot_and_value, metadata), values}
    else
      e -> parse_value_error(e)
    end
  end

  defp parse_value(<<@annotation_type::size(4), l::size(4), values::bitstring>>, metadata) when l == 14 do
    with {:ok, length, values} <- parse_varuint(values),
         <<annotation::size(length)-unit(8)-binary, values::bitstring>> <- values,
         {:ok, annotation_length, annot_and_value} <- parse_varuint(annotation) do
      {:ok, parse_annotation(annotation_length, annot_and_value, metadata), values}
    else
      e -> parse_value_error(e)
    end
  end

  defp parse_value(<<unknown_type::size(4), l::size(4), values::bitstring>>, metadata) do
    parse_value_error({:error_message, "Unable to handle type #{@type_to_name[unknown_type]} (#{inspect(unknown_type, base: :hex)}) of length #{l}.\nMetadata: #{inspect(metadata)}\nRemaining binary: #{inspect(values, base: :hex)}"})
  end

  defp parse_annotation(annotation_length, annot_and_value, metadata = %Ion.Metadata{symbols: symbols}) do
    {annots, value} =
      Enum.reduce(0..(annotation_length - 1), {[], annot_and_value}, fn _, acc ->
        with {annots, annot_and_value} <- acc,
             {:ok, annot_integer, rest} <- parse_varuint(annot_and_value) do
          case Map.fetch(symbols, annot_integer) do
            {:ok, annotation} ->
              {[annotation | annots], rest}

            :error ->
              # Only error out on unfound user symbols, system symbols are handled automatically
              if annot_integer >= @user_symbol_start_index do
                parse_value_error({:error_message, "Unable to find symbol #{annot_integer}, known symbols are #{inspect(symbols)}"})
              else
                {[annot_integer | annots], rest}
              end
          end
        else
          e -> parse_value_error(e)
        end
      end)

    {:ok, value, <<>>} = parse_value(value, metadata)
    {:annotation, annots, value}
  end

  @spec parse_struct(ion_binary, Ion.Metadata.t(), map) :: map | error_parsed_value
  defp parse_struct(struct, metadata, result \\ %{})

  defp parse_struct(<<>>, _metadata, result), do: result

  defp parse_struct(struct, %Ion.Metadata{symbols: symbols} = metadata, result) do
    with {:ok, field, values} <- parse_varuint(struct),
         {:ok, value, values} <- parse_value(values, metadata) do
      parse_struct(values, metadata, Map.put(result, symbols[field] || field, value))
    else
      e -> e
    end
  end

  ### VarInt ###
  @spec parse_varint(binary, nil | 0 | 1, nil | integer) :: parsed_value(integer) | error_parsed_value
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
  @spec parse_varuint(binary, nil | non_neg_integer) :: parsed_value(non_neg_integer) | error_parsed_value
  defp parse_varuint(binary, acc \\ nil)

  defp parse_varuint(<<0::size(1), value::size(7), values::bitstring>>, nil) do
    use Bitwise
    parse_varuint(values, value <<< 8)
  end

  defp parse_varuint(<<0::size(1), value::size(7), values::bitstring>>, total) do
    use Bitwise
    parse_varuint(values, (value <<< 8) + (total <<< 8))
  end

  defp parse_varuint(<<1::size(1), value::size(7), values::bitstring>>, nil) do
    {:ok, value, values}
  end

  defp parse_varuint(<<1::size(1), value::size(7), values::bitstring>>, total) do
    use Bitwise
    value = (total >>> 1) + value
    {:ok, value, values}
  end

  defp parse_varuint(binary, _), do: {:error, binary}

  @spec parse_int(binary) :: parsed_value(integer)
  defp parse_int(<<sign::size(1), int::size(7), values::bitstring>>) do
    {:ok, if(sign == 0, do: int, else: -int), values}
  end

  @spec parse_value_error(parsed_value(any) | error_message | error_parsed_value | binary) :: error_parsed_value
  defp parse_value_error({:ok, _, binary}) do
    {:error, "Error found: #{inspect(binary, base: :hex)}"}
  end

  defp parse_value_error({:error_message, message}) do
    {:error, message}
  end

  defp parse_value_error({:error, binary}) do
    {:error, "Error found: #{inspect(binary, base: :hex)}"}
  end

  defp parse_value_error(binary) do
    {:error, "Error found: #{inspect(binary, base: :hex)}"}
  end

  @spec exponent_and_coefficient(binary, binary) :: parsed_value(float) | error_parsed_value
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

  @spec parse_metadata(ion_binary) :: {:ok, Ion.Metadata.t(), binary, value} | error_parsed_value
  defp parse_metadata(values) do
    with {:ok, first_result, values} <- parse_value(values, %Ion.Metadata{}) do
      case first_result do
        {:annotation, annots, symbol_table} ->
          {:ok, Enum.reduce(annots, %Ion.Metadata{}, &parse_metadata(&1, &2, symbol_table)), values, []}

        _ ->
          {:ok, %Ion.Metadata{}, values, [first_result]}
      end
    end
  end

  @spec parse_metadata(1..9, Ion.Metadata.t(), %{(1..9) => %{non_neg_integer => atom}}) :: Ion.Metadata.t()
  defp parse_metadata(@symbol_table, metadata, %{@symbol_symbols => symbols}) do
    symbol_map = symbols |> Stream.with_index() |> Enum.reduce(%{}, fn {sym, i}, map -> Map.put(map, i + @user_symbol_start_index, sym) end)
    %Ion.Metadata{metadata | symbols: symbol_map}
  end

  @spec parse_document(ion_binary) :: document | error_partial_value
  defp parse_document(document) do
    with {:ok, metadata, values, result} <- parse_metadata(document) do
      parse_values(values, metadata, result)
    else
      {:error, message} -> {:error, message, nil}
    end
  end

  @spec parse_values(ion_binary, Ion.Metadata.t(), list(value)) :: {:ok, list(value)} | error_partial_value
  defp parse_values(values, metadata, result \\ [])

  defp parse_values(<<>>, _metadata, result) do
    {:ok, Enum.reverse(result)}
  end

  defp parse_values(values, metadata, result) do
    with {:ok, value, values} <- parse_value(values, metadata) do
      parse_values(values, metadata, [value | result])
    else
      {:error, message} -> {:error, message, Enum.reverse(result)}
    end
  end
end
