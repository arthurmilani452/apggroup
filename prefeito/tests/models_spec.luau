-- Monta todos os prédios com as Instances de verdade (Lune) e confere tamanho e propriedades
return function(t)
	local Config = t.require("ReplicatedStorage/Shared/Config")
	local Buildings = t.require("ReplicatedStorage/Shared/Buildings")
	local BuildingModels = t.require("ReplicatedStorage/Shared/BuildingModels")
	local LotLayout = t.require("ReplicatedStorage/Shared/LotLayout")
	local Grid = t.require("ReplicatedStorage/Shared/Grid")
	local CELL = Config.CellSize

	for _, def in Buildings.List do
		local ok, model = pcall(BuildingModels.Build, def)
		if not ok then
			t.check(false, def.Id .. ": " .. tostring(model))
			continue
		end
		t.check(model.PrimaryPart ~= nil, def.Id .. " sem PrimaryPart")
		local parts = 0
		local halfW, halfD = def.W * CELL / 2 + 0.6, def.D * CELL / 2 + 0.6
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") then
				parts += 1
				t.check(item.Anchored, def.Id .. "." .. item.Name .. " solto")
				local p = item.CFrame.Position
				local bigX = item.Size.X
				-- cilindros e pás giradas: confere só o centro
				t.check(math.abs(p.X) <= halfW and math.abs(p.Z) <= halfD, ("%s.%s fora do terreno (%.1f, %.1f)"):format(def.Id, item.Name, p.X, p.Z))
				t.check(p.Y >= -0.01 and bigX > 0, def.Id .. "." .. item.Name .. " abaixo do chão")
			end
		end
		t.check(parts >= 2, def.Id .. " sem peças")
		t.check(parts <= 60, def.Id .. " pesado demais: " .. parts .. " peças")

		-- fantasma também monta
		local ghostOk, err = pcall(BuildingModels.MakeGhost, BuildingModels.Build(def), true)
		t.check(ghostOk, def.Id .. " fantasma: " .. tostring(err))
	end

	-- terrenos: cada um olha para o hub e não encosta no vizinho
	for i = 1, Config.MaxPlayers do
		local cf = LotLayout.CFrame(i)
		local toHub = -cf.Position.Unit
		t.check((cf.LookVector - toHub).Magnitude < 1e-3, "terreno " .. i .. " não olha para o hub")
		local cell = LotLayout.CellCFrame(i, 5, 7)
		local x, z = LotLayout.ToCell(i, cell.Position)
		t.eq(x, 5, "ToCell x no terreno " .. i)
		t.eq(z, 7, "ToCell z no terreno " .. i)
		t.check(LotLayout.Contains(i, cell.Position), "Contains no terreno " .. i)
		local nextIndex = i % Config.MaxPlayers + 1
		t.check(not LotLayout.Contains(nextIndex, cell.Position), "terreno " .. i .. " invade o vizinho")
	end
	-- os cantos do fundo dos terrenos vizinhos não se sobrepõem
	local N = Config.GridSize
	local corner = LotLayout.CellCFrame(1, N, N).Position
	t.check(not LotLayout.Contains(2, corner) and not LotLayout.Contains(Config.MaxPlayers, corner), "canto do fundo invade vizinho")

	-- prédio girado: o centro bate com a grade
	local placed = { X = 3, Z = 4, R = 1, W = 1, D = 2 }
	local cf = LotLayout.BuildingCFrame(1, placed)
	local cx, cz = Grid.Center(placed)
	t.check((cf.Position - LotLayout.CellCFrame(1, cx, cz).Position).Magnitude < 1e-4, "centro do prédio girado")
end
