-- Testes da grade: limites, ocupação, rotação, ruas ligadas e salvar/carregar
return function(t)
	local Config = t.require("ReplicatedStorage/Shared/Config")
	local Buildings = t.require("ReplicatedStorage/Shared/Buildings")
	local Grid = t.require("ReplicatedStorage/Shared/Grid")
	local def = Buildings.ById

	-- todo prédio tem dados válidos
	for _, b in Buildings.List do
		t.check(b.W >= 1 and b.D >= 1 and b.Cost > 0, "dados ruins em " .. b.Id)
		t.check(b.Tier >= 1 and b.Tier <= #Config.Tiers, "tier ruim em " .. b.Id)
		t.check(b.Model and b.Model.Kind, "sem modelo em " .. b.Id)
	end

	-- expansão 1 = 12 de largura, centralizada, começando depois da avenida
	local x1, x2, z1, z2 = Grid.Bounds(1)
	t.eq(x1, 7, "x1"); t.eq(x2, 18, "x2"); t.eq(z1, 2, "z1"); t.eq(z2, 13, "z2")
	local a, b, c, d = Grid.Bounds(4)
	t.eq(a, 1, "x1 cheio"); t.eq(b, 24, "x2 cheio"); t.eq(c, 2, "z1 cheio"); t.eq(d, 24, "z2 cheio")

	local s = Grid.new()
	t.check(Grid.CanPlace(s, 1, def.casa, 7, 2, 0), "casa no canto liberado")
	t.check(not Grid.CanPlace(s, 1, def.casa, 6, 2, 0), "fora à esquerda")
	t.check(not Grid.CanPlace(s, 1, def.casa, 7, 1, 0), "na avenida")
	t.check(not Grid.CanPlace(s, 1, def.casa, 7, 2, 4), "rotação inválida")
	t.check(not Grid.CanPlace(s, 1, def.casa, 7.5, 2, 0), "posição quebrada")
	t.check(not Grid.CanPlace(s, 1, def.shopping, 17, 2, 0), "3x3 passando da borda")
	t.check(Grid.CanPlace(s, 1, def.shopping, 16, 2, 0), "3x3 encostado na borda")

	-- prédio que não é quadrado: rotação troca largura e profundidade
	local fake = { Id = "fake", W = 2, D = 1 }
	local w, dd = Buildings.Footprint(fake, 1)
	t.eq(w, 1, "w girado"); t.eq(dd, 2, "d girado")

	local uid = Grid.Place(s, def.mercado, 8, 3, 0)
	t.eq(Grid.At(s, 9, 4), uid, "mercado ocupa 2x2")
	t.check(not Grid.CanPlace(s, 1, def.casa, 9, 4, 0), "ocupado")
	t.eq(s.Count, 1, "contagem")

	-- ruas: mercado em (8..9, 3..4) não encosta na avenida (z = 1), precisa de rua em z = 2
	local conn = Grid.Connected(s)
	t.check(not Grid.HasAccess(s, conn, s.Buildings[uid]), "sem rua ainda")
	Grid.Place(s, def.rua, 8, 2, 0)
	conn = Grid.Connected(s)
	t.check(Grid.HasAccess(s, conn, s.Buildings[uid]), "rua ligada à avenida")
	-- rua solta, longe da avenida, não liga
	local s2 = Grid.new()
	Grid.Place(s2, def.rua, 10, 6, 0)
	local house = Grid.Place(s2, def.casa, 10, 7, 0)
	t.check(not Grid.HasAccess(s2, Grid.Connected(s2), s2.Buildings[house]), "rua solta não conta")
	for z = 2, 5 do
		Grid.Place(s2, def.rua, 10, z, 0)
	end
	t.check(Grid.HasAccess(s2, Grid.Connected(s2), s2.Buildings[house]), "rua emendada até a avenida")
	-- diagonal não vale
	local s3 = Grid.new()
	local h3 = Grid.Place(s3, def.casa, 10, 3, 0)
	Grid.Place(s3, def.rua, 11, 2, 0)
	t.check(not Grid.HasAccess(s3, Grid.Connected(s3), s3.Buildings[h3]), "diagonal não vale")

	-- remover libera as casas
	Grid.Remove(s, uid)
	t.check(Grid.At(s, 9, 4) == nil, "liberou")
	t.eq(s.Count, 1, "sobrou a rua")

	-- salvar e carregar
	local s4 = Grid.new()
	Grid.Place(s4, def.casa, 7, 2, 0)
	Grid.Place(s4, def.mercado, 8, 2, 1)
	local saved = Grid.Serialize(s4)
	t.eq(#saved, 2, "2 itens salvos")
	local back = Grid.Deserialize(saved, 1)
	t.eq(back.Count, 2, "2 itens carregados")
	-- lixo e sobreposição são ignorados
	local junk = Grid.Deserialize({ "casa,7,2,0", "casa,7,2,0", "nada,1,1,0", "casa,1,2,0", 5, "casa,8,2" }, 1)
	t.eq(junk.Count, 1, "só o primeiro vale")

	-- conversão casa <-> studs ida e volta
	local lx, lz = Grid.LocalPosition(5, 9)
	local cx, cz = Grid.CellAt(lx, lz)
	t.eq(cx, 5, "cx"); t.eq(cz, 9, "cz")
end
