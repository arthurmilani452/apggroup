--[[
	Plots: as granjas (bases) do mapa. Dá uma para cada jogador, devolve quando ele sai
	e desenha o que é dele: aves, ovos nos ninhos, esteira, decorações e a placa com o nome.

	Cada granja (workspace.Plots.PlotN) vem do builder com:
	  Zone, Spawn, Sign (SurfaceGui Gui > Text), SellPoint, SellPad,
	  Nest1..12, HenSpot1..12, ConvPath1..N, Conveyor (Model), Decor1..6 (Models)
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetLib = require(ReplicatedStorage.Shared.AssetLib)
local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Registry = require(script.Parent.Registry)

local Plots = {}

export type Plot = {
	Index: number,
	Model: Model,
	Owner: Player?,
	Parts: { [string]: BasePart },
	Nests: { BasePart },
	HenSpots: { BasePart },
	Path: { BasePart },
	NestEggs: { { { Egg: string, Rare: boolean } } },
	NestPrompts: { ProximityPrompt },
	Visuals: Folder,
	SellPrompt: ProximityPrompt,
}

local plots: { Plot } = {}
local byPlayer: { [Player]: Plot } = {}

-- Prompt com dono: o cliente só mostra para quem pode usar ("owner" = só o dono da granja)
function Plots.MakePrompt(parent: Instance, action: string, object: string, forWho: string, hold: number?, distance: number?): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = hold or 0
	prompt.MaxActivationDistance = distance or 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("For", forWho)
	prompt:SetAttribute("Active", true)
	prompt:SetAttribute("Owner", 0)
	prompt.Parent = parent
	CollectionService:AddTag(prompt, "VUOPrompt")
	return prompt
end

function Plots.All(): { Plot }
	return plots
end

function Plots.Of(player: Player): Plot?
	return byPlayer[player]
end

function Plots.IsInside(plot: Plot, position: Vector3): boolean
	local zone = plot.Parts.Zone
	local p = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y + 20 and math.abs(p.Z) <= half.Z
end

function Plots.RootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function Plots.Near(player: Player, part: BasePart, distance: number): boolean
	local root = Plots.RootOf(player)
	return root ~= nil and (root.Position - part.Position).Magnitude <= distance
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function clear(f: Instance)
	for _, child in f:GetChildren() do
		child:Destroy()
	end
end

local function sub(plot: Plot, name: string): Folder
	return plot.Visuals:FindFirstChild(name) :: Folder
end

-- ---------------------------------------------------------------------------
-- Desenho
-- ---------------------------------------------------------------------------
local function rareFx(model: Model, color: Color3)
	local _, size = model:GetBoundingBox()
	local anchor = Instance.new("Part")
	anchor.Name = "Glow"
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	local cf = model:GetBoundingBox()
	anchor.CFrame = cf
	anchor.Parent = model
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 8
	light.Brightness = 2
	light.Parent = anchor
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150))
	sparkle.Size = NumberSequence.new(0.5, 0)
	sparkle.Lifetime = NumberRange.new(0.6, 1)
	sparkle.Rate = 8
	sparkle.Speed = NumberRange.new(1, 2.5)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.LightEmission = 1
	sparkle.Parent = anchor
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.7
	highlight.OutlineColor = Color3.fromRGB(255, 230, 90)
	highlight.FillColor = color
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	model:SetAttribute("Rare", size.Y > 0)
end

function Plots.MakeEgg(eggId: string, rare: boolean): Model?
	local egg = Config.EggById[eggId]
	if not egg then
		return nil
	end
	local model = AssetLib.Get(egg.Asset, Config.AssetHeights.Ovo)
	if not model then
		return nil
	end
	AssetLib.SetCollide(model, false)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanQuery = false
		end
	end
	if rare then
		rareFx(model, egg.Color)
	end
	return model
end

