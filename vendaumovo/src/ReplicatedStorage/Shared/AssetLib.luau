--[[
	AssetLib: pega os modelos de ReplicatedStorage > Assets ("Ovo_Dourado", "Galinha_Cristal", "Banca"...).
	Para trocar pela arte 3D de verdade: importe o modelo, coloque em Assets com o MESMO nome e apague o antigo.
	Nada no código muda: o jogo ajusta o tamanho (Config.AssetHeights), coloca a base no chão e tira scripts.

	No mapa, cada objeto de cenário tem o atributo "Asset" (ex.: "Arvore"). Quando o servidor liga,
	ele troca cada um pela versão atual de Assets, no mesmo lugar e tamanho. Assim, trocar o Model
	em Assets troca TODAS as árvores do mapa de uma vez.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetLib = {}

local function assetsFolder(): Instance?
	return ReplicatedStorage:FindFirstChild("Assets")
end

function AssetLib.Has(name: string): boolean
	local folder = assetsFolder()
	return folder ~= nil and folder:FindFirstChild(name) ~= nil
end

-- Cópia pronta para usar: base no chão em (0,0,0), ancorada, sem scripts.
-- height: altura final em studs (nil = mantém o tamanho do modelo).
function AssetLib.Get(name: string, height: number?): Model?
	local folder = assetsFolder()
	local source = folder and folder:FindFirstChild(name)
	if not source then
		return nil
	end
	local model: Model
	if source:IsA("Model") then
		model = source:Clone()
	else
		model = Instance.new("Model")
		model.Name = name
		source:Clone().Parent = model
	end
	local hasPart = false
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			hasPart = true
		end
	end
	if not hasPart then
		model:Destroy()
		return nil
	end
	if height then
		local _, size = model:GetBoundingBox()
		if size.Y > 0.01 and math.abs(size.Y - height) > 0.01 then
			pcall(function()
				model:ScaleTo(model:GetScale() * height / size.Y)
			end)
		end
	end
	local cf, size = model:GetBoundingBox()
	-- coloca a base no chão e o centro em x/z = 0, mantendo o giro do modelo
	model:PivotTo(model:GetPivot() - (cf.Position - Vector3.new(0, size.Y / 2, 0)))
	model:SetAttribute("Asset", name)
	return model
end

-- Coloca a base do modelo (já normalizado por Get) no ponto "base", virado "yaw" graus
function AssetLib.PlaceAt(model: Model, base: Vector3, yaw: number?)
	local cf, size = model:GetBoundingBox()
	local bottomCenter = Vector3.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z)
	local pivot = model:GetPivot()
	local offset = pivot.Position - bottomCenter
	local rotation = CFrame.Angles(0, math.rad(yaw or 0), 0)
	model:PivotTo(CFrame.new(base) * rotation * CFrame.new(offset) * pivot.Rotation)
end

-- Solda todas as peças ao "root" (para carregar o modelo grudado no personagem)
function AssetLib.WeldTo(model: Model, root: BasePart)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = d
			weld.Parent = d
		end
	end
end

function AssetLib.SetCollide(model: Model, collide: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = collide
			if not collide then
				d.CanTouch = false
			end
		end
	end
end

-- Troca os objetos de cenário (atributo "Asset") pela versão atual de ReplicatedStorage > Assets.
-- Atributos de cada objeto no mapa: Asset, BX/BY/BZ (base), Yaw (giro), H (altura).
function AssetLib.RefreshScenery(root: Instance)
	local list = {}
	for _, d in root:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("Asset") and d:GetAttribute("BX") then
			table.insert(list, d)
		end
	end
	local folder = assetsFolder()
	for _, old in list do
		local name = old:GetAttribute("Asset")
		local source = folder and folder:FindFirstChild(name)
		-- o modelo provisório (de peças) já está no mapa com as cores de cada granja: só troca quando
		-- você colocar um modelo novo em Assets (o novo não tem o atributo "Placeholder")
		if not source or source:GetAttribute("Placeholder") then
			continue
		end
		local new = AssetLib.Get(name, old:GetAttribute("H"))
		if new then
			AssetLib.PlaceAt(new, Vector3.new(old:GetAttribute("BX"), old:GetAttribute("BY"), old:GetAttribute("BZ")), old:GetAttribute("Yaw"))
			for key, value in old:GetAttributes() do
				new:SetAttribute(key, value)
			end
			new.Name = old.Name
			new.Parent = old.Parent
			old:Destroy()
		end
	end
end

return AssetLib
