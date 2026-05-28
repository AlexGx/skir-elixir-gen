# temporary
defmodule EncodeBinaryDiffTest do
  use ExUnit.Case
  alias SkirOut.Gepheum.SkirGoldenTests.Goldens, as: G

  test "generated __skir_encode_binary__ matches runtime to_binary" do
    values = [
      {G.Point, G.Point.default()},
      {G.Point, G.Point.partial(%{x: 42, y: -7})},
      {G.Color, G.Color.default()},
      {G.Color, G.Color.partial(%{r: 255, g: 128, b: 64})},
      {G.KeyedArrays, G.KeyedArrays.default()},
      {G.RecStruct, G.RecStruct.default()},
      {G.RecStruct, G.RecStruct.partial(%{b: true})}
    ]

    for {mod, val} <- values do
      old = mod.to_binary(val)
      new = IO.iodata_to_binary(mod.__skir_encode_binary__(val, ["skir"]))
      assert old == new, "#{inspect(mod)} mismatch:\n  old: #{Base.encode16(old)}\n  new: #{Base.encode16(new)}"
    end
  end
end