function Plots.RefreshNest(plot: Plot, index: number)
	local nestFolder = sub(plot, "Eggs"):FindFirstChild("Nest" .. index)
	if nestFolder then
		nestFolder:Destroy()
	end
	local eggs = plot.NestEggs[index]
	local nest = plot.Nests[index]
	local prompt = plot.NestPrompts[index]
	if prompt then
		prompt:SetAttribute("Active", eggs ~= nil and #eggs > 0)
	end
	if not eggs or #eggs == 0 or not nest then
		return
	end
	local f = folder(sub(plot, "Eggs"), "Nest" .. index)
	local top = nest.Position + Vector3.new(0, nest.Size.Y / 2, 0)
	for i, entry in eggs do
		local model = Plots.MakeEgg(entry.Egg, entry.Rare)
		if model then
			local angle = (i - 1) * (math.pi * 2 / 3) + index
			AssetLib.PlaceAt(model, top + Vector3.new(math.cos(angle) * 0.7, -0.35, math.sin(angle) * 0.7), math.deg(angle))
			-- encostar no ovo também coleta (só o dono)
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					d.CanTouch = true
					d.Touched:Connect(function(hit)
						local player = game:GetService("Players"):GetPlayerFromCharacter(hit.Parent)
						if player and player == plot.Owner then
							Registry.Farm.Collect(player, plot, index)
						end
					end)
					break
				end
			end
			model.Parent = f
		end
	end
end

function Plots.RefreshHens(plot: Plot)
	local f = sub(plot, "Hens")
	clear(f)
	local owner = plot.Owner
	local data = owner and Registry.Economy.Data(owner)
	if not data then
		return
	end
	for i, henId in data.Hens do
		local hen = Config.HenById[henId]
		local spot = plot.HenSpots[i]
		if hen and spot then
			local model = AssetLib.Get(hen.Asset, Config.AssetHeights.Ave)
			if model then
				AssetLib.SetCollide(model, false)
				AssetLib.PlaceAt(model, spot.Position - Vector3.new(0, spot.Size.Y / 2, 0), spot:GetAttribute("Yaw") or 0)
				model.Name = "Ave" .. i
				model:SetAttribute("Hen", henId)
				CollectionService:AddTag(model, "VUOHen")
				model.Parent = f
			end
		end
	end
	-- ninhos sem ave ficam vazios (e somem os ovos de quem saiu)
	for i = 1, #plot.Nests do
		local nest = plot.Nests[i]
		nest:SetAttribute("Used", data.Hens[i] ~= nil)
	end
end

function Plots.RefreshUpgrades(plot: Plot)
	local owner = plot.Owner
	local data = owner and Registry.Economy.Data(owner)
	local hasConveyor = data ~= nil and Formulas.UpgradeValue(Config, data, "Esteira") > 0
	local decor = if data then Formulas.UpgradeLevel(data, "Decoracao") else 0
	local nestCap = if data then Formulas.UpgradeValue(Config, data, "Ninhos") else 0
	local function show(model: Instance?, visible: boolean)
		if not model then
			return
		end
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				if d:GetAttribute("T0") == nil then
					d:SetAttribute("T0", d.Transparency)
					d:SetAttribute("C0", d.CanCollide)
				end
				d.Transparency = if visible then d:GetAttribute("T0") else 1
				d.CanCollide = visible and d:GetAttribute("C0") == true
			elseif d:IsA("Decal") or d:IsA("Texture") then
				d.Transparency = if visible then 0 else 1
			elseif d:IsA("Light") or d:IsA("ParticleEmitter") then
				d.Enabled = visible
			end
		end
	end
	show(plot.Model:FindFirstChild("Conveyor"), hasConveyor)
	for i = 1, 6 do
		show(plot.Model:FindFirstChild("Decor" .. i), decor >= i)
	end
	-- ninhos liberados aparecem; os outros ficam escondidos
	for i = 1, 12 do
		show(plot.Model:FindFirstChild("NestLook" .. i), owner ~= nil and i <= nestCap)
	end
end

function Plots.RefreshSign(plot: Plot)
	local sign = plot.Parts.Sign
	local gui = sign and sign:FindFirstChildWhichIsA("SurfaceGui")
	local label = gui and gui:FindFirstChildWhichIsA("TextLabel")
	if label then
		label.Text = if plot.Owner then "Granja de " .. plot.Owner.DisplayName else "Granja livre"
	end
	plot.Model:SetAttribute("OwnerId", if plot.Owner then plot.Owner.UserId else 0)
end

function Plots.RefreshAll(plot: Plot)
	Plots.RefreshSign(plot)
	Plots.RefreshHens(plot)
	Plots.RefreshUpgrades(plot)
	for i = 1, #plot.Nests do
		Plots.RefreshNest(plot, i)
	end
end

local function setOwnerAttr(plot: Plot)
	local id = if plot.Owner then plot.Owner.UserId else 0
	for _, d in plot.Model:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			d:SetAttribute("Owner", id)
		end
	end
end

-- ---------------------------------------------------------------------------
function Plots.Assign(player: Player): Plot?
	if byPlayer[player] then
		return byPlayer[player]
	end
	for _, plot in plots do
		if not plot.Owner then
			plot.Owner = player
			byPlayer[player] = plot
			plot.NestEggs = {}
			for i = 1, #plot.Nests do
				plot.NestEggs[i] = {}
			end
			setOwnerAttr(plot)
			Plots.RefreshAll(plot)
			return plot
		end
	end
	return nil
end

function Plots.Release(player: Player)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	byPlayer[player] = nil
	plot.Owner = nil
	plot.NestEggs = {}
	setOwnerAttr(plot)
	clear(sub(plot, "Eggs"))
	clear(sub(plot, "Hens"))
	clear(sub(plot, "Belt"))
	Plots.RefreshAll(plot)
end

function Plots.SpawnCFrame(plot: Plot): CFrame
	local spawn = plot.Parts.Spawn
	return spawn.CFrame + Vector3.new(0, 4, 0)
end

function Plots.Init()
	local root = workspace:WaitForChild("Plots")
	local models = root:GetChildren()
	table.sort(models, function(a, b)
		return (a:GetAttribute("Index") or 0) < (b:GetAttribute("Index") or 0)
	end)
	for _, model in models do
		if not model:IsA("Model") then
			continue
		end
		local parts: { [string]: BasePart } = {}
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") then
				parts[child.Name] = child
			end
		end
		local function list(prefix: string): { BasePart }
			local out = {}
			local i = 1
			while parts[prefix .. i] do
				table.insert(out, parts[prefix .. i])
				i += 1
			end
			return out
		end
		local visuals = folder(model, "Visuals")
		for _, name in { "Eggs", "Hens", "Belt" } do
			folder(visuals, name)
		end
		local plot: Plot = {
			Index = model:GetAttribute("Index") or (#plots + 1),
			Model = model,
			Owner = nil,
			Parts = parts,
			Nests = list("Nest"),
			HenSpots = list("HenSpot"),
			Path = list("ConvPath"),
			NestEggs = {},
			NestPrompts = {},
			Visuals = visuals,
			SellPrompt = nil :: any,
		}
		for i, nest in plot.Nests do
			local prompt = Plots.MakePrompt(nest, "Coletar", "Ninho", "owner", 0, 9)
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt:SetAttribute("Active", false)
			plot.NestPrompts[i] = prompt
			prompt.Triggered:Connect(function(player)
				Registry.Farm.Collect(player, plot, i)
			end)
		end
		plot.SellPrompt = Plots.MakePrompt(parts.SellPoint, "Vender tudo", "Banca", "owner", 0, 12)
		plot.SellPrompt.KeyboardKeyCode = Enum.KeyCode.E
		plot.SellPrompt.Triggered:Connect(function(player)
			Registry.Farm.Sell(player, plot)
		end)
		local pad = parts.SellPad
		if pad then
			pad.Touched:Connect(function(hit)
				local player = game:GetService("Players"):GetPlayerFromCharacter(hit.Parent)
				if player and player == plot.Owner then
					Registry.Farm.Sell(player, plot)
				end
			end)
		end
		table.insert(plots, plot)
		Plots.RefreshAll(plot)
	end
end

return Plots
