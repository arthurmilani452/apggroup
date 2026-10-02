--[[
	Lots (ModuleScript em ServerScriptService > Game)          Prefeito Tycoon
	Os terrenos: monta o chão, a Avenida, a Prefeitura, o Cofre e o caminho até o hub; dá um
	terreno para cada jogador; desenha e apaga os prédios.

	No Workspace:  Lots > Lot1..Lot8
	  atributos: Owner (UserId, 0 = livre), OwnerName, CityName, Population, Stars, Happiness, Expansion
	  Buildings (Folder): um Model por prédio, com atributos Uid, Id, X, Z, R (o cliente lê daqui)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Buildings = require(Shared.Buildings)
local BuildingModels = require(Shared.BuildingModels)
local Grid = require(Shared.Grid)
local LotLayout = require(Shared.LotLayout)

local Lots = {}

type Lot = {
	Index: number,
	Model: Model,
	Buildings: Folder,
	Owner: Player?,
	Unlocked: Part,
	Sign: TextLabel,
	VaultLabel: TextLabel,
	VaultPrompt: ProximityPrompt,
	Rendered: { [number]: Model },
}

local lots: { Lot } = {}
local root: Folder

local CELL = Config.CellSize
local N = Config.GridSize
local SIZE = N * CELL

-- Chamado quando o dono aperta o cofre (o City preenche)
Lots.OnVault = nil :: ((Player, number) -> ())?

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function surfaceText(target: BasePart, face: Enum.NormalId, text: string, color: Color3): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	gui.Parent = target
	return label
end

local function buildLot(index: number): Lot
	local cf = LotLayout.CFrame(index)
	local function L(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end

	local model = Instance.new("Model")
	model.Name = "Lot" .. index
	model:SetAttribute("Index", index)
	model:SetAttribute("Owner", 0)
	model:SetAttribute("OwnerName", "")
	model:SetAttribute("CityName", "Terreno livre")
	model:SetAttribute("Population", 0)
	model:SetAttribute("Stars", 0)
	model:SetAttribute("Happiness", 0)
	model:SetAttribute("Expansion", 1)

	-- chão do terreno (área travada) + área liberada por cima
	local ground = part(model, "Ground", Vector3.new(SIZE, 1, SIZE), L(0, -0.5, SIZE / 2), Color3.fromRGB(46, 58, 46), Enum.Material.Ground)
	ground.CastShadow = false
	local unlocked = part(model, "Unlocked", Vector3.new(1, 0.1, 1), L(0, 0.05, SIZE / 2), Color3.fromRGB(86, 120, 76), Enum.Material.Grass)
	unlocked.CastShadow = false
	unlocked.CanCollide = false

	-- Avenida (fileira z = 1) de ponta a ponta
	local avenue = part(model, "Avenue", Vector3.new(SIZE, 0.3, CELL), L(0, 0.15, CELL / 2), Color3.fromRGB(38, 40, 46), Enum.Material.Asphalt)
	avenue.CastShadow = false
	for i = 0, 11 do
		local dash = part(model, "Dash", Vector3.new(6, 0.05, 0.4), L(-SIZE / 2 + 8 + i * 16, 0.32, CELL / 2), Color3.fromRGB(230, 200, 80), Enum.Material.Neon)
		dash.CastShadow = false
	end

	-- praça e Prefeitura na frente da Avenida (lado do hub)
	part(model, "Plaza", Vector3.new(SIZE, 0.4, 64), L(0, 0.2, -32), Color3.fromRGB(150, 146, 140), Enum.Material.Cobblestone).CastShadow = false
	local hall = Instance.new("Model")
	hall.Name = "Prefeitura"
	part(hall, "Body", Vector3.new(40, 16, 16), L(0, 8, -22), Color3.fromRGB(232, 226, 210), Enum.Material.Marble)
	part(hall, "Roof", Vector3.new(44, 2, 20), L(0, 17, -22), Color3.fromRGB(200, 194, 180), Enum.Material.Marble)
	local dome = part(hall, "Dome", Vector3.new(14, 14, 14), L(0, 18, -22), Color3.fromRGB(70, 110, 120), Enum.Material.Metal)
	dome.Shape = Enum.PartType.Ball
	part(hall, "Mast", Vector3.new(0.5, 10, 0.5), L(0, 29, -22), Color3.fromRGB(60, 60, 60), Enum.Material.Metal)
	part(hall, "Flag", Vector3.new(4, 2.6, 0.2), L(2.2, 32.5, -22), Color3.fromRGB(0, 150, 70), Enum.Material.Fabric)
	for i = -2, 2 do
		local column = part(hall, "Column", Vector3.new(16, 2, 2), L(i * 8, 8, -31.5), Color3.fromRGB(245, 242, 232), Enum.Material.Marble)
		column.Shape = Enum.PartType.Cylinder
		column.CFrame = L(i * 8, 8, -31.5) * CFrame.Angles(0, 0, math.rad(90))
	end
	part(hall, "Steps", Vector3.new(36, 1, 4), L(0, 0.5, -33), Color3.fromRGB(210, 206, 196), Enum.Material.Marble)
	for _, x in { -14, -6, 6, 14 } do
		part(hall, "Window", Vector3.new(3, 5, 0.2), L(x, 9, -30.05), Color3.fromRGB(255, 214, 140), Enum.Material.Neon)
	end
	-- placa com o nome da cidade (de frente para o hub)
	local signPart = part(hall, "Sign", Vector3.new(34, 4, 0.4), L(0, 13.5, -30.3), Color3.fromRGB(30, 34, 44), Enum.Material.SmoothPlastic)
	local sign = surfaceText(signPart, Enum.NormalId.Front, "TERRENO LIVRE", Color3.fromRGB(255, 230, 160))
	hall.Parent = model

	-- Cofre: a renda cai aqui e o dono vem buscar
	local vault = part(model, "Vault", Vector3.new(7, 7, 7), L(28, 3.5, -20), Color3.fromRGB(90, 96, 104), Enum.Material.DiamondPlate)
	part(model, "VaultTrim", Vector3.new(7.4, 0.8, 7.4), L(28, 6.6, -20), Color3.fromRGB(255, 200, 60), Enum.Material.Neon).CastShadow = false
	part(model, "VaultPad", Vector3.new(12, 0.3, 12), L(28, 0.45, -20), Color3.fromRGB(255, 200, 60), Enum.Material.Neon).CastShadow = false
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(220, 60)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
	billboard.MaxDistance = 200
	billboard.LightInfluence = 0
	local vaultLabel = Instance.new("TextLabel")
	vaultLabel.BackgroundTransparency = 1
	vaultLabel.Size = UDim2.fromScale(1, 1)
	vaultLabel.Font = Enum.Font.GothamBlack
	vaultLabel.TextScaled = true
	vaultLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
	vaultLabel.TextStrokeTransparency = 0.4
	vaultLabel.Text = "COFRE"
	vaultLabel.Parent = billboard
	billboard.Parent = vault
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Coletar"
	prompt.ObjectText = "Cofre da Prefeitura"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = vault
	prompt.Triggered:Connect(function(player)
		if Lots.OnVault then
			Lots.OnVault(player, index)
		end
	end)

	-- caminho até o hub
	local inner = 120
	local outer = Config.LotRadius - 64
	local mid = (inner + outer) / 2
	local path = part(model, "Path", Vector3.new(18, 0.3, outer - inner + 2), L(0, 0.05, -(Config.LotRadius - mid)), Color3.fromRGB(70, 72, 78), Enum.Material.Asphalt)
	path.CastShadow = false
	for t = 0, 4 do
		local z = -(Config.LotRadius - inner) + 10 + t * (outer - inner - 20) / 4
		for _, x in { -11, 11 } do
			part(model, "Lamp", Vector3.new(0.5, 12, 0.5), L(x, 6, z), Color3.fromRGB(40, 40, 44), Enum.Material.Metal)
			local bulb = part(model, "Bulb", Vector3.new(1.2, 1.2, 1.2), L(x, 12.4, z), Color3.fromRGB(255, 214, 150), Enum.Material.Neon)
			bulb.Shape = Enum.PartType.Ball
			local light = Instance.new("PointLight")
			light.Range = 22
			light.Brightness = 1.2
			light.Color = Color3.fromRGB(255, 200, 140)
			light.Parent = bulb
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = "Buildings"
	folder.Parent = model
	model.Parent = root

	return {
		Index = index,
		Model = model,
		Buildings = folder,
		Owner = nil,
		Unlocked = unlocked,
		Sign = sign,
		VaultLabel = vaultLabel,
		VaultPrompt = prompt,
		Rendered = {},
	}
end

function Lots.Init()
	root = Instance.new("Folder")
	root.Name = "Lots"
	root.Parent = workspace
	for index = 1, Config.MaxPlayers do
		lots[index] = buildLot(index)
		Lots.SetExpansion(index, 1)
	end
end

function Lots.Claim(player: Player): number?
	for _, lot in lots do
		if lot.Owner == player then
			return lot.Index
		end
	end
	for _, lot in lots do
		if lot.Owner == nil then
			lot.Owner = player
			lot.Model:SetAttribute("Owner", player.UserId)
			lot.Model:SetAttribute("OwnerName", player.DisplayName)
			return lot.Index
		end
	end
	return nil
end

function Lots.Release(index: number)
	local lot = lots[index]
	if not lot then
		return
	end
	lot.Owner = nil
	Lots.ClearBuildings(index)
	lot.Model:SetAttribute("Owner", 0)
	lot.Model:SetAttribute("OwnerName", "")
	lot.Model:SetAttribute("CityName", "Terreno livre")
	lot.Model:SetAttribute("Population", 0)
	lot.Model:SetAttribute("Stars", 0)
	lot.Model:SetAttribute("Happiness", 0)
	lot.Sign.Text = "TERRENO LIVRE"
	lot.VaultLabel.Text = "COFRE"
	Lots.SetExpansion(index, 1)
end

function Lots.OwnerOf(index: number): Player?
	local lot = lots[index]
	return lot and lot.Owner
end

function Lots.Count(): number
	return #lots
end

function Lots.SetInfo(index: number, info: { [string]: any })
	local lot = lots[index]
	if not lot then
		return
	end
	for key, value in info do
		if lot.Model:GetAttribute(key) ~= value then
			lot.Model:SetAttribute(key, value)
		end
	end
	if info.CityName and lot.Owner then
		lot.Sign.Text = string.upper(info.CityName)
	end
end

function Lots.SetVaultText(index: number, text: string)
	local lot = lots[index]
	if lot and lot.VaultLabel.Text ~= text then
		lot.VaultLabel.Text = text
	end
end

function Lots.SetExpansion(index: number, level: number)
	local lot = lots[index]
	if not lot then
		return
	end
	local x1, x2, z1, z2 = Grid.Bounds(level)
	local w = (x2 - x1 + 1) * CELL
	local d = (z2 - z1 + 1) * CELL
	local cx, cz = Grid.LocalPosition((x1 + x2) / 2, (z1 + z2) / 2)
	lot.Unlocked.Size = Vector3.new(w, 0.1, d)
	lot.Unlocked.CFrame = LotLayout.CFrame(index) * CFrame.new(cx, 0.05, cz)
	lot.Model:SetAttribute("Expansion", level)
end

function Lots.Render(index: number, placed: Grid.Placed)
	local lot = lots[index]
	local def = Buildings.ById[placed.Id]
	if not lot or not def then
		return
	end
	local old = lot.Rendered[placed.Uid]
	if old then
		old:Destroy()
	end
	local model = BuildingModels.Build(def)
	model.Name = tostring(placed.Uid)
	model:SetAttribute("Uid", placed.Uid)
	model:SetAttribute("Id", placed.Id)
	model:SetAttribute("X", placed.X)
	model:SetAttribute("Z", placed.Z)
	model:SetAttribute("R", placed.R)
	model:PivotTo(LotLayout.BuildingCFrame(index, placed))
	model.Parent = lot.Buildings
	lot.Rendered[placed.Uid] = model
end

function Lots.Unrender(index: number, uid: number)
	local lot = lots[index]
	local model = lot and lot.Rendered[uid]
	if model then
		model:Destroy()
		lot.Rendered[uid] = nil
	end
end

function Lots.ClearBuildings(index: number)
	local lot = lots[index]
	if not lot then
		return
	end
	lot.Buildings:ClearAllChildren()
	lot.Rendered = {}
end

-- Placa de aviso "SEM RUA" em cima dos prédios que não funcionam
function Lots.SetWarnings(index: number, noRoad: { [number]: boolean })
	local lot = lots[index]
	if not lot then
		return
	end
	for uid, model in lot.Rendered do
		local has = model:FindFirstChild("Warning")
		if noRoad[uid] and not has then
			local gui = Instance.new("BillboardGui")
			gui.Name = "Warning"
			gui.Size = UDim2.fromOffset(110, 30)
			gui.StudsOffsetWorldSpace = Vector3.new(0, 10, 0)
			gui.MaxDistance = 160
			gui.LightInfluence = 0
			gui.AlwaysOnTop = true
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
			label.TextColor3 = Color3.new(1, 1, 1)
			label.Font = Enum.Font.GothamBold
			label.TextScaled = true
			label.Text = "SEM RUA"
			label.Parent = gui
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 6)
			corner.Parent = label
			gui.Parent = model
		elseif not noRoad[uid] and has then
			has:Destroy()
		end
	end
end

return Lots
