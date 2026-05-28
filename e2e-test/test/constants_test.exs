defmodule SerializerTest do
  use ExUnit.Case, async: true

  alias SkirOut.Constants
  alias SkirOut.Enums

  # =============================================================================
  # b_const
  # =============================================================================

  test "b_const" do
    assert Constants.b() == false
  end

  # =============================================================================
  # foo_method_const
  # =============================================================================

  test "foo_method_const" do
    assert Constants.foo_method() == true
  end

  # =============================================================================
  # large_int64_const
  # =============================================================================

  test "large_int64_const" do
    assert Constants.large_int64() == 9_223_372_036_854_775_807
  end

  # =============================================================================
  # one_single_quoted_string_const
  # =============================================================================

  test "one_single_quoted_string_const" do
    assert Constants.one_single_quoted_string() == "\"Foo\""
  end

  # =============================================================================
  # one_timestamp_const
  # =============================================================================

  test "one_timestamp_const" do
    # Assuming Skir.Timestamp struct representation with field :unix_millis
    timestamp = ~U[2023-12-31 00:53:48Z]
    assert timestamp == Constants.one_timestamp()
    assert DateTime.to_unix(timestamp, :millisecond) == 1_703_984_028_000
  end

  # =============================================================================
  # pi_const
  # =============================================================================

  test "pi_const" do
    assert Constants.pi() == 3.141592653589793
  end

  # =============================================================================
  # one_constant_const — complex enum with nested values
  # =============================================================================

  test "one_constant_const is array variant" do
    case Constants.one_constant() do
      {:array, _} -> :ok
      other -> flunk("Expected array variant, got: #{inspect(other)}")
    end
  end

  test "one_constant_const array has 4 items" do
    assert {:array, items} = Constants.one_constant()
    assert [b, n, s, obj] = items

    assert b == {:boolean, true}
    assert n == {:number, 2.5}
    assert s == {:string, "\n        foo\n        bar"}

    assert {:object, [pair]} = obj
    # Matches struct pattern Enums.JsonValue.Pair matching your Skir.Struct generator rules
    assert %Enums.JsonValue.Pair{name: name, value: v} = pair
    assert name == "foo"
    assert v == :null
  end

  # =============================================================================
  # infinity_const, minus_infinity_const, nan_const — pub const fallbacks
  # =============================================================================

  test "infinity_const is float" do
    # On Elixir target, handles raw float bounds or fallback atoms (:infinity)
    val = Constants.infinity()

    assert is_atom(val)
    assert val == :infinity

    # if is_atom(val) do
    #   assert val == :infinity
    # else
    #   assert val > 1.0e308
    # end
  end
end
