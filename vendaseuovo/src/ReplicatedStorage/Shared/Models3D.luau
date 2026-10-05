--[[
	Models3D: usa MODELOS 3D de verdade (Higgsfield, Creator Store, gerador de IA do Studio) quando existirem.
	Sem modelo, o jogo usa as peças (nada quebra).

	Como usar:
	  1. No Studio: File > Import 3D e selecione TODOS os .glb de uma vez.
	  2. Arraste os modelos importados para ReplicatedStorage > Models3D (ou deixe no Workspace: o servidor leva sozinho).
	  3. O NOME do arquivo diz o que ele é (pode ter mais coisa no nome, ex.: "hf_galinha_caipira_123.glb"):
	       caipira, pintada, dourada        → galinhas
	       ovo, ovocozido                   → produtos da vitrine
	       barraca, ninho, fogao, carroca, fonte, granja → cenário
	Atributos opcionais no modelo importado:
	  Turn = gira (graus: 0, 90, 180, 270) se aparecer de lado/de costas
	  Size = altura em studs (se quiser maior ou menor que o padrão)
	  Lift = sobe/desce (studs) se ficar enterrado ou flutuando
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Models3D = {}

-- nome curto → palavras que podem aparecer no nome do arquivo (a mais específica primeiro)
Models3D.Ids = {
	ovocozido = { "ovocozido", "ovo_cozido", "boiledegg", "boiled_egg" },
	caipira = { "caipira" },
	pintada = { "pintada" },
	dourada = { "dourada" },
	ovo = { "ovo", "egg" },
	barraca = { "barraca", "stand" },
	ninho = { "ninho", "nest" },
	fogao = { "fogao", "stove" },
	carroca = { "carroca", "cart" },
	fonte = { "fonte", "fountain" },
	granja = { "granja", "farmshop" },
}
local ORDER = { "ovocozido", "caipira", "pintada", "dourada", "barraca", "ninho", "fogao", "carroca", "fonte", "granja", "ovo" }

local found: { [string]: Instance } = {}
local scanned = false

local function folder(): Instance?
	local f = ReplicatedStorage:FindFirstChild("Models3D")
	if not f and RunService:IsServer() then
		local newFolder = Instance.new("Folder")
		newFolder.Name = "Models3D"
		newFolder.Parent = ReplicatedStorage
		f = newFolder
	end
	return f
end

local function classify(name: string): string?
	local lower = string.lower(name)
	for _, id in ORDER do
		for _, word in Models3D.Ids[id] do
			if string.find(lower, word, 1, true) then
				return id
			end
		end
	end
	return nil
end

local function scan()
	local f = folder()
	-- o servidor leva para Models3D os modelos importados que ficaram soltos no Workspace
	if RunService:IsServer() and f then
		for _, child in workspace:GetChildren() do
			if child:IsA("Model") and classify(child.Name) and not child:FindFirstChildOfClass("Humanoid") then
				child.Parent = f
			end
		end
	end
	if not f then
		return
	end
	for _, child in f:GetChildren() do
		local id = classify(child.Name)
		if id and not found[id] then
			found[id] = child
		end
	end
	scanned = true
end

function Models3D.Has(id: string): boolean
	if not scanned then
		scan()
	end
	return found[id] ~= nil
end

-- Cópia normalizada: base no chão (y = 0), centro em x/z = 0, altura "height" (ou o atributo Size).
-- Sem scripts, ancorada, sem colisão, com um "Root" invisível como PrimaryPart (soldado ao resto).
function Models3D.Get(id: string, height: number): Model?
	if not scanned then
		scan()
	end
	local source = found[id]
	if not source then
		return nil
	end
	local model: Model
	if source:IsA("Model") then
		model = source:Clone()
	else
		model = Instance.new("Model")
		source:Clone().Parent = model
	end
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	local turn = tonumber(source:GetAttribute("Turn")) or 0
	local size = tonumber(source:GetAttribute("Size")) or height
	local lift = tonumber(source:GetAttribute("Lift")) or 0
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.Massless = true
			table.insert(parts, d)
		end
	end
	if #parts == 0 then
		model:Destroy()
		return nil
	end
	if turn ~= 0 then
		local pivot = model:GetPivot()
		model:PivotTo(CFrame.new(pivot.Position) * CFrame.Angles(0, math.rad(turn), 0) * pivot.Rotation)
	end
	local _, box = model:GetBoundingBox()
	if box.Y > 0 then
		pcall(function()
			model:ScaleTo(model:GetScale() * size / box.Y)
		end)
	end
	local cf, newBox = model:GetBoundingBox()
	-- centro nos pés
	local offset = Vector3.new(-cf.Position.X, -cf.Position.Y + newBox.Y / 2 + lift, -cf.Position.Z)
	for _, p in parts do
		p.CFrame = p.CFrame + offset
	end
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = newBox
	root.CFrame = CFrame.new(0, newBox.Y / 2, 0)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.Massless = true
	root.Parent = model
	for _, p in parts do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
	end
	model.PrimaryPart = root
	model:SetAttribute("Is3D", true)
	return model
end

return Models3D
