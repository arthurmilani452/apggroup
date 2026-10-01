-- Testes do Rng (PCG32): confere com os valores de referência do pcg32 oficial (seed 42, stream 54)
return function(t)
	local Rng = t.require("ReplicatedStorage/Shared/Rng")
	local r = Rng.new(42, 54)
	local expected = { 0xa15c02b7, 0x7b47f409, 0xba1d3330, 0x83d2f293, 0xbfa4784b, 0xcbed606e }
	for i, value in expected do
		t.eq(r:NextU32(), value, "pcg32 saída " .. i)
	end
	t.eq(Rng.Hash("a"), 0xe40c292c, "fnv1a('a')")
	t.eq(Rng.Hash("foobar"), 0xbf9cf968, "fnv1a('foobar')")

	-- mesma seed = mesma sequência
	local a, b = Rng.new(99), Rng.new(99)
	for _ = 1, 50 do
		t.eq(a:NextInt(1, 1000), b:NextInt(1, 1000), "determinismo")
	end
	-- limites
	local c = Rng.new(7)
	local seen = {}
	for _ = 1, 5000 do
		local v = c:NextInt(1, 6)
		t.check(v >= 1 and v <= 6, "NextInt fora da faixa")
		seen[v] = true
		local f = c:NextFloat()
		t.check(f >= 0 and f < 1, "NextFloat fora da faixa")
	end
	for v = 1, 6 do
		t.check(seen[v], "NextInt nunca deu " .. v)
	end
	local item = c:WeightedPick({ { Weight = 0 }, { Weight = 5, Id = "x" } })
	t.eq(item and item.Id, "x", "WeightedPick ignora peso 0")
end
