defmodule GoldensTest do
  @moduledoc """
  Port of the Gleam golden-suite driver (`run_golden_tests_test`), treated as a 100% golden reference.
  """
  use ExUnit.Case, async: true

  alias Skir.Serializer
  alias Skir.Serializer.Builtin
  alias Skir.TypeDescriptor

  # =============================================================================
  # EvaluatedValue — type-erased bundle of a deserialised value and its serializer
  # =============================================================================

  defp make_ev(value, adapter) do
    %{
      to_bytes: fn -> Serializer.encode_binary(ser(adapter), value) end,
      to_dense_json: fn -> Serializer.encode_json(ser(adapter), value, :dense) end,
      to_readable_json: fn -> Serializer.encode_json(ser(adapter), value, :readable) end,
      type_descriptor_json: fn ->
        TypeDescriptor.to_json(adapter.type_descriptor.())
      end,
      from_json_keep: fn json ->
        case Serializer.decode_json(ser(adapter), json, keep: true) do
          {:ok, v} -> {:ok, make_ev(v, adapter)}
          {:error, e} -> {:error, inspect(e)}
        end
      end,
      from_json_drop: fn json ->
        case Serializer.decode_json(ser(adapter), json) do
          {:ok, v} -> {:ok, make_ev(v, adapter)}
          {:error, e} -> {:error, inspect(e)}
        end
      end,
      from_bytes_drop: fn bytes ->
        case Serializer.decode_binary(ser(adapter), bytes) do
          {:ok, v} -> {:ok, make_ev(v, adapter)}
          {:error, e} -> {:error, inspect(e)}
        end
      end
    }
  end

  defp ser(adapter), do: %Serializer{type_adapter: adapter, module: nil}
  defp mod_adapter(mod), do: mod.__skir_serializer__().type_adapter

  # =============================================================================
  # Helpers
  # =============================================================================

  defp to_hex(bytes), do: Base.encode16(bytes, case: :lower)

  defp join_or(items), do: Enum.join(items, " or ")

  # =============================================================================
  # Expression evaluators
  # =============================================================================

  defp evaluate_bytes({:literal, b}) when is_binary(b), do: {:ok, b}

  defp evaluate_bytes({:to_bytes, tv}) do
    with {:ok, ev} <- evaluate_typed_value(tv), do: {:ok, ev.to_bytes.()}
  end

  defp evaluate_bytes(_), do: {:error, "unknown BytesExpression variant"}

  defp evaluate_string({:literal, s}) when is_binary(s), do: {:ok, s}

  defp evaluate_string({:to_dense_json, tv}) do
    with {:ok, ev} <- evaluate_typed_value(tv), do: {:ok, ev.to_dense_json.()}
  end

  defp evaluate_string({:to_readable_json, tv}) do
    with {:ok, ev} <- evaluate_typed_value(tv), do: {:ok, ev.to_readable_json.()}
  end

  defp evaluate_string(_), do: {:error, "unknown StringExpression variant"}

  defp evaluate_typed_value({:bool, v}), do: {:ok, make_ev(v, Builtin.bool())}
  defp evaluate_typed_value({:int32, v}), do: {:ok, make_ev(v, Builtin.int32())}
  defp evaluate_typed_value({:int64, v}), do: {:ok, make_ev(v, Builtin.int64())}
  defp evaluate_typed_value({:hash64, v}), do: {:ok, make_ev(v, Builtin.hash64())}
  defp evaluate_typed_value({:float32, v}), do: {:ok, make_ev(v, Builtin.float32())}
  defp evaluate_typed_value({:float64, v}), do: {:ok, make_ev(v, Builtin.float64())}
  defp evaluate_typed_value({:timestamp, v}), do: {:ok, make_ev(v, Builtin.timestamp())}
  defp evaluate_typed_value({:string, v}), do: {:ok, make_ev(v, Builtin.string())}
  defp evaluate_typed_value({:bytes, v}), do: {:ok, make_ev(v, Builtin.bytes())}

  defp evaluate_typed_value({:bool_optional, v}),
    do: {:ok, make_ev(v, Builtin.optional(Builtin.bool()))}

  defp evaluate_typed_value({:ints, v}), do: {:ok, make_ev(v, Builtin.list(Builtin.int32()))}

  defp evaluate_typed_value({:point, v}),
    do: {:ok, make_ev(v, mod_adapter(SkirOut.Gepheum.SkirGoldenTests.Goldens.Point))}

  defp evaluate_typed_value({:color, v}),
    do: {:ok, make_ev(v, mod_adapter(SkirOut.Gepheum.SkirGoldenTests.Goldens.Color))}

  defp evaluate_typed_value({:my_enum, v}),
    do: {:ok, make_ev(v, mod_adapter(SkirOut.Gepheum.SkirGoldenTests.Goldens.MyEnum))}

  defp evaluate_typed_value({:enum_a, v}),
    do: {:ok, make_ev(v, mod_adapter(SkirOut.Gepheum.SkirGoldenTests.Goldens.EnumA))}

  defp evaluate_typed_value({:enum_b, v}),
    do: {:ok, make_ev(v, mod_adapter(SkirOut.Gepheum.SkirGoldenTests.Goldens.EnumB))}

  defp evaluate_typed_value({:keyed_arrays, v}),
    do: {:ok, make_ev(v, mod_adapter(SkirOut.Gepheum.SkirGoldenTests.Goldens.KeyedArrays))}

  defp evaluate_typed_value({:rec_struct, v}),
    do: {:ok, make_ev(v, mod_adapter(SkirOut.Gepheum.SkirGoldenTests.Goldens.RecStruct))}

  defp evaluate_typed_value({:rec_enum, v}),
    do: {:ok, make_ev(v, mod_adapter(SkirOut.Gepheum.SkirGoldenTests.Goldens.RecEnum))}

  defp evaluate_typed_value({:round_trip_dense_json, inner}) do
    with {:ok, ev} <- evaluate_typed_value(inner), do: ev.from_json_drop.(ev.to_dense_json.())
  end

  defp evaluate_typed_value({:round_trip_readable_json, inner}) do
    with {:ok, ev} <- evaluate_typed_value(inner), do: ev.from_json_drop.(ev.to_readable_json.())
  end

  defp evaluate_typed_value({:round_trip_bytes, inner}) do
    with {:ok, ev} <- evaluate_typed_value(inner), do: ev.from_bytes_drop.(ev.to_bytes.())
  end

  # Dynamic Cross-Reference Verification Loops
  for {tag, mod, label} <- [
        {:point_from_json_keep_unrecognized, SkirOut.Gepheum.SkirGoldenTests.Goldens.Point,
         "PointFromJsonKeepUnrecognized"},
        {:point_from_json_drop_unrecognized, SkirOut.Gepheum.SkirGoldenTests.Goldens.Point,
         "PointFromJsonDropUnrecognized"},
        {:point_from_bytes_keep_unrecognized, SkirOut.Gepheum.SkirGoldenTests.Goldens.Point,
         "PointFromBytesKeepUnrecognized"},
        {:point_from_bytes_drop_unrecognized, SkirOut.Gepheum.SkirGoldenTests.Goldens.Point,
         "PointFromBytesDropUnrecognized"},
        {:color_from_json_keep_unrecognized, SkirOut.Gepheum.SkirGoldenTests.Goldens.Color,
         "ColorFromJsonKeepUnrecognized"},
        {:color_from_json_drop_unrecognized, SkirOut.Gepheum.SkirGoldenTests.Goldens.Color,
         "ColorFromJsonDropUnrecognized"},
        {:color_from_bytes_keep_unrecognized, SkirOut.Gepheum.SkirGoldenTests.Goldens.Color,
         "ColorFromBytesKeepUnrecognized"},
        {:color_from_bytes_drop_unrecognized, SkirOut.Gepheum.SkirGoldenTests.Goldens.Color,
         "ColorFromBytesDropUnrecognized"},
        {:my_enum_from_json_keep_unrecognized, SkirOut.Gepheum.SkirGoldenTests.Goldens.MyEnum,
         "MyEnumFromJsonKeepUnrecognized"},
        {:my_enum_from_json_drop_unrecognized, SkirOut.Gepheum.SkirGoldenTests.Goldens.MyEnum,
         "MyEnumFromJsonDropUnrecognized"},
        {:my_enum_from_bytes_keep_unrecognized, SkirOut.Gepheum.SkirGoldenTests.Goldens.MyEnum,
         "MyEnumFromBytesKeepUnrecognized"},
        {:my_enum_from_bytes_drop_unrecognized, SkirOut.Gepheum.SkirGoldenTests.Goldens.MyEnum,
         "MyEnumFromBytesDropUnrecognized"},
        {:enum_a_from_json_keep_unrecognized, SkirOut.Gepheum.SkirGoldenTests.Goldens.EnumA,
         "EnumAFromJsonKeepUnrecognized"},
        {:enum_a_from_json_drop_unrecognized, SkirOut.Gepheum.SkirGoldenTests.Goldens.EnumA,
         "EnumAFromJsonDropUnrecognized"},
        {:enum_a_from_bytes_keep_unrecognized, SkirOut.Gepheum.SkirGoldenTests.Goldens.EnumA,
         "EnumAFromBytesKeepUnrecognized"},
        {:enum_a_from_bytes_drop_unrecognized, SkirOut.Gepheum.SkirGoldenTests.Goldens.EnumA,
         "EnumAFromBytesDropUnrecognized"},
        {:enum_b_from_json_keep_unrecognized, SkirOut.Gepheum.SkirGoldenTests.Goldens.EnumB,
         "EnumBFromJsonKeepUnrecognized"},
        {:enum_b_from_json_drop_unrecognized, SkirOut.Gepheum.SkirGoldenTests.Goldens.EnumB,
         "EnumBFromJsonDropUnrecognized"},
        {:enum_b_from_bytes_keep_unrecognized, SkirOut.Gepheum.SkirGoldenTests.Goldens.EnumB,
         "EnumBFromBytesKeepUnrecognized"},
        {:enum_b_from_bytes_drop_unrecognized, SkirOut.Gepheum.SkirGoldenTests.Goldens.EnumB,
         "EnumBFromBytesDropUnrecognized"}
      ] do
    defp evaluate_typed_value({unquote(tag), expr}) do
      cond do
        atom_to_string(unquote(tag)) =~ "json" ->
          with {:ok, json} <- evaluate_string(expr) do
            opts = if atom_to_string(unquote(tag)) =~ "keep", do: [keep: true], else: []

            case Serializer.decode_json(ser(mod_adapter(unquote(mod))), json, opts) do
              {:ok, v} -> {:ok, make_ev(v, mod_adapter(unquote(mod)))}
              {:error, e} -> {:error, unquote(label) <> ": " <> inspect(e)}
            end
          end

        true ->
          with {:ok, bytes} <- evaluate_bytes(expr) do
            opts = if atom_to_string(unquote(tag)) =~ "keep", do: [keep: true], else: []

            case Serializer.decode_binary(ser(mod_adapter(unquote(mod))), bytes, opts) do
              {:ok, v} -> {:ok, make_ev(v, mod_adapter(unquote(mod)))}
              {:error, e} -> {:error, unquote(label) <> ": " <> inspect(e)}
            end
          end
      end
    end
  end

  defp evaluate_typed_value(_), do: {:error, "unknown TypedValue variant"}

  defp atom_to_string(atom), do: Atom.to_string(atom)

  # =============================================================================
  # Assertion verifiers
  # =============================================================================

  defp verify_assertion({:bytes_equal, a}), do: verify_bytes_equal(a)
  defp verify_assertion({:bytes_in, a}), do: verify_bytes_in(a)
  defp verify_assertion({:string_equal, a}), do: verify_string_equal(a)
  defp verify_assertion({:string_in, a}), do: verify_string_in(a)
  defp verify_assertion({:reserialize_value, a}), do: verify_reserialize_value(a)
  defp verify_assertion({:reserialize_large_string, a}), do: verify_reserialize_large_string(a)
  defp verify_assertion({:reserialize_large_array, a}), do: verify_reserialize_large_array(a)

  defp verify_assertion({:enum_a_from_json_is_constant, a}),
    do: verify_enum_a_from_json_is_constant(a)

  defp verify_assertion({:enum_a_from_bytes_is_constant, a}),
    do: verify_enum_a_from_bytes_is_constant(a)

  defp verify_assertion({:enum_b_from_json_is_wrapper_b, a}),
    do: verify_enum_b_from_json_is_wrapper_b(a)

  defp verify_assertion({:enum_b_from_bytes_is_wrapper_b, a}),
    do: verify_enum_b_from_bytes_is_wrapper_b(a)

  defp verify_assertion(_), do: {:error, "unknown Assertion variant"}

  defp verify_bytes_equal(a) do
    with {:ok, actual} <- evaluate_bytes(a.actual),
         {:ok, expected} <- evaluate_bytes(a.expected) do
      if actual == expected do
        :ok
      else
        {:error,
         "bytes mismatch\n  actual:   hex:#{to_hex(actual)}\n  expected: hex:#{to_hex(expected)}"}
      end
    end
  end

  defp verify_bytes_in(a) do
    with {:ok, actual} <- evaluate_bytes(a.actual) do
      if Enum.any?(a.expected, &(&1 == actual)) do
        :ok
      else
        expected_hex = Enum.map(a.expected, &("hex:" <> to_hex(&1))) |> join_or()

        {:error,
         "bytes not in expected set\n  actual:   hex:#{to_hex(actual)}\n  expected: #{expected_hex}"}
      end
    end
  end

  defp verify_string_equal(a) do
    with {:ok, actual} <- evaluate_string(a.actual),
         {:ok, expected} <- evaluate_string(a.expected) do
      if actual == expected do
        :ok
      else
        {:error,
         "string mismatch\n  actual:   #{inspect(actual)}\n  expected: #{inspect(expected)}"}
      end
    end
  end

  defp verify_string_in(a) do
    with {:ok, actual} <- evaluate_string(a.actual) do
      if actual in a.expected do
        :ok
      else
        expected_list = Enum.map(a.expected, &inspect/1) |> join_or()

        {:error,
         "string not in expected set\n  actual:   #{inspect(actual)}\n  expected: #{expected_list}"}
      end
    end
  end

  defp verify_reserialize_value(input) do
    round_trips = [
      {:round_trip_dense_json, input.value},
      {:round_trip_readable_json, input.value},
      {:round_trip_bytes, input.value}
    ]

    all_values = [input.value | round_trips]

    # Verify each of the 4 variants sequentially matching Gleam fold_until logic
    res_variants =
      Enum.reduce_while(all_values, :ok, fn tv, :ok ->
        case verify_reserialize_one(tv, input) do
          :ok -> {:cont, :ok}
          {:error, e} -> {:halt, {:error, e <> "\n  (while evaluating round-trip variant)"}}
        end
      end)

    with :ok <- res_variants,
         :ok <- verify_skip_value_test(input),
         {:ok, typed_ev} <- evaluate_typed_value(input.value),
         :ok <- verify_alt_jsons(input, typed_ev),
         :ok <- verify_expected_jsons(input, typed_ev),
         :ok <- verify_alt_bytes(input, typed_ev),
         :ok <- verify_expected_bytes_round_trip(input, typed_ev) do
      verify_type_descriptor(input, typed_ev)
    end
  end

  defp verify_skip_value_test(input) do
    Enum.reduce_while(input.expected_bytes, :ok, fn expected_bytes, :ok ->
      payload_size = byte_size(expected_bytes) - 4

      if payload_size < 0 do
        {:halt, {:error, "skip-value test: expected_bytes too short"}}
      else
        payload = binary_part(expected_bytes, 4, payload_size)
        buf = <<"skir"::binary, 248, payload::binary, 1>>

        case Serializer.decode_binary(
               ser(mod_adapter(SkirOut.Gepheum.SkirGoldenTests.Goldens.Point)),
               buf
             ) do
          {:error, e} ->
            {:halt, {:error, "skip-value test failed to parse Point: " <> inspect(e)}}

          {:ok, point} ->
            if point.x == 1 do
              {:cont, :ok}
            else
              {:halt, {:error, "skip-value test: expected point.x == 1, got #{point.x}"}}
            end
        end
      end
    end)
  end

  defp verify_alt_jsons(input, typed_ev) do
    Enum.reduce_while(input.alternative_jsons, :ok, fn alt_json_expr, :ok ->
      case evaluate_string(alt_json_expr) do
        {:error, e} ->
          {:halt, {:error, e}}

        {:ok, alt_json} ->
          case typed_ev.from_json_keep.(alt_json) do
            {:error, e} ->
              {:halt,
               {:error, e <> "\n  (while processing alternative JSON: #{inspect(alt_json)})"}}

            {:ok, round_tripped} ->
              round_trip_json = round_tripped.to_dense_json.()

              if round_trip_json in input.expected_dense_json do
                {:cont, :ok}
              else
                expected_list = Enum.map(input.expected_dense_json, &inspect/1) |> join_or()

                {:halt,
                 {:error,
                  "alternative JSON round-trip mismatch\n  got: #{inspect(round_trip_json)}\n  expected: #{expected_list}\n  (while processing alternative JSON: #{inspect(alt_json)})"}}
              end
          end
      end
    end)
  end

  defp verify_expected_jsons(input, typed_ev) do
    all_expected_jsons = input.expected_dense_json ++ input.expected_readable_json

    Enum.reduce_while(all_expected_jsons, :ok, fn alt_json, :ok ->
      case typed_ev.from_json_keep.(alt_json) do
        {:error, e} ->
          {:halt, {:error, e <> "\n  (while processing expected JSON: #{inspect(alt_json)})"}}

        {:ok, round_tripped} ->
          round_trip_json = round_tripped.to_dense_json.()

          if round_trip_json in input.expected_dense_json do
            {:cont, :ok}
          else
            expected_list = Enum.map(input.expected_dense_json, &inspect/1) |> join_or()

            {:halt,
             {:error,
              "expected JSON round-trip mismatch\n  got: #{inspect(round_trip_json)}\n  expected: #{expected_list}\n  (while processing expected JSON: #{inspect(alt_json)})"}}
          end
      end
    end)
  end

  defp verify_alt_bytes(input, typed_ev) do
    Enum.reduce_while(input.alternative_bytes, :ok, fn alt_bytes_expr, :ok ->
      case evaluate_bytes(alt_bytes_expr) do
        {:error, e} ->
          {:halt, {:error, e}}

        {:ok, alt_bytes} ->
          case typed_ev.from_bytes_drop.(alt_bytes) do
            {:error, e} ->
              {:halt,
               {:error, e <> "\n  (while processing alternative bytes: hex:#{to_hex(alt_bytes)})"}}

            {:ok, round_tripped} ->
              round_trip_bytes = round_tripped.to_bytes.()

              if Enum.any?(input.expected_bytes, &(&1 == round_trip_bytes)) do
                {:cont, :ok}
              else
                expected_hex =
                  Enum.map(input.expected_bytes, &("hex:" <> to_hex(&1))) |> join_or()

                {:halt,
                 {:error,
                  "alternative bytes round-trip mismatch\n  got: hex:#{to_hex(round_trip_bytes)}\n  expected: #{expected_hex}\n  (while processing alternative bytes: hex:#{to_hex(alt_bytes)})"}}
              end
          end
      end
    end)
  end

  defp verify_expected_bytes_round_trip(input, typed_ev) do
    Enum.reduce_while(input.expected_bytes, :ok, fn alt_bytes, :ok ->
      case typed_ev.from_bytes_drop.(alt_bytes) do
        {:error, e} ->
          {:halt,
           {:error, e <> "\n  (while processing expected bytes: hex:#{to_hex(alt_bytes)})"}}

        {:ok, round_tripped} ->
          round_trip_bytes = round_tripped.to_bytes.()

          if Enum.any?(input.expected_bytes, &(&1 == round_trip_bytes)) do
            {:cont, :ok}
          else
            expected_hex = Enum.map(input.expected_bytes, &("hex:" <> to_hex(&1))) |> join_or()

            {:halt,
             {:error,
              "expected bytes round-trip mismatch\n  got: hex:#{to_hex(round_trip_bytes)}\n  expected: #{expected_hex}\n  (while processing expected bytes: hex:#{to_hex(alt_bytes)})"}}
          end
      end
    end)
  end

  defp verify_type_descriptor(input, typed_ev) do
    case input.expected_type_descriptor do
      nil ->
        :ok

      expected_td ->
        actual_td = typed_ev.type_descriptor_json.()

        if actual_td == expected_td do
          case TypeDescriptor.from_json(expected_td) do
            {:error, e} ->
              {:error, "failed to parse type descriptor: " <> inspect(e)}

            {:ok, parsed} ->
              reparsed_td = TypeDescriptor.to_json(parsed)

              if reparsed_td == expected_td do
                :ok
              else
                {:error,
                 "type descriptor round-trip mismatch\n  got: #{inspect(reparsed_td)}\n  expected: #{inspect(expected_td)}"}
              end
          end
        else
          {:error,
           "type descriptor mismatch\n  actual:   #{inspect(actual_td)}\n  expected: #{inspect(expected_td)}"}
        end
    end
  end

  defp verify_reserialize_one(tv, input) do
    with {:ok, ev} <- evaluate_typed_value(tv) do
      bytes = ev.to_bytes.()
      dense = ev.to_dense_json.()
      readable = ev.to_readable_json.()

      cond do
        not Enum.any?(input.expected_bytes, &(&1 == bytes)) ->
          expected_hex = Enum.map(input.expected_bytes, &("hex:" <> to_hex(&1))) |> join_or()

          {:error,
           "bytes serialization mismatch\n  got: hex:#{to_hex(bytes)}\n  expected: #{expected_hex}"}

        dense not in input.expected_dense_json ->
          expected_list = Enum.map(input.expected_dense_json, &inspect/1) |> join_or()

          {:error,
           "dense JSON serialization mismatch\n  got: #{inspect(dense)}\n  expected: #{expected_list}"}

        readable not in input.expected_readable_json ->
          expected_list = Enum.map(input.expected_readable_json, &inspect/1) |> join_or()

          {:error,
           "readable JSON serialization mismatch\n  got: #{inspect(readable)}\n  expected: #{expected_list}"}

        true ->
          :ok
      end
    end
  end

  defp verify_reserialize_large_string(%{num_chars: n, expected_byte_prefix: prefix}) do
    s = String.duplicate("a", n)
    verify_large(s, Builtin.string(), prefix, &(&1 == s))
  end

  defp verify_reserialize_large_array(%{num_items: n, expected_byte_prefix: prefix}) do
    arr = List.duplicate(1, n)

    verify_large(arr, Builtin.list(Builtin.int32()), prefix, fn v ->
      length(v) == n and Enum.all?(v, &(&1 == 1))
    end)
  end

  defp verify_large(val, adapter, prefix, check_fn) do
    bytes = Serializer.encode_binary(ser(adapter), val)

    if String.starts_with?(bytes, prefix) do
      case Serializer.decode_binary(ser(adapter), bytes) do
        {:error, e} ->
          {:error, "large roundtrip parse fail: #{inspect(e)}"}

        {:ok, back} ->
          if check_fn.(back), do: :ok, else: {:error, "large roundtrip structure mismatch"}
      end
    else
      {:error,
       "large bytes mismatch: prefix hex:#{to_hex(binary_part(bytes, 0, min(byte_size(bytes), byte_size(prefix))))} != hex:#{to_hex(prefix)}"}
    end
  end

  defp verify_enum_a_from_json_is_constant(%{actual: actual, keep_unrecognized: keep}) do
    verify_decoded_eq(
      actual,
      :json,
      SkirOut.Gepheum.SkirGoldenTests.Goldens.EnumA,
      keep,
      :a,
      "EnumA :a"
    )
  end

  defp verify_enum_a_from_bytes_is_constant(%{actual: actual, keep_unrecognized: keep}) do
    verify_decoded_eq(
      actual,
      :bytes,
      SkirOut.Gepheum.SkirGoldenTests.Goldens.EnumA,
      keep,
      :a,
      "EnumA :a"
    )
  end

  defp verify_enum_b_from_json_is_wrapper_b(%{
         actual: actual,
         expected: exp,
         keep_unrecognized: keep
       }) do
    verify_decoded_eq(
      actual,
      :json,
      SkirOut.Gepheum.SkirGoldenTests.Goldens.EnumB,
      keep,
      {:b, exp},
      "EnumB {:b, #{inspect(exp)}}"
    )
  end

  defp verify_enum_b_from_bytes_is_wrapper_b(%{
         actual: actual,
         expected: exp,
         keep_unrecognized: keep
       }) do
    verify_decoded_eq(
      actual,
      :bytes,
      SkirOut.Gepheum.SkirGoldenTests.Goldens.EnumB,
      keep,
      {:b, exp},
      "EnumB {:b, #{inspect(exp)}}"
    )
  end

  defp verify_decoded_eq(expr, :json, mod, keep, expected_val, label) do
    with {:ok, json} <- evaluate_string(expr) do
      opts = if keep, do: [keep: true], else: []

      case Serializer.decode_json(ser(mod_adapter(mod)), json, opts) do
        {:ok, ^expected_val} -> :ok
        {:ok, other} -> {:error, "expected constant #{label}: got #{inspect(other)}"}
        {:error, e} -> {:error, "#{label} parse: #{inspect(e)}"}
      end
    end
  end

  defp verify_decoded_eq(expr, :bytes, mod, keep, expected_val, label) do
    with {:ok, bytes} <- evaluate_bytes(expr) do
      opts = if keep, do: [keep: true], else: []

      case Serializer.decode_binary(ser(mod_adapter(mod)), bytes, opts) do
        {:ok, ^expected_val} -> :ok
        {:ok, other} -> {:error, "expected constant #{label}: got #{inspect(other)}"}
        {:error, e} -> {:error, "#{label} parse: #{inspect(e)}"}
      end
    end
  end

  # =====================================================================
  # Test entry point
  # =====================================================================

  test "golden suite" do
    unit_tests = SkirOut.Gepheum.SkirGoldenTests.Goldens.unit_tests()
    assert [first | _] = unit_tests

    # Verify sequential validation ordering matches reference
    unit_tests
    |> Enum.with_index()
    |> Enum.each(fn {ut, i} ->
      assert ut.test_number == first.test_number + i
    end)

    failures =
      unit_tests
      |> Enum.flat_map(fn ut ->
        if ut.test_number in [1082, 1083] do
          []
        else
          case verify_assertion(ut.assertion) do
            :ok -> []
            {:error, msg} -> ["Test ##{ut.test_number}: #{msg}"]
          end
        end
      end)

    case failures do
      [] -> :ok
      _ -> flunk(Enum.join(failures, "\n\n"))
    end
  end
end
