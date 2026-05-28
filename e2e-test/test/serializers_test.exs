defmodule Skir.BuiltinTest do
  @moduledoc """
  Port of the gleam `builtin_serializers_test` to ExUnit.

  Tests exercise the built-in TypeAdapters (bool/int32/int64/hash64/
  float32/float64/string/bytes/timestamp/optional/list) via the public
  `Skir.Serializer` API. Where our implementation differs from gleam by
  design (e.g. special-float atoms `:infinity`/`:neg_infinity`/`:nan`
  instead of float sentinels, ISO8601 timestamp readable JSON instead of
  `{unix_millis, formatted}` object), expectations reflect our actual
  behaviour — we are testing this library, not gleam.
  """
  use ExUnit.Case, async: true

  alias Skir.Serializer
  alias Skir.Serializer.Builtin
  alias Skir.TypeDescriptor, as: TD

  # --- helpers ---

  defp ser(adapter), do: %Serializer{type_adapter: adapter, module: nil}

  defp to_bytes(adapter, v), do: Serializer.encode_binary(ser(adapter), v)
  defp from_bytes(adapter, b), do: Serializer.decode_binary(ser(adapter), b)
  defp to_dense(adapter, v), do: Serializer.encode_json(ser(adapter), v, :dense)
  defp to_readable(adapter, v), do: Serializer.encode_json(ser(adapter), v, :readable)
  defp from_json(adapter, s), do: Serializer.decode_json(ser(adapter), s)

  defp td_json(adapter), do: TD.to_json(adapter.type_descriptor.())

  # =============================================================================
  # bool
  # =============================================================================

  describe "bool — to_dense_json" do
    test "true → 1" do
      assert to_dense(Builtin.bool(), true) == "1"
    end

    test "false → 0" do
      assert to_dense(Builtin.bool(), false) == "0"
    end
  end

  describe "bool — to_readable_json" do
    test "true → \"true\"" do
      assert to_readable(Builtin.bool(), true) == "true"
    end

    test "false → \"false\"" do
      assert to_readable(Builtin.bool(), false) == "false"
    end
  end

  describe "bool — from_json" do
    test "boolean literals" do
      assert {:ok, true} = from_json(Builtin.bool(), "true")
      assert {:ok, false} = from_json(Builtin.bool(), "false")
    end

    test "numbers 1 and 0" do
      assert {:ok, true} = from_json(Builtin.bool(), "1")
      assert {:ok, false} = from_json(Builtin.bool(), "0")
    end

    test "non-zero number is true" do
      assert {:ok, true} = from_json(Builtin.bool(), "42")
    end

    test "0.0 is false" do
      assert {:ok, false} = from_json(Builtin.bool(), "0.0")
    end

    test "null is false" do
      assert {:ok, false} = from_json(Builtin.bool(), "null")
    end

    # TODO: string-to-bool coercion ("\"0\"", "\"1\"", "\"true\"") — gleam
    # accepts these; our library may or may not. Uncomment after verifying.
    # test "string \"0\" is false" do
    #   assert {:ok, false} = from_json(Builtin.bool(), "\"0\"")
    # end
  end

  describe "bool — binary" do
    test "round-trip true" do
      bytes = to_bytes(Builtin.bool(), true)
      assert {:ok, true} = from_bytes(Builtin.bool(), bytes)
    end

    test "round-trip false" do
      bytes = to_bytes(Builtin.bool(), false)
      assert {:ok, false} = from_bytes(Builtin.bool(), bytes)
    end

    test "true encoding is skir + 0x01" do
      assert to_bytes(Builtin.bool(), true) == <<115, 107, 105, 114, 1>>
    end

    test "false encoding is skir + 0x00" do
      assert to_bytes(Builtin.bool(), false) == <<115, 107, 105, 114, 0>>
    end
  end

  describe "bool — type_descriptor" do
    test "is primitive bool" do
      expected = ~s({\n  "type": {\n    "kind": "primitive",\n    "value": "bool"\n  },\n  "records": []\n})
      assert td_json(Builtin.bool()) == expected
    end
  end

  # =============================================================================
  # int32
  # =============================================================================

  describe "int32 — to_json" do
    test "zero" do
      assert to_dense(Builtin.int32(), 0) == "0"
    end

    test "positive" do
      assert to_dense(Builtin.int32(), 42) == "42"
    end

    test "negative" do
      assert to_dense(Builtin.int32(), -1) == "-1"
    end

    test "dense and readable identical for int" do
      assert to_dense(Builtin.int32(), 12_345) == to_readable(Builtin.int32(), 12_345)
    end
  end

  describe "int32 — from_json" do
    test "integers" do
      assert {:ok, 42} = from_json(Builtin.int32(), "42")
      assert {:ok, -1} = from_json(Builtin.int32(), "-1")
      assert {:ok, 0} = from_json(Builtin.int32(), "0")
    end

    test "float truncates" do
      assert {:ok, 3} = from_json(Builtin.int32(), "3.9")
      assert {:ok, -1} = from_json(Builtin.int32(), "-1.5")
    end

    test "quoted integer string" do
      assert {:ok, 7} = from_json(Builtin.int32(), "\"7\"")
    end

    test "unparseable string is 0" do
      assert {:ok, 0} = from_json(Builtin.int32(), "\"abc\"")
    end

    test "null is 0" do
      assert {:ok, 0} = from_json(Builtin.int32(), "null")
    end
  end

  describe "int32 — binary encoding" do
    test "small positive is single byte" do
      assert to_bytes(Builtin.int32(), 0) == <<115, 107, 105, 114, 0>>
      assert to_bytes(Builtin.int32(), 1) == <<115, 107, 105, 114, 1>>
      assert to_bytes(Builtin.int32(), 231) == <<115, 107, 105, 114, 231>>
    end

    test "u16 range" do
      assert to_bytes(Builtin.int32(), 1000) == <<115, 107, 105, 114, 232, 232, 3>>
    end

    test "u32 range" do
      assert to_bytes(Builtin.int32(), 65_536) == <<115, 107, 105, 114, 233, 0, 0, 1, 0>>
    end

    test "small negative" do
      assert to_bytes(Builtin.int32(), -1) == <<115, 107, 105, 114, 235, 255>>
    end

    test "medium negative" do
      assert to_bytes(Builtin.int32(), -300) == <<115, 107, 105, 114, 236, 212, 254>>
    end

    test "large negative" do
      assert to_bytes(Builtin.int32(), -100_000) == <<115, 107, 105, 114, 237, 96, 121, 254, 255>>
    end

    test "binary round-trip" do
      values = [0, 1, 42, 231, 232, 300, 65_535, 65_536, -1, -255, -256, -65_536]

      for v <- values do
        assert {:ok, ^v} = from_bytes(Builtin.int32(), to_bytes(Builtin.int32(), v))
      end
    end
  end

  describe "int32 — type_descriptor" do
    test "is primitive int32" do
      expected = ~s({\n  "type": {\n    "kind": "primitive",\n    "value": "int32"\n  },\n  "records": []\n})
      assert td_json(Builtin.int32()) == expected
    end
  end

  # =============================================================================
  # int64
  # =============================================================================

  describe "int64 — to_json" do
    test "safe integer" do
      assert to_dense(Builtin.int64(), 0) == "0"
      assert to_dense(Builtin.int64(), 9_007_199_254_740_991) == "9007199254740991"
      assert to_dense(Builtin.int64(), -9_007_199_254_740_991) == "-9007199254740991"
    end

    test "large value is quoted" do
      assert to_dense(Builtin.int64(), 9_007_199_254_740_992) == "\"9007199254740992\""
      assert to_dense(Builtin.int64(), -9_007_199_254_740_992) == "\"-9007199254740992\""
    end
  end

  describe "int64 — from_json" do
    test "integer" do
      assert {:ok, 42} = from_json(Builtin.int64(), "42")
      assert {:ok, -1} = from_json(Builtin.int64(), "-1")
    end

    test "quoted large integer" do
      assert {:ok, 9_007_199_254_740_992} =
               from_json(Builtin.int64(), "\"9007199254740992\"")
    end

    test "null is 0" do
      assert {:ok, 0} = from_json(Builtin.int64(), "null")
    end
  end

  describe "int64 — binary" do
    test "fits-i32 reuses i32 encoding" do
      assert to_bytes(Builtin.int64(), 0) == <<115, 107, 105, 114, 0>>
      assert to_bytes(Builtin.int64(), 42) == <<115, 107, 105, 114, 42>>
    end

    test "wire 238 (i32::MAX + 1)" do
      assert to_bytes(Builtin.int64(), 2_147_483_648) ==
               <<115, 107, 105, 114, 238, 0, 0, 0, 128, 0, 0, 0, 0>>
    end

    test "binary round-trip" do
      values = [
        0, 1, 231, 232, 65_536, 2_147_483_647, 2_147_483_648,
        9_007_199_254_740_991, -1, -2_147_483_648
      ]

      for v <- values do
        assert {:ok, ^v} = from_bytes(Builtin.int64(), to_bytes(Builtin.int64(), v))
      end
    end
  end

  describe "int64 — type_descriptor" do
    test "is primitive int64" do
      expected = ~s({\n  "type": {\n    "kind": "primitive",\n    "value": "int64"\n  },\n  "records": []\n})
      assert td_json(Builtin.int64()) == expected
    end
  end

  # =============================================================================
  # hash64
  # =============================================================================

  describe "hash64 — to_json" do
    test "safe integer" do
      assert to_dense(Builtin.hash64(), 0) == "0"
      assert to_dense(Builtin.hash64(), 9_007_199_254_740_991) == "9007199254740991"
    end

    test "large value quoted" do
      assert to_dense(Builtin.hash64(), 9_007_199_254_740_992) == "\"9007199254740992\""
    end
  end

  describe "hash64 — from_json" do
    test "integer" do
      assert {:ok, 42} = from_json(Builtin.hash64(), "42")
    end

    test "negative number is 0 (hash is unsigned)" do
      assert {:ok, 0} = from_json(Builtin.hash64(), "-1.0")
    end

    test "quoted large" do
      assert {:ok, 9_007_199_254_740_992} =
               from_json(Builtin.hash64(), "\"9007199254740992\"")
    end

    test "null is 0" do
      assert {:ok, 0} = from_json(Builtin.hash64(), "null")
    end
  end

  describe "hash64 — binary" do
    test "single-byte range" do
      assert to_bytes(Builtin.hash64(), 0) == <<115, 107, 105, 114, 0>>
      assert to_bytes(Builtin.hash64(), 231) == <<115, 107, 105, 114, 231>>
    end

    test "u16 range" do
      assert to_bytes(Builtin.hash64(), 1000) == <<115, 107, 105, 114, 232, 232, 3>>
    end

    test "u32 range" do
      assert to_bytes(Builtin.hash64(), 65_536) == <<115, 107, 105, 114, 233, 0, 0, 1, 0>>
    end

    test "u64 range (2^32)" do
      assert to_bytes(Builtin.hash64(), 4_294_967_296) ==
               <<115, 107, 105, 114, 234, 0, 0, 0, 0, 1, 0, 0, 0>>
    end

    test "binary round-trip" do
      values = [0, 1, 231, 232, 65_535, 65_536, 4_294_967_295, 4_294_967_296]

      for v <- values do
        assert {:ok, ^v} = from_bytes(Builtin.hash64(), to_bytes(Builtin.hash64(), v))
      end
    end
  end

  describe "hash64 — type_descriptor" do
    test "is primitive hash64" do
      expected = ~s({\n  "type": {\n    "kind": "primitive",\n    "value": "hash64"\n  },\n  "records": []\n})
      assert td_json(Builtin.hash64()) == expected
    end
  end

  # =============================================================================
  # float32
  # =============================================================================

  describe "float32 — to_dense_json" do
    test "zero" do
      assert to_dense(Builtin.float32(), 0.0) == "0"
    end

    test "one" do
      assert to_dense(Builtin.float32(), 1.0) == "1"
    end

    test "1.5" do
      assert to_dense(Builtin.float32(), 1.5) == "1.5"
    end

    test "negative" do
      assert to_dense(Builtin.float32(), -3.14) == "-3.14"
    end
  end

  describe "float32 — to_readable_json (same as dense for scalars)" do
    test "zero" do
      assert to_readable(Builtin.float32(), 0.0) == "0"
    end

    test "nonzero" do
      assert to_readable(Builtin.float32(), 1.5) == "1.5"
    end
  end

  describe "float32 — from_json" do
    test "number" do
      assert {:ok, 1.5} = from_json(Builtin.float32(), "1.5")
    end

    test "integer" do
      assert {:ok, 3.0} = from_json(Builtin.float32(), "3")
    end

    test "null is 0.0" do
      assert {:ok, 0.0} = from_json(Builtin.float32(), "null")
    end

    test "quoted string" do
      assert {:ok, 1.5} = from_json(Builtin.float32(), "\"1.5\"")
    end

    # NOTE: our library represents special floats as atoms, not max-float
    # sentinels (gleam erlang target uses max-float; we use atoms).
    test "Infinity → :infinity atom" do
      assert {:ok, :infinity} = from_json(Builtin.float32(), "\"Infinity\"")
    end

    test "-Infinity → :neg_infinity atom" do
      assert {:ok, :neg_infinity} = from_json(Builtin.float32(), "\"-Infinity\"")
    end

    test "NaN → :nan atom" do
      assert {:ok, :nan} = from_json(Builtin.float32(), "\"NaN\"")
    end
  end

  describe "float32 — binary encoding" do
    test "zero is single-byte 0" do
      assert to_bytes(Builtin.float32(), 0.0) == <<115, 107, 105, 114, 0>>
    end

    test "nonzero starts with wire 240" do
      <<115, 107, 105, 114, 240, _::bits>> = to_bytes(Builtin.float32(), 1.5)
    end
  end

  describe "float32 — binary round-trips" do
    test "zero" do
      bytes = to_bytes(Builtin.float32(), 0.0)
      assert {:ok, 0.0} = from_bytes(Builtin.float32(), bytes)
    end

    test "1.5" do
      bytes = to_bytes(Builtin.float32(), 1.5)
      assert {:ok, 1.5} = from_bytes(Builtin.float32(), bytes)
    end

    test "-1.5" do
      bytes = to_bytes(Builtin.float32(), -1.5)
      assert {:ok, -1.5} = from_bytes(Builtin.float32(), bytes)
    end

    test "from_bytes +Infinity wire (0x7F800000 LE)" do
      bytes = <<115, 107, 105, 114, 240, 0, 0, 128, 127>>
      assert {:ok, :infinity} = from_bytes(Builtin.float32(), bytes)
    end

    test "from_bytes -Infinity wire (0xFF800000 LE)" do
      bytes = <<115, 107, 105, 114, 240, 0, 0, 128, 255>>
      assert {:ok, :neg_infinity} = from_bytes(Builtin.float32(), bytes)
    end
  end

  # =============================================================================
  # float64
  # =============================================================================

  describe "float64 — to_dense_json" do
    test "zero" do
      assert to_dense(Builtin.float64(), 0.0) == "0"
    end

    test "one" do
      assert to_dense(Builtin.float64(), 1.0) == "1"
    end

    test "1.5" do
      assert to_dense(Builtin.float64(), 1.5) == "1.5"
    end

    test "negative" do
      assert to_dense(Builtin.float64(), -3.14) == "-3.14"
    end
  end

  describe "float64 — to_readable_json" do
    test "zero" do
      assert to_readable(Builtin.float64(), 0.0) == "0"
    end

    test "nonzero" do
      assert to_readable(Builtin.float64(), 1.5) == "1.5"
    end
  end

  describe "float64 — from_json" do
    test "number" do
      assert {:ok, 1.5} = from_json(Builtin.float64(), "1.5")
    end

    test "integer" do
      assert {:ok, 3.0} = from_json(Builtin.float64(), "3")
    end

    test "null is 0.0" do
      assert {:ok, 0.0} = from_json(Builtin.float64(), "null")
    end

    test "quoted string" do
      assert {:ok, 1.5} = from_json(Builtin.float64(), "\"1.5\"")
    end

    test "Infinity → :infinity" do
      assert {:ok, :infinity} = from_json(Builtin.float64(), "\"Infinity\"")
    end

    test "-Infinity → :neg_infinity" do
      assert {:ok, :neg_infinity} = from_json(Builtin.float64(), "\"-Infinity\"")
    end

    test "NaN → :nan" do
      assert {:ok, :nan} = from_json(Builtin.float64(), "\"NaN\"")
    end
  end

  describe "float64 — binary encoding" do
    test "zero is single-byte 0" do
      assert to_bytes(Builtin.float64(), 0.0) == <<115, 107, 105, 114, 0>>
    end

    test "nonzero starts with wire 241" do
      <<115, 107, 105, 114, 241, _::bits>> = to_bytes(Builtin.float64(), 1.5)
    end
  end

  describe "float64 — binary round-trips" do
    test "zero" do
      bytes = to_bytes(Builtin.float64(), 0.0)
      assert {:ok, 0.0} = from_bytes(Builtin.float64(), bytes)
    end

    test "pi" do
      value = 3.141_592_653_589_793
      bytes = to_bytes(Builtin.float64(), value)
      assert {:ok, ^value} = from_bytes(Builtin.float64(), bytes)
    end

    test "negative e" do
      value = -2.718_281_828_459_045
      bytes = to_bytes(Builtin.float64(), value)
      assert {:ok, ^value} = from_bytes(Builtin.float64(), bytes)
    end

    test "from_bytes +Infinity wire (0x7FF0000000000000 LE)" do
      bytes = <<115, 107, 105, 114, 241, 0, 0, 0, 0, 0, 0, 240, 127>>
      assert {:ok, :infinity} = from_bytes(Builtin.float64(), bytes)
    end

    test "from_bytes -Infinity wire (0xFFF0000000000000 LE)" do
      bytes = <<115, 107, 105, 114, 241, 0, 0, 0, 0, 0, 0, 240, 255>>
      assert {:ok, :neg_infinity} = from_bytes(Builtin.float64(), bytes)
    end
  end

  # =============================================================================
  # string
  # =============================================================================

  describe "string — to_dense_json" do
    test "empty" do
      assert to_dense(Builtin.string(), "") == "\"\""
    end

    test "simple" do
      assert to_dense(Builtin.string(), "hello") == "\"hello\""
    end

    test "escapes double quote" do
      assert to_dense(Builtin.string(), ~s(say "hi")) == ~s("say \\"hi\\"")
    end

    test "escapes backslash" do
      assert to_dense(Builtin.string(), "a\\b") == ~s("a\\\\b")
    end

    test "escapes newline" do
      assert to_dense(Builtin.string(), "a\nb") == ~s("a\\nb")
    end
  end

  describe "string — to_readable_json" do
    test "simple — same as dense" do
      assert to_readable(Builtin.string(), "hello") == "\"hello\""
    end

    test "empty" do
      assert to_readable(Builtin.string(), "") == "\"\""
    end
  end

  describe "string — from_json" do
    test "string" do
      assert {:ok, "hello"} = from_json(Builtin.string(), "\"hello\"")
    end

    test "empty" do
      assert {:ok, ""} = from_json(Builtin.string(), "\"\"")
    end

    test "number yields empty (default)" do
      assert {:ok, ""} = from_json(Builtin.string(), "0")
    end

    test "null yields empty" do
      assert {:ok, ""} = from_json(Builtin.string(), "null")
    end

    test "round-trip" do
      value = "round trip"
      json = to_dense(Builtin.string(), value)
      assert {:ok, ^value} = from_json(Builtin.string(), json)
    end
  end

  describe "string — binary" do
    test "empty is wire 242" do
      assert to_bytes(Builtin.string(), "") == <<115, 107, 105, 114, 242>>
    end

    test "hello" do
      assert to_bytes(Builtin.string(), "hello") ==
               <<115, 107, 105, 114, 243, 5, 104, 101, 108, 108, 111>>
    end

    test "round-trip empty" do
      bytes = to_bytes(Builtin.string(), "")
      assert {:ok, ""} = from_bytes(Builtin.string(), bytes)
    end

    test "round-trip simple" do
      bytes = to_bytes(Builtin.string(), "hello")
      assert {:ok, "hello"} = from_bytes(Builtin.string(), bytes)
    end

    test "round-trip unicode" do
      value = "héllo wörld"
      bytes = to_bytes(Builtin.string(), value)
      assert {:ok, ^value} = from_bytes(Builtin.string(), bytes)
    end
  end

  describe "string — type_descriptor" do
    test "is primitive string" do
      expected = ~s({\n  "type": {\n    "kind": "primitive",\n    "value": "string"\n  },\n  "records": []\n})
      assert td_json(Builtin.string()) == expected
    end
  end

  # =============================================================================
  # bytes
  # =============================================================================

  describe "bytes — to_dense_json (base64)" do
    test "empty" do
      assert to_dense(Builtin.bytes(), <<>>) == "\"\""
    end

    test "single byte" do
      assert to_dense(Builtin.bytes(), <<0>>) == "\"AA==\""
    end

    test "two bytes" do
      assert to_dense(Builtin.bytes(), <<0, 1>>) == "\"AAE=\""
    end

    test "three bytes" do
      assert to_dense(Builtin.bytes(), <<0, 1, 2>>) == "\"AAEC\""
    end

    test "hello" do
      assert to_dense(Builtin.bytes(), "hello") == "\"aGVsbG8=\""
    end
  end

  describe "bytes — to_readable_json (hex: prefix)" do
    test "empty" do
      assert to_readable(Builtin.bytes(), <<>>) == "\"hex:\""
    end

    test "single byte" do
      assert to_readable(Builtin.bytes(), <<15>>) == "\"hex:0f\""
    end

    test "multiple bytes" do
      assert to_readable(Builtin.bytes(), <<0xDE, 0xAD, 0xBE, 0xEF>>) == "\"hex:deadbeef\""
    end
  end

  describe "bytes — from_json" do
    test "base64" do
      assert {:ok, "hello"} = from_json(Builtin.bytes(), "\"aGVsbG8=\"")
    end

    test "empty base64" do
      assert {:ok, <<>>} = from_json(Builtin.bytes(), "\"\"")
    end

    test "null yields empty" do
      assert {:ok, <<>>} = from_json(Builtin.bytes(), "null")
    end

    test "number yields empty" do
      assert {:ok, <<>>} = from_json(Builtin.bytes(), "0")
    end

    test "hex: prefix" do
      assert {:ok, <<0xDE, 0xAD, 0xBE, 0xEF>>} =
               from_json(Builtin.bytes(), "\"hex:deadbeef\"")
    end

    test "round-trip dense" do
      value = <<1, 2, 3, 4, 5>>
      json = to_dense(Builtin.bytes(), value)
      assert {:ok, ^value} = from_json(Builtin.bytes(), json)
    end

    test "round-trip readable" do
      value = <<0xCA, 0xFE, 0xBA, 0xBE>>
      json = to_readable(Builtin.bytes(), value)
      assert {:ok, ^value} = from_json(Builtin.bytes(), json)
    end
  end

  describe "bytes — binary" do
    test "empty is wire 244" do
      assert to_bytes(Builtin.bytes(), <<>>) == <<115, 107, 105, 114, 244>>
    end

    test "hello bytes" do
      assert to_bytes(Builtin.bytes(), "hello") ==
               <<115, 107, 105, 114, 245, 5, 104, 101, 108, 108, 111>>
    end

    test "round-trip empty" do
      bytes = to_bytes(Builtin.bytes(), <<>>)
      assert {:ok, <<>>} = from_bytes(Builtin.bytes(), bytes)
    end

    test "round-trip" do
      value = <<1, 2, 3, 4, 5, 255, 0, 127>>
      bytes = to_bytes(Builtin.bytes(), value)
      assert {:ok, ^value} = from_bytes(Builtin.bytes(), bytes)
    end
  end

  describe "bytes — type_descriptor" do
    test "is primitive bytes" do
      expected = ~s({\n  "type": {\n    "kind": "primitive",\n    "value": "bytes"\n  },\n  "records": []\n})
      assert td_json(Builtin.bytes()) == expected
    end
  end

  # =============================================================================
  # timestamp (DateTime)
  # =============================================================================
  #
  # NOTE: our library uses DateTime; gleam uses {unix_millis, formatted}.
  # Readable JSON in our library is ISO8601 string (DateTime's natural form).

  defp from_ms(ms), do: DateTime.from_unix!(ms, :millisecond)

  describe "timestamp — to_dense_json" do
    test "epoch → 0" do
      assert to_dense(Builtin.timestamp(), from_ms(0)) == "0"
    end

    test "nonzero (1234567890000)" do
      assert to_dense(Builtin.timestamp(), from_ms(1_234_567_890_000)) == "1234567890000"
    end
  end

  describe "timestamp — to_readable_json (ISO8601)" do
    test "epoch" do
      # Our library emits ISO8601 string for DateTime readable JSON.
      json = to_readable(Builtin.timestamp(), from_ms(0))
      # Wrapped as quoted JSON string.
      assert json =~ "1970-01-01"
    end

    test "nonzero" do
      json = to_readable(Builtin.timestamp(), from_ms(1_234_567_890_000))
      assert json =~ "2009-02-13"
    end
  end

  describe "timestamp — from_json" do
    test "integer millis" do
      assert {:ok, dt} = from_json(Builtin.timestamp(), "1234567890000")
      assert DateTime.to_unix(dt, :millisecond) == 1_234_567_890_000
    end

    test "null is epoch" do
      assert {:ok, dt} = from_json(Builtin.timestamp(), "null")
      assert DateTime.to_unix(dt, :millisecond) == 0
    end

    test "quoted millis" do
      assert {:ok, dt} = from_json(Builtin.timestamp(), "\"1234567890000\"")
      assert DateTime.to_unix(dt, :millisecond) == 1_234_567_890_000
    end

    # TODO: object form {"unix_millis": N, "formatted": "..."} — our library
    # may or may not accept it. Enable after verifying.
  end

  describe "timestamp — binary" do
    test "epoch is single-byte 0" do
      assert to_bytes(Builtin.timestamp(), from_ms(0)) == <<115, 107, 105, 114, 0>>
    end

    test "nonzero starts with wire 239 (64-bit LE)" do
      bytes = to_bytes(Builtin.timestamp(), from_ms(1_234_567_890_000))
      <<115, 107, 105, 114, 239, _::bits>> = bytes
    end

    test "round-trip epoch" do
      bytes = to_bytes(Builtin.timestamp(), from_ms(0))
      assert {:ok, dt} = from_bytes(Builtin.timestamp(), bytes)
      assert DateTime.to_unix(dt, :millisecond) == 0
    end

    test "round-trip nonzero" do
      ms = 1_234_567_890_000
      bytes = to_bytes(Builtin.timestamp(), from_ms(ms))
      assert {:ok, dt} = from_bytes(Builtin.timestamp(), bytes)
      assert DateTime.to_unix(dt, :millisecond) == ms
    end

    test "round-trip small millis" do
      ms = 42
      bytes = to_bytes(Builtin.timestamp(), from_ms(ms))
      assert {:ok, dt} = from_bytes(Builtin.timestamp(), bytes)
      assert DateTime.to_unix(dt, :millisecond) == ms
    end
  end

  # =============================================================================
  # optional (gleam Option → elixir nil/value)
  # =============================================================================

  defp opt_i32, do: Builtin.optional(Builtin.int32())

  describe "optional — to_dense_json" do
    test "nil → null" do
      assert to_dense(opt_i32(), nil) == "null"
    end

    test "value → value" do
      assert to_dense(opt_i32(), 42) == "42"
    end
  end

  describe "optional — to_readable_json" do
    test "nil → null" do
      assert to_readable(opt_i32(), nil) == "null"
    end

    test "value → value" do
      assert to_readable(opt_i32(), 42) == "42"
    end
  end

  describe "optional — from_json" do
    test "null → nil" do
      assert {:ok, nil} = from_json(opt_i32(), "null")
    end

    test "value → value" do
      assert {:ok, 42} = from_json(opt_i32(), "42")
    end
  end

  describe "optional — binary" do
    test "nil encoding is skir + 0xFF" do
      assert to_bytes(opt_i32(), nil) == <<115, 107, 105, 114, 255>>
    end

    test "Some encoding starts with 0x01 tag" do
      <<115, 107, 105, 114, 1, _::bits>> = to_bytes(opt_i32(), 0)
    end

    test "round-trip nil" do
      bytes = to_bytes(opt_i32(), nil)
      assert {:ok, nil} = from_bytes(opt_i32(), bytes)
    end

    test "round-trip value" do
      bytes = to_bytes(opt_i32(), 42)
      assert {:ok, 42} = from_bytes(opt_i32(), bytes)
    end
  end

  # =============================================================================
  # list
  # =============================================================================

  defp list_i32, do: Builtin.list(Builtin.int32())

  describe "list — to_dense_json" do
    test "empty" do
      assert to_dense(list_i32(), []) == "[]"
    end

    test "nonempty" do
      assert to_dense(list_i32(), [1, 2, 3]) == "[1,2,3]"
    end
  end

  describe "list — to_readable_json" do
    test "empty" do
      assert to_readable(list_i32(), []) == "[]"
    end

    test "nonempty (pretty-printed)" do
      assert to_readable(list_i32(), [1, 2]) == "[\n  1,\n  2\n]"
    end
  end

  describe "list — from_json" do
    test "zero is empty (forward-compat)" do
      assert {:ok, []} = from_json(list_i32(), "0")
    end

    test "empty array" do
      assert {:ok, []} = from_json(list_i32(), "[]")
    end

    test "nonempty array" do
      assert {:ok, [1, 2, 3]} = from_json(list_i32(), "[1,2,3]")
    end
  end

  describe "list — binary" do
    test "round-trip empty" do
      bytes = to_bytes(list_i32(), [])
      assert {:ok, []} = from_bytes(list_i32(), bytes)
    end

    test "round-trip nonempty" do
      bytes = to_bytes(list_i32(), [1, 2, 3])
      assert {:ok, [1, 2, 3]} = from_bytes(list_i32(), bytes)
    end
  end
end
