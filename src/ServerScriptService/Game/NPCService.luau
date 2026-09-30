--[[
	NPCService (ModuleScript em ServerScriptService > Game)
	v14: coloca o mascote SNEAKY e os ajudantes no mapa (lista em ReplicatedStorage > Shared > NPCs).
	  • Se existir modelo 3D em ReplicatedStorage > Models3D > <Id>, usa ele (feito no Higgsfield).
	  • Senão, monta um boneco com peças (nunca fica vazio).
	  • Cada um tem nome em cima e o botão "Talk" (ProximityPrompt). A conversa é só na tela
	    de quem apertou (NpcUI) e não dá prêmio nenhum: por isso não precisa de RemoteEvent.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NPCs = require(ReplicatedStorage.Shared.NPCs)
local Models3D = require(ReplicatedStorage.Shared.Models3D)

local NPCService = {}

local rgb = Color3.fromRGB
local V = Vector3.new

local DEFAULT_HEIGHT = { raccoon = 6.5, person = 5.6 }
local SKIN = rgb(255, 205, 160)
local DARK = rgb(30, 25, 35)

local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, shape: Enum.PartType?, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape == Enum.PartType.Ball then
		local d = math.min(size.X, size.Y, size.Z)
		size = V(d, d, d)
	end
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	if shape then
		p.Shape = shape
	end
	return p
end

-- peça esticada em forma de ovo/elipse
local function blob(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = part(name, size, cframe, color, nil, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

---------------------------------------------------------------------
-- Bonecos de peças (usados quando não tem modelo 3D). Pés em y = 0, frente para -Z.
---------------------------------------------------------------------
local function buildPerson(npc: any, model: Model)
	local shirt: Color3 = npc.Shirt or rgb(80, 160, 255)
	local hair: Color3 = npc.Hair or rgb(90, 60, 40)
	local skin: Color3 = npc.Skin or SKIN
	local pants: Color3 = npc.Pants or rgb(55, 65, 95)
	for _, x in { -0.5, 0.5 } do
		part("Leg", V(0.9, 2, 0.95), CFrame.new(x, 1, 0), pants).Parent = model
		blob("Shoe", V(1, 0.5, 1.3), CFrame.new(x, 0.25, -0.15), DARK).Parent = model
		local arm = part("Arm", V(0.75, 1.9, 0.8), CFrame.new(x * 3, 3.05, 0) * CFrame.Angles(0, 0, math.rad(-8 * x * 2)), shirt)
		arm.Parent = model
		part("Hand", V(0.7, 0.7, 0.7), CFrame.new(x * 3.2, 1.95, 0), skin, Enum.PartType.Ball).Parent = model
	end
	part("Torso", V(2.2, 2.1, 1.15), CFrame.new(0, 3.05, 0), shirt).Parent = model
	part("Head", V(1.95, 1.95, 1.95), CFrame.new(0, 5.1, 0), skin, Enum.PartType.Ball).Parent = model
	part("Hair", V(2.05, 2.05, 2.05), CFrame.new(0, 5.35, 0.12), hair, Enum.PartType.Ball).Parent = model
	for _, x in { -0.38, 0.38 } do
		part("Eye", V(0.3, 0.3, 0.3), CFrame.new(x, 5.12, -0.9), DARK, Enum.PartType.Ball).Parent = model
	end
	blob("Smile", V(0.55, 0.14, 0.12), CFrame.new(0, 4.7, -0.93), rgb(170, 60, 70)).Parent = model
	blob("Blush", V(0.3, 0.16, 0.08), CFrame.new(-0.62, 4.85, -0.8), rgb(255, 150, 160)).Parent = model
	blob("Blush", V(0.3, 0.16, 0.08), CFrame.new(0.62, 4.85, -0.8), rgb(255, 150, 160)).Parent = model
end

local function buildRaccoon(_npc: any, model: Model)
	local gray, light, dark = rgb(150, 150, 160), rgb(235, 235, 240), rgb(45, 45, 55)
	blob("Body", V(3.1, 3.2, 2.9), CFrame.new(0, 2.05, 0), gray).Parent = model
	blob("Belly", V(2.2, 2.3, 1), CFrame.new(0, 1.95, -1.05), light).Parent = model
	for _, x in { -0.75, 0.75 } do
		blob("Foot", V(0.9, 0.55, 1.2), CFrame.new(x, 0.28, -0.4), dark).Parent = model
	end
	part("Head", V(2.7, 2.7, 2.7), CFrame.new(0, 4.35, -0.1), gray, Enum.PartType.Ball).Parent = model
	blob("Muzzle", V(1.3, 0.9, 0.9), CFrame.new(0, 4.0, -1.25), light).Parent = model
	part("Nose", V(0.35, 0.35, 0.35), CFrame.new(0, 4.15, -1.7), DARK, Enum.PartType.Ball).Parent = model
	blob("Mask", V(2.5, 0.75, 0.6), CFrame.new(0, 4.6, -1.05), dark).Parent = model
	for _, x in { -0.5, 0.5 } do
		part("Eye", V(0.55, 0.55, 0.55), CFrame.new(x, 4.62, -1.3), rgb(255, 255, 255), Enum.PartType.Ball).Parent = model
		part("Pupil", V(0.3, 0.3, 0.3), CFrame.new(x, 4.62, -1.55), DARK, Enum.PartType.Ball).Parent = model
		local ear = part("Ear", V(0.7, 0.9, 0.35), CFrame.new(x * 2, 5.7, -0.1) * CFrame.Angles(0, 0, math.rad(-18 * x * 2)), gray)
		ear.Parent = model
		blob("EarTip", V(0.45, 0.55, 0.1), CFrame.new(x * 2, 5.7, -0.3), dark).Parent = model
	end
	-- rabo listrado (para trás, subindo)
	for i = 1, 5 do
		local t = (i - 1) / 4
		local d = 1.2 - t * 0.25
		part("Tail", V(d, d, d), CFrame.new(0.3 * t, 1.4 + t * 2.2, 1.6 + t * 0.9), if i % 2 == 0 then dark else gray, Enum.PartType.Ball).Parent = model
	end
	-- o ovo dourado que ele sempre abraça
	local egg = blob("GoldenEgg", V(1.35, 1.7, 1.35), CFrame.new(0, 2.2, -1.65), rgb(255, 205, 60), Enum.Material.Foil)
	egg.Reflectance = 0.15
	egg.Parent = model
	for _, x in { -0.8, 0.8 } do
		part("Paw", V(0.65, 0.65, 0.65), CFrame.new(x, 2.3, -1.75), gray, Enum.PartType.Ball).Parent = model
	end
	local shine = Instance.new("PointLight")
	shine.Color = rgb(255, 215, 90)
	shine.Range = 8
	shine.Brightness = 0.8
	shine.Shadows = false
	shine.Parent = egg
end

---------------------------------------------------------------------
local function groundY(position: Vector3, ignore: { Instance }): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(V(position.X, position.Y + 150, position.Z), V(0, -300, 0), params)
	return if hit then hit.Position.Y else position.Y
end

local function nameTag(npc: any, height: number, parent: BasePart)
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Size = UDim2.fromOffset(220, 60)
	gui.StudsOffsetWorldSpace = V(0, height / 2 + 1.4, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 70
	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0.6, 0)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = rgb(255, 255, 255)
	name.TextStrokeTransparency = 0.2
	name.Text = npc.Name
	name.Parent = gui
	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromScale(0, 0.6)
	title.Size = UDim2.new(1, 0, 0.4, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = rgb(255, 215, 80)
	title.TextStrokeTransparency = 0.3
	title.Text = npc.Title or ""
	title.Parent = gui
	gui.Parent = parent
end

function NPCService.Build(npc: any, folder: Instance, ignore: { Instance }): Model
	local height: number = npc.Height or DEFAULT_HEIGHT[npc.Kind] or 5.6
	local model = Instance.new("Model")
	model.Name = npc.Name
	model:SetAttribute("NpcId", npc.Id)

	local mesh, meshHeight = Models3D.Get(npc.Id, { Size = height, Fit = "Height" })
	if mesh then
		for _, d in mesh:GetDescendants() do
			if d:IsA("BasePart") then
				d.Parent = model
				d.CastShadow = true
			end
		end
		mesh:Destroy()
		height = meshHeight
		model:SetAttribute("Is3D", true)
	elseif npc.Kind == "raccoon" then
		buildRaccoon(npc, model)
		model.WorldPivot = CFrame.identity
		model:ScaleTo(height / 6.2)
	else
		buildPerson(npc, model)
		model.WorldPivot = CFrame.identity
		model:ScaleTo(height / 6.1)
	end

	-- base invisível: colisão (ninguém atravessa) + onde fica o botão Talk
	local base = part("Base", V(2.6, height, 2.6), CFrame.new(0, height / 2, 0), rgb(255, 255, 255))
	base.Transparency = 1
	base.CanCollide = true
	base.CanQuery = true
	base.CastShadow = false
	base.Parent = model
	-- pivô do modelo = pés (com PrimaryPart o Roblox usa o pivô dela, então ele fica meia altura abaixo do centro)
	base.PivotOffset = CFrame.new(0, -height / 2, 0)
	model.PrimaryPart = base

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TalkPrompt"
	prompt.ActionText = "Talk"
	prompt.ObjectText = npc.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	-- tecla própria (F / Y no controle): assim o "Talk" nunca esconde o botão da barraquinha (E)
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt:SetAttribute("NpcId", npc.Id)
	prompt.Parent = base
	nameTag(npc, height, base)

	-- lugar no mapa: no chão, olhando para Look
	local position: Vector3 = npc.Position
	local y = groundY(position, ignore)
	local look: Vector3 = npc.Look or (position + V(0, 0, -1))
	local flatLook = V(look.X, y, look.Z)
	local at = V(position.X, y, position.Z)
	local cframe = if (flatLook - at).Magnitude > 0.1 then CFrame.lookAt(at, flatLook) else CFrame.new(at)
	model:PivotTo(cframe)
	model:SetAttribute("Height", height)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	model:AddTag("NPC")
	model.Parent = folder
	return model
end

function NPCService.Init()
	local folder = workspace:FindFirstChild("NPCs") or Instance.new("Folder")
	folder.Name = "NPCs"
	folder.Parent = workspace
	local ignore: { Instance } = { folder }
	local map = workspace:FindFirstChild("Map")
	for _, name in { "Decor", "Plots", "Boundaries" } do
		local child = map and map:FindFirstChild(name)
		if child then
			table.insert(ignore, child)
		end
	end
	for _, name in { "ActiveCritters", "ClientPets", "Monsters", "HuntEggs" } do
		local child = workspace:FindFirstChild(name)
		if child then
			table.insert(ignore, child)
		end
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	for _, npc in NPCs.List do
		local ok, err = pcall(NPCService.Build, npc, folder, ignore)
		if not ok then
			warn("[NPCs] could not build", npc.Id, err)
		end
	end
	-- ajuda a conferir a importação: aparece no Output quando o servidor liga
	local loaded = Models3D.Loaded()
	if #loaded > 0 then
		print(("[Models3D] %d 3D models found: %s"):format(#loaded, table.concat(loaded, ", ")))
	else
		print("[Models3D] no 3D models imported yet (using part models). See the Guide: Version 14.")
	end
end

return NPCService
