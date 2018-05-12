defmodule Ion.ParseTest do
  use ExUnit.Case
  doctest Ion.Parse

  describe "plain binary" do
    test "null" do
      assert {:ok, nil} = Ion.parse(
        <<224, 1, 0, 234, 15>>
      )
    end

    test "null.null" do
      assert {:ok, nil} = Ion.parse(
        <<224, 1, 0, 234, 15>>
      )
    end

    test "null.bool" do
      assert {:ok, nil} = Ion.parse(
        <<224, 1, 0, 234, 31>>
      )
    end

    test "null.int" do
      assert {:ok, nil} = Ion.parse(
        <<224, 1, 0, 234, 63>>
      )
    end

    test "null.float" do
      assert {:ok, nil} = Ion.parse(
        <<224, 1, 0, 234, 79>>
      )
    end

    test "null.decimal" do
      assert {:ok, nil} = Ion.parse(
        <<224, 1, 0, 234, 95>>
      )
    end

    test "null.timestamp" do
      assert {:ok, nil} = Ion.parse(
        <<224, 1, 0, 234, 111>>
      )
    end

    test "null.string" do
      assert {:ok, nil} = Ion.parse(
        <<224, 1, 0, 234, 143>>
      )
    end

    test "null.symbol" do
      assert {:ok, nil} = Ion.parse(
        <<224, 1, 0, 234, 127>>
      )
    end

    test "null.blob" do
      assert {:ok, nil} = Ion.parse(
        <<224, 1, 0, 234, 175>>
      )
    end

    test "null.clob" do
      assert {:ok, nil} = Ion.parse(
        <<224, 1, 0, 234, 159>>
      )
    end

    test "null.struct" do
      assert {:ok, nil} = Ion.parse(
        <<224, 1, 0, 234, 223>>
      )
    end

    test "null.list" do
      assert {:ok, nil} = Ion.parse(
        <<224, 1, 0, 234, 191>>
      )
    end

    test "null.sexp" do
      assert {:ok, nil} = Ion.parse(
        <<224, 1, 0, 234, 207>>
      )
    end

    test "boolean false" do
      assert {:ok, false} = Ion.parse(
        <<224, 1, 0, 234, 16>>
      )
    end

    test "boolean true" do
      assert {:ok, true} = Ion.parse(
        <<224, 1, 0, 234, 17>>
      )
    end

    test "integer 1" do
      assert {:ok, 1} = Ion.parse(
        <<224, 1, 0, 234, 33, 1>>
      )
    end

    test "integer 0" do
      assert {:ok, 0} = Ion.parse(
        <<224, 1, 0, 234, 32>>
      )
    end

    test "integer -1" do
      assert {:ok, -1} = Ion.parse(
        <<224, 1, 0, 234, 49, 1>>
      )
    end

    test "integer 123456" do
      assert {:ok, 123456} = Ion.parse(
        <<224, 1, 0, 234, 35, 1, 226, 64>>
      )
    end

    test "integer -123456" do
      assert {:ok, -123456} = Ion.parse(
        <<224, 1, 0, 234, 51, 1, 226, 64>>
      )
    end

    test "float 0e0" do
      assert {:ok, 0.0} = Ion.parse(
        <<224, 1, 0, 234, 64>>
      )
    end

    test "float -0e0" do
      assert {:ok, -0.0} = Ion.parse(
        <<224, 1, 0, 234, 72, 128, 0, 0, 0, 0, 0, 0, 0>>
      )
    end

    test "float 1.0e0" do
      assert {:ok, 1.0} = Ion.parse(
        <<224, 1, 0, 234, 72, 63, 240, 0, 0, 0, 0, 0, 0>>
      )
    end

    test "float -0.12e4" do
      assert {:ok, -1200.0} = Ion.parse(
        <<224, 1, 0, 234, 72, 192, 146, 192, 0, 0, 0, 0, 0>>
      )
    end

    test "float ∞" do
      assert {:ok, :infinity} = Ion.parse(
        <<224, 1, 0, 234, 72, 127, 240, 0, 0, 0, 0, 0, 0>>
      )
    end

    test "float -∞" do
      assert {:ok, :neg_infinity} = Ion.parse(
        <<224, 1, 0, 234, 72, 255, 240, 0, 0, 0, 0, 0, 0>>
      )
    end

    test "float NaN" do
      assert {:ok, :nan} = Ion.parse(
        <<224, 1, 0, 234, 72, 127, 248, 0, 0, 0, 0, 0, 0>>
      )
    end

    test "decimal 0D0" do
      assert {:ok, 0.0} = Ion.parse(
        <<224, 1, 0, 234, 80>>
      )
    end

    test "decimal -0D0" do
      assert {:ok, 0.0} = Ion.parse(
        <<224, 1, 0, 234, 82, 128, 128>>
      )
    end

    test "decimal 1.0D0" do
      assert {:ok, 1.0e-64} = Ion.parse(
        <<224, 1, 0, 234, 82, 193, 10>>
      )
    end

    test "decimal -0.12D4" do
      assert {:ok, -0.12} = Ion.parse(
        <<224, 1, 0, 234, 82, 130, 140>>
      )
    end

    test "decimal 123456.789012" do
      assert {:ok, 123456.789012} = Ion.parse(
        <<224, 1, 0, 234, 86, 198, 28, 190, 153, 26, 20>>
      )
    end

    test "decimal -123456.789012" do
      assert {:ok, -123456.789012} = Ion.parse(
        <<224, 1, 0, 234, 86, 198, 156, 190, 153, 26, 20>>
      )
    end

    test "decimal 12345678901234567890.12345678901234567890" do
      assert {:ok, 12345678901234567890.12345678901234567890} = Ion.parse(
        <<224, 1, 0, 234, 94, 146, 212, 3, 160, 201, 32, 117, 192, 219, 243, 184, 172,
        188, 95, 150, 206, 63, 10, 210>>
      )
    end

    test "decimal -12345678901234567890.12345678901234567890" do
      assert {:ok, -12345678901234567890.12345678901234567890} = Ion.parse(
        <<224, 1, 0, 234, 94, 146, 212, 131, 160, 201, 32, 117, 192, 219, 243, 184, 172,
        188, 95, 150, 206, 63, 10, 210>>
      )
    end

    # 1.2345678901234568e308 is max exponent representable in the EVM
    test "decimal superhuge" do
      assert {:ok, 123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345} = Ion.parse(
        <<224, 1, 0, 234, 46, 197, 2, 36, 212, 78, 12, 86, 245, 55, 99, 40, 21, 242, 80,
        16, 22, 170, 124, 17, 241, 92, 47, 183, 41, 233, 190, 18, 73, 188, 232, 45,
        66, 70, 243, 105, 204, 226, 213, 80, 57, 198, 43, 86, 30, 215, 221, 159, 191,
        89, 167, 192, 125, 134, 11, 174, 166, 16, 12, 127, 16, 24, 144, 204, 2, 188,
        116, 241, 226, 223, 121>>
      )
    end

    test "decimal -superhuge" do
      assert {:ok, -123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345} = Ion.parse(
        <<224, 1, 0, 234, 62, 197, 2, 36, 212, 78, 12, 86, 245, 55, 99, 40, 21, 242, 80,
        16, 22, 170, 124, 17, 241, 92, 47, 183, 41, 233, 190, 18, 73, 188, 232, 45,
        66, 70, 243, 105, 204, 226, 213, 80, 57, 198, 43, 86, 30, 215, 221, 159, 191,
        89, 167, 192, 125, 134, 11, 174, 166, 16, 12, 127, 16, 24, 144, 204, 2, 188,
        116, 241, 226, 223, 121>>
      )
    end

    # test "struct" do
    #   # {a: null}
    #   assert {:ok, nil} = Ion.parse(
    #     <<224, 1, 0, 234,
    #     # Annotation type with L of 7
    #     231,
    #     # length = 1
    #     129,
    #     # annot_length = 3
    #     131,
    #     # struct with L of 4
    #     212,
    #     # length varuint 7
    #     135,
    #     # varuint = 50
    #     178,
    #     # varuint = 1
    #     129,
    #     # a
    #     97,
    #     # ?? struct with L of 3
    #     210,
    #     # varuint 10
    #     138,
    #     # null
    #     15>>
    #   )
    # end

    # test "annotation" do
    #   assert {:ok, 1} = Ion.parse(
    #     <<224, 1, 0, 234,
    #     # Annotation type with L of 9
    #     233,
    #     # length = 1
    #     129,
    #     # annot_length = 3
    #     131,
    #     # WTF??
    #     # 214 = varuint of 86
    #     # 135 = varuint of 7
    #     # 180 = varuint of 52
    #     214, 135, 180, 131,
    #     # abc
    #     97, 98, 99,
    #     # WTF
    #     # 228 = varuint of 100
    #     # 129 = varuint of 1
    #     # 138 = varuint of 10
    #     # 33 ???
    #     228, 129, 138, 33,
    #     # Value
    #     12>>
    #   )
    # end
  end
end
