--[[
	ZONA ZERO - tela do jogador (LocalScript "ClientMain" em StarterPlayer > StarterPlayerScripts)
	  • HUD: vida/escudo, munição, vivos, abates, zona, killfeed, resultado
	  • Armas: câmera por cima do ombro, mira no centro, tiro, recarga, mira (zoom), recuo
	  • Efeitos: rastro das balas, marcador de acerto, flash de dano
	  • Zona: parede roxa e anel da próxima zona (desenhados só na sua tela)
	  • Espectador depois de morrer
	O servidor confere tudo; aqui é só controle e visual.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Locale = require(Shared:WaitForChild("Locale"))
local ZoneMath = require(Shared:WaitForChild("ZoneMath"))
local WeaponBuilder = require(Shared:WaitForChild("WeaponBuilder"))
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local Remotes = {
	Fire = RemotesFolder:WaitForChild("Fire"),
	Reload = RemotesFolder:WaitForChild("Reload"),
	Spectate = RemotesFolder:WaitForChild("Spectate"),
	Effect = RemotesFolder:WaitForChild("Effect"),
	Event = RemotesFolder:WaitForChild("Event"),
	Aim = RemotesFolder:WaitForChild("Aim"),
	Notify = RemotesFolder:WaitForChild("Notify"),
	Killfeed = RemotesFolder:WaitForChild("Killfeed"),
	Result = RemotesFolder:WaitForChild("Result"),
	SpectateTarget = RemotesFolder:WaitForChild("SpectateTarget"),
}

local T = Locale.T
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local isTouch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

---------------------------------------------------------------------
-- UI básica
---------------------------------------------------------------------
local FONT = Enum.Font.GothamBold
local FONT_LIGHT = Enum.Font.Gotham
local WHITE = Color3.new(1, 1, 1)
local ACCENT = Color3.fromRGB(255, 200, 60)

local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.AutoLocalize = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextColor3 = WHITE
	l.TextScaled = true
	l.Text = ""
	for k, v in props do
		(l :: any)[k] = v
	end
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Transparency = 0.3
	stroke.Parent = l
	l.Parent = parent
	return l
end

local function frame(parent: Instance, props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in props do
		(f :: any)[k] = v
	end
	f.Parent = parent
	return f
end

local function corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = parent
end

-- topo: fase/zona + vivos + abates
local topText = label(gui, { Size = UDim2.new(0.5, 0, 0, 30), Position = UDim2.new(0.25, 0, 0, 48), Text = "" })
local aliveText = label(gui, { Size = UDim2.new(0, 160, 0, 26), Position = UDim2.new(0.5, -170, 0, 82), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = ACCENT })
local killsText = label(gui, { Size = UDim2.new(0, 160, 0, 26), Position = UDim2.new(0.5, 10, 0, 82), TextXAlignment = Enum.TextXAlignment.Left })

-- killfeed (canto superior direito)
local feed = frame(gui, { Size = UDim2.new(0, 320, 0, 160), Position = UDim2.new(1, -330, 0, 120), BackgroundTransparency = 1 })
local feedLayout = Instance.new("UIListLayout")
feedLayout.SortOrder = Enum.SortOrder.LayoutOrder
feedLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
feedLayout.Padding = UDim.new(0, 4)
feedLayout.Parent = feed

-- vida e escudo (embaixo, centro)
local barsBox = frame(gui, { Size = UDim2.new(0, 300, 0, 44), Position = UDim2.new(0.5, -150, 1, -96), BackgroundTransparency = 1 })
local shieldBack = frame(barsBox, { Size = UDim2.new(1, 0, 0, 14), BackgroundColor3 = Color3.fromRGB(20, 25, 40), BackgroundTransparency = 0.3 })
corner(shieldBack, 4)
local shieldFill = frame(shieldBack, { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(70, 160, 255) })
corner(shieldFill, 4)
local healthBack = frame(barsBox, { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 0, 20), BackgroundColor3 = Color3.fromRGB(25, 25, 25), BackgroundTransparency = 0.3 })
corner(healthBack, 4)
local healthFill = frame(healthBack, { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(90, 220, 110) })
corner(healthFill, 4)
local healthText = label(healthBack, { Size = UDim2.new(1, 0, 1, 0), ZIndex = 2, Text = "100" })

-- munição (embaixo, direita)
local ammoText = label(gui, { Size = UDim2.new(0, 220, 0, 40), Position = UDim2.new(1, -240, 1, -150), TextXAlignment = Enum.TextXAlignment.Right })
local weaponText = label(gui, { Size = UDim2.new(0, 260, 0, 22), Position = UDim2.new(1, -280, 1, -176), TextXAlignment = Enum.TextXAlignment.Right, Font = FONT_LIGHT })
local reserveTexts = {}
do
	local box = frame(gui, { Size = UDim2.new(0, 220, 0, 20), Position = UDim2.new(1, -240, 1, -108), BackgroundTransparency = 1 })
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Padding = UDim.new(0, 8)
	layout.Parent = box
	for _, ammoType in { "Light", "Medium", "Shells", "Heavy" } do
		reserveTexts[ammoType] = label(box, { Size = UDim2.new(0, 46, 1, 0), TextColor3 = Config.AmmoTypes[ammoType].Color, Font = FONT_LIGHT })
	end
end

-- mira e marcador de acerto
local crosshair = frame(gui, { Size = UDim2.new(0, 40, 0, 40), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundTransparency = 1 })
local crossLines = {}
for i, dir in { Vector2.new(0, -1), Vector2.new(0, 1), Vector2.new(-1, 0), Vector2.new(1, 0) } do
	local horizontal = dir.Y == 0
	crossLines[i] = { Dir = dir, Frame = frame(crosshair, {
		Size = if horizontal then UDim2.new(0, 8, 0, 2) else UDim2.new(0, 2, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = WHITE,
	}) }
end
frame(crosshair, { Size = UDim2.new(0, 3, 0, 3), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundColor3 = WHITE })
local hitmarker = label(gui, { Size = UDim2.new(0, 34, 0, 34), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Text = "✕", TextTransparency = 1, TextColor3 = WHITE })

-- luneta do rifle de precisão
local scope = frame(gui, { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false })
do
	local ring = frame(scope, { Size = UDim2.new(0.6, 0, 0.6, 0), SizeConstraint = Enum.SizeConstraint.RelativeYY, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundTransparency = 1 })
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2000
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = ring
	corner(ring, 2000)
	frame(scope, { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = Color3.new(0, 0, 0) })
	frame(scope, { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(0.5, 0, 0, 0), BackgroundColor3 = Color3.new(0, 0, 0) })
end

-- avisos grandes e pequenos
local bigText = label(gui, { Size = UDim2.new(0.7, 0, 0, 70), Position = UDim2.new(0.15, 0, 0.22, 0), TextTransparency = 1, TextColor3 = ACCENT })
local subText = label(gui, { Size = UDim2.new(0.6, 0, 0, 30), Position = UDim2.new(0.2, 0, 0.22, 74), TextTransparency = 1, Font = FONT_LIGHT })
local toast = label(gui, { Size = UDim2.new(0.5, 0, 0, 26), Position = UDim2.new(0.25, 0, 0.68, 0), TextTransparency = 1, Font = FONT_LIGHT })
local zoneWarning = label(gui, { Size = UDim2.new(0.6, 0, 0, 34), Position = UDim2.new(0.2, 0, 0, 120), Text = "", TextColor3 = Color3.fromRGB(220, 150, 255), Visible = false })
local useBar = frame(gui, { Size = UDim2.new(0, 220, 0, 8), Position = UDim2.new(0.5, -110, 0.62, 0), BackgroundColor3 = Color3.fromRGB(30, 30, 30), Visible = false })
corner(useBar, 4)
local useFill = frame(useBar, { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(120, 230, 140) })
corner(useFill, 4)
local useText = label(useBar, { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0, -24), Font = FONT_LIGHT })

-- vinheta de dano e da zona
local damageFlash = frame(gui, { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(200, 0, 0), BackgroundTransparency = 1, ZIndex = 0 })
local zoneTint = frame(gui, { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Config.Zone.Color, BackgroundTransparency = 1, ZIndex = 0 })

-- espectador
local specBar = frame(gui, { Size = UDim2.new(0, 360, 0, 44), Position = UDim2.new(0.5, -180, 1, -160), BackgroundColor3 = Color3.fromRGB(15, 15, 20), BackgroundTransparency = 0.25, Visible = false })
corner(specBar, 8)
local specText = label(specBar, { Size = UDim2.new(0.68, -10, 1, -10), Position = UDim2.new(0, 10, 0, 5), TextXAlignment = Enum.TextXAlignment.Left })
local specNext = Instance.new("TextButton")
specNext.Size = UDim2.new(0.3, 0, 1, -10)
specNext.Position = UDim2.new(0.7, -5, 0, 5)
specNext.BackgroundColor3 = ACCENT
specNext.TextColor3 = Color3.new(0, 0, 0)
specNext.Font = FONT
specNext.TextScaled = true
specNext.Text = T("NEXT")
specNext.Parent = specBar
corner(specNext, 6)

-- lobby: estatísticas e XP
local lobbyBox = frame(gui, { Size = UDim2.new(0, 420, 0, 76), Position = UDim2.new(0.5, -210, 1, -120), BackgroundTransparency = 1 })
local statsText = label(lobbyBox, { Size = UDim2.new(1, 0, 0, 26), Font = FONT_LIGHT })
local xpBack = frame(lobbyBox, { Size = UDim2.new(1, 0, 0, 10), Position = UDim2.new(0, 0, 0, 32), BackgroundColor3 = Color3.fromRGB(30, 30, 30) })
corner(xpBack, 4)
local xpFill = frame(xpBack, { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = ACCENT })
corner(xpFill, 4)
local hintText = label(lobbyBox, { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 0, 48), Font = FONT_LIGHT, Text = T("LOBBY_HINT") })

-- botões do celular
local mobileButtons = {}
local function mobileButton(text: string, position: UDim2, size: number): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, size, 0, size)
	b.Position = position
	b.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	b.BackgroundTransparency = 0.35
	b.TextColor3 = WHITE
	b.Font = FONT
	b.TextScaled = true
	b.Text = text
	b.Visible = false
	b.Parent = gui
	corner(b, size)
	table.insert(mobileButtons, b)
	return b
end
local fireButton = mobileButton("🔫", UDim2.new(1, -150, 1, -250), 92)
local aimButton = mobileButton(T("BTN_AIM"), UDim2.new(1, -250, 1, -210), 64)
local reloadButton = mobileButton("⟳", UDim2.new(1, -110, 1, -340), 56)

---------------------------------------------------------------------
-- Avisos
---------------------------------------------------------------------
local function fadeIn(l: TextLabel, seconds: number)
	l.TextTransparency = 0
	local stroke = l:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = 0.3
	end
	task.delay(seconds, function()
		TweenService:Create(l, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.6), { Transparency = 1 }):Play()
		end
	end)
end

local bigToken = 0
local function showBig(text: string, sub: string?, seconds: number?)
	bigToken += 1
	bigText.Text = text
	subText.Text = sub or ""
	fadeIn(bigText, seconds or 3)
	if sub then
		fadeIn(subText, seconds or 3)
	end
end

local function showToast(text: string)
	toast.Text = text
	fadeIn(toast, 2)
end

local function addFeed(text: string)
	local line = label(feed, { Size = UDim2.new(1, 0, 0, 22), Text = text, TextXAlignment = Enum.TextXAlignment.Right, Font = FONT_LIGHT })
	line.LayoutOrder = math.floor(os.clock() * 100)
	local items = {}
	for _, child in feed:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(items, child)
		end
	end
	if #items > 6 then
		table.sort(items, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		items[1]:Destroy()
	end
	task.delay(7, function()
		if line.Parent then
			line:Destroy()
		end
	end)
end

Remotes.Notify.OnClientEvent:Connect(function(key: string, args: any, kind: string?)
	if kind == "big" then
		showBig(T(key, args), nil, 3)
	else
		showToast(T(key, args))
	end
end)

Remotes.Killfeed.OnClientEvent:Connect(function(key: string, args: any)
	addFeed(T(key, args))
end)

---------------------------------------------------------------------
-- Resultado da partida
---------------------------------------------------------------------
Remotes.Result.OnClientEvent:Connect(function(result: any)
	if result.Won then
		showBig(T("VICTORY"), T("VICTORY_SUB") .. "  ·  " .. T("KILLS", { count = result.Kills }) .. "  ·  " .. T("XP_GAINED", { xp = result.XP }), 7)
	else
		showBig(T("ELIMINATED"), T("PLACE", { place = result.Place, total = result.Total }) .. "  ·  " .. T("KILLS", { count = result.Kills }) .. "  ·  " .. T("XP_GAINED", { xp = result.XP }), 6)
	end
	if result.Level then
		task.delay(2.5, function()
			showToast(T("LEVEL_UP", { level = result.Level }))
		end)
	end
end)

---------------------------------------------------------------------
-- Espectador
---------------------------------------------------------------------
local spectating: Model? = nil
Remotes.SpectateTarget.OnClientEvent:Connect(function(model: Model?, name: string)
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		spectating = model
		camera.CameraSubject = humanoid
		specText.Text = T("SPECTATING", { name = name })
		specBar.Visible = true
	else
		spectating = nil
		specBar.Visible = false
	end
end)
specNext.Activated:Connect(function()
	Remotes.Spectate:FireServer()
end)
player.CharacterAdded:Connect(function(character)
	spectating = nil
	specBar.Visible = false
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		camera.CameraSubject = humanoid
	end
end)

---------------------------------------------------------------------
-- Zona (desenhada só na sua tela)
---------------------------------------------------------------------
local zoneFolder = Instance.new("Folder")
zoneFolder.Name = "ZoneVisual"
zoneFolder.Parent = workspace
local zoneWall = Instance.new("Part")
zoneWall.Name = "ZoneWall"
zoneWall.Shape = Enum.PartType.Cylinder
zoneWall.Anchored = true
zoneWall.CanCollide = false
zoneWall.CanQuery = false
zoneWall.CanTouch = false
zoneWall.CastShadow = false
zoneWall.Material = Enum.Material.ForceField
zoneWall.Color = Config.Zone.Color
zoneWall.Transparency = 0.15
zoneWall.Parent = zoneFolder
local ringParts = {}
for i = 1, 48 do
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = WHITE
	p.Transparency = 0.3
	p.Size = Vector3.new(0.6, 0.4, 1)
	p.Parent = zoneFolder
	ringParts[i] = p
end
local lastRing = ""

local function updateZone()
	local stage = workspace:GetAttribute("ZoneStage") or 0
	if stage <= 0 or workspace:GetAttribute("Phase") ~= "Match" then
		zoneWall.Transparency = 1
		for _, p in ringParts do
			p.Transparency = 1
		end
		zoneWarning.Visible = false
		zoneTint.BackgroundTransparency = 1
		return
	end
	local cx, cz, r = ZoneMath.Current()
	r = math.max(r, 0.5)
	zoneWall.Transparency = 0.15
	zoneWall.Size = Vector3.new(600, r * 2, r * 2)
	zoneWall.CFrame = CFrame.new(cx, 100, cz) * CFrame.Angles(0, 0, math.rad(90))
	-- anel branco da próxima zona
	local ncx, ncz, nr = ZoneMath.Next()
	local key = string.format("%d:%d:%d", ncx, ncz, nr)
	if key ~= lastRing then
		lastRing = key
		for i, p in ringParts do
			local a0 = (i - 1) / #ringParts * math.pi * 2
			local a1 = i / #ringParts * math.pi * 2
			local p0 = Vector3.new(ncx + math.cos(a0) * nr, 1, ncz + math.sin(a0) * nr)
			local p1 = Vector3.new(ncx + math.cos(a1) * nr, 1, ncz + math.sin(a1) * nr)
			local length = (p1 - p0).Magnitude
			p.Size = Vector3.new(0.6, 0.4, math.max(length, 0.2))
			p.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
		end
	end
	local showRing = nr > 0 and math.abs(nr - r) > 1
	for _, p in ringParts do
		p.Transparency = if showRing then 0.3 else 1
	end
	-- dentro ou fora
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local outside = root ~= nil and player:GetAttribute("InMatch") == true and not ZoneMath.IsInside(root.Position)
	zoneWarning.Visible = outside
	zoneWarning.Text = T("OUTSIDE_ZONE")
	zoneTint.BackgroundTransparency = if outside then 0.82 else 1
end

---------------------------------------------------------------------
-- Armas
---------------------------------------------------------------------
local equipped: Tool? = nil
local weLocked = false -- este script travou o mouse no centro (para não brigar com a câmera do Roblox)
local firing = false
local aiming = false
local lastFire = 0
local recoil = 0
local spreadVisual = 0

local function weaponDef(): any
	local id = equipped and equipped:GetAttribute("WeaponId")
	return id and Config.Weapons[id]
end

local function playSound(id: string?, parent: Instance)
	if not id or id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = 0.6
	s.Parent = parent
	s:Play()
	Debris:AddItem(s, 3)
end

local function tracer(from: Vector3, to: Vector3, color: Color3?)
	local length = (to - from).Magnitude
	if length < 0.5 then
		return
	end
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color or Color3.fromRGB(255, 220, 140)
	p.Size = Vector3.new(0.08, 0.08, length)
	p.CFrame = CFrame.lookAt((from + to) / 2, to)
	p.Parent = zoneFolder
	TweenService:Create(p, TweenInfo.new(0.12), { Transparency = 1 }):Play()
	Debris:AddItem(p, 0.15)
	-- faísca no impacto
	local spark = Instance.new("Part")
	spark.Anchored = true
	spark.CanCollide = false
	spark.CanQuery = false
	spark.CanTouch = false
	spark.Material = Enum.Material.Neon
	spark.Color = Color3.fromRGB(255, 200, 120)
	spark.Shape = Enum.PartType.Ball
	spark.Size = Vector3.new(0.5, 0.5, 0.5)
	spark.CFrame = CFrame.new(to)
	spark.Parent = zoneFolder
	TweenService:Create(spark, TweenInfo.new(0.15), { Transparency = 1, Size = Vector3.new(0.1, 0.1, 0.1) }):Play()
	Debris:AddItem(spark, 0.2)
end

local function muzzleFlash(at: Vector3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = CFrame.new(at)
	local light = Instance.new("PointLight")
	light.Range = 10
	light.Brightness = 4
	light.Color = Color3.fromRGB(255, 190, 90)
	light.Parent = p
	p.Parent = zoneFolder
	Debris:AddItem(p, 0.05)
end

-- Raio do centro da tela (a mira) até onde ele bate
local function aimPoint(): Vector3
	local viewport = camera.ViewportSize
	local ray = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { zoneFolder }
	if player.Character then
		table.insert(exclude, player.Character)
	end
	local loot = workspace:FindFirstChild("Loot")
	if loot then
		table.insert(exclude, loot)
	end
	params.FilterDescendantsInstances = exclude
	-- começa no ponto do raio mais perto da cabeça: o que está entre a câmera e o personagem não conta
	local origin = ray.Origin
	local head = player.Character and player.Character:FindFirstChild("Head") :: BasePart?
	if head then
		local along = (head.Position - ray.Origin):Dot(ray.Direction)
		if along > 0 then
			origin = ray.Origin + ray.Direction * along
		end
	end
	local result = workspace:Raycast(origin, ray.Direction * 2000, params)
	return if result then result.Position else origin + ray.Direction * 2000
end

local function muzzlePosition(): Vector3?
	local handle = equipped and equipped:FindFirstChild("Handle")
	local muzzle = handle and handle:FindFirstChild("Muzzle") :: Attachment?
	return muzzle and muzzle.WorldPosition
end

local function requestReload()
	local def = weaponDef()
	if not def or not equipped or equipped:GetAttribute("Reloading") then
		return
	end
	if (equipped:GetAttribute("Mag") or 0) >= def.Mag then
		return
	end
	if (player:GetAttribute("Ammo_" .. def.Ammo) or 0) <= 0 then
		showToast(T("NO_AMMO"))
		return
	end
	Remotes.Reload:FireServer()
	playSound(Config.Sounds.Reload, camera)
end

local function fireOnce(): boolean
	local def = weaponDef()
	if not def or not equipped then
		return false
	end
	if equipped:GetAttribute("Reloading") or player:GetAttribute("Using") then
		return false
	end
	local now = os.clock()
	if now - lastFire < 60 / def.Rpm then
		return true -- ainda não deu o tempo da arma; continua segurando
	end
	if (equipped:GetAttribute("Mag") or 0) <= 0 then
		requestReload()
		return false
	end
	lastFire = now
	local target = aimPoint()
	Remotes.Fire:FireServer(target, aiming)
	-- efeito na hora (o servidor confirma o acerto depois)
	local from = muzzlePosition() or camera.CFrame.Position
	for _ = 1, def.Pellets do
		local spread = math.rad(def.Spread * (if aiming then def.AimSpread else 1))
		local dir = (target - from).Unit
		local jitter = Vector3.new((math.random() - 0.5) * spread, (math.random() - 0.5) * spread, (math.random() - 0.5) * spread)
		tracer(from, from + (dir + jitter).Unit * math.min((target - from).Magnitude, def.Range))
	end
	muzzleFlash(from)
	playSound(Config.Sounds[equipped:GetAttribute("WeaponId")], camera)
	-- recuo da câmera
	recoil += if def.Pellets > 1 then 2.2 else math.clamp(def.Damage / 18, 0.4, 3)
	spreadVisual = math.min(spreadVisual + 6, 24)
	return def.Auto
end

local fireToken = 0
local function startFiring()
	if firing then
		return
	end
	firing = true
	fireToken += 1
	local myToken = fireToken
	task.spawn(function()
		while firing and fireToken == myToken do
			local keep = fireOnce()
			if not keep then
				break
			end
			task.wait(0.02)
		end
		if fireToken == myToken then
			firing = false
		end
	end)
end

local function stopFiring()
	firing = false
end

local function setAiming(on: boolean)
	local def = weaponDef()
	local was = aiming
	aiming = on and def ~= nil
	if aiming ~= was then
		Remotes.Aim:FireServer(aiming)
	end
	local fov = if aiming then def.Zoom else 70
	TweenService:Create(camera, TweenInfo.new(0.15), { FieldOfView = fov }):Play()
	scope.Visible = aiming and def ~= nil and def.Zoom <= 25
end

local boundTools = setmetatable({}, { __mode = "k" })
local function bindTool(tool: Tool)
	if not tool:GetAttribute("WeaponId") or boundTools[tool] then
		return
	end
	boundTools[tool] = true
	tool.Equipped:Connect(function()
		equipped = tool
	end)
	tool.Unequipped:Connect(function()
		if equipped == tool then
			equipped = nil
			stopFiring()
			setAiming(false)
		end
	end)
	if not isTouch then
		tool.Activated:Connect(startFiring)
		tool.Deactivated:Connect(stopFiring)
	end
end

local function watchContainer(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("Tool") then
			bindTool(child)
		end
	end
	container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			bindTool(child)
			if child.Parent == player.Character and child:GetAttribute("WeaponId") then
				equipped = child
			end
		end
	end)
end

player.CharacterAdded:Connect(function(character)
	equipped = nil
	firing = false
	setAiming(false)
	watchContainer(character)
	watchContainer(player:WaitForChild("Backpack"))
end)
if player.Character then
	watchContainer(player.Character)
	watchContainer(player:WaitForChild("Backpack"))
end

-- teclado e mouse
ContextActionService:BindAction("ZZ_Reload", function(_, state)
	if state == Enum.UserInputState.Begin then
		requestReload()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.R, Enum.KeyCode.ButtonX)
UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.ButtonL2 then
		setAiming(true)
	elseif input.KeyCode == Enum.KeyCode.ButtonR2 and not processed then
		startFiring()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.ButtonL2 then
		setAiming(false)
	elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
		stopFiring()
	end
end)

-- celular
local fireTouch: InputObject? = nil
fireButton.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		fireTouch = input
		startFiring()
	end
end)
UserInputService.TouchEnded:Connect(function(input)
	if input == fireTouch then
		fireTouch = nil
		stopFiring()
	end
end)
fireButton.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		stopFiring()
	end
end)
aimButton.Activated:Connect(function()
	setAiming(not aiming)
end)
reloadButton.Activated:Connect(requestReload)

---------------------------------------------------------------------
-- Efeitos vindos do servidor
---------------------------------------------------------------------
local function onEffect(kind: string, data: any)
	if kind == "Shot" then
		if data.S == player.UserId then
			return -- o seu tiro já foi desenhado
		end
		for _, endPos in data.Ends do
			tracer(data.From, endPos)
		end
		muzzleFlash(data.From)
	elseif kind == "Hit" then
		hitmarker.TextColor3 = if data.Kill then Color3.fromRGB(255, 60, 60) elseif data.Head then ACCENT else WHITE
		hitmarker.TextTransparency = 0
		hitmarker.Size = UDim2.new(0, 44, 0, 44)
		TweenService:Create(hitmarker, TweenInfo.new(0.25), { TextTransparency = 1, Size = UDim2.new(0, 30, 0, 30) }):Play()
		playSound(Config.Sounds.Hit, camera)
	elseif kind == "Damaged" then
		damageFlash.BackgroundTransparency = 0.7
		TweenService:Create(damageFlash, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
	elseif kind == "Pickup" then
		showToast("+ " .. T(data.Label or ""))
		playSound(Config.Sounds.Pickup, camera)
	end
end
Remotes.Effect.OnClientEvent:Connect(onEffect)
Remotes.Event.OnClientEvent:Connect(onEffect)

-- Textos dos itens no chão no seu idioma
local function localizePrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local model = prompt:FindFirstAncestorOfClass("Model")
	if not model then
		return
	end
	prompt.ActionText = T("PICKUP")
	local text = T(model:GetAttribute("Label") or "")
	local rarity = model:GetAttribute("Rarity")
	local amount = model:GetAttribute("Amount")
	if model:GetAttribute("Kind") == "Weapon" and rarity then
		text ..= " · " .. T("R_" .. rarity)
	elseif amount and amount > 1 then
		text ..= " x" .. amount
	end
	prompt.ObjectText = text
end
task.spawn(function()
	local loot = workspace:WaitForChild("Loot")
	for _, d in loot:GetDescendants() do
		localizePrompt(d)
	end
	loot.DescendantAdded:Connect(localizePrompt)
end)

---------------------------------------------------------------------
-- Câmera por cima do ombro (com arma na mão) e atualização do HUD
---------------------------------------------------------------------
RunService:BindToRenderStep("ZZ_Camera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local armed = equipped ~= nil and equipped.Parent == character and humanoid ~= nil and humanoid.Health > 0 and spectating == nil
	if humanoid and root then
		if armed then
			humanoid.CameraOffset = humanoid.CameraOffset:Lerp(Vector3.new(1.8, 0.4, 0), math.min(dt * 12, 1))
			humanoid.AutoRotate = false
			local look = camera.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 0.01 then
				root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
			end
			if not isTouch then
				UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
				weLocked = true
			end
		else
			humanoid.CameraOffset = humanoid.CameraOffset:Lerp(Vector3.zero, math.min(dt * 12, 1))
			humanoid.AutoRotate = true
			if weLocked then
				weLocked = false
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			end
		end
	end
	-- recuo: sobe a câmera e volta devagar
	if recoil > 0 then
		local kick = math.min(recoil, 30 * dt)
		camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(kick), 0, 0)
		recoil -= kick * 1.6
	end
	spreadVisual = math.max(0, spreadVisual - dt * 40)
	local def = weaponDef()
	local gap = 6 + spreadVisual + (if def then def.Spread * (if aiming then def.AimSpread else 1) * 3 else 0)
	for _, line in crossLines do
		line.Frame.Position = UDim2.new(0.5, line.Dir.X * gap, 0.5, line.Dir.Y * gap)
	end
	crosshair.Visible = armed and not scope.Visible
	for _, b in mobileButtons do
		b.Visible = isTouch and armed
	end
	updateZone()
end)

local function updateHUD()
	local phase = workspace:GetAttribute("Phase") or "Lobby"
	local endsAt = workspace:GetAttribute("PhaseEndsAt") or 0
	local now = workspace:GetServerTimeNow()
	local inMatch = player:GetAttribute("InMatch") == true

	if phase == "Lobby" then
		if endsAt > now then
			topText.Text = T("LOBBY_STARTING", { s = math.ceil(endsAt - now + Config.Match.Countdown) })
		else
			topText.Text = T("LOBBY_WAITING", { count = #Players:GetPlayers(), max = Config.Match.MaxParticipants })
		end
	elseif phase == "Countdown" then
		topText.Text = T("LOBBY_STARTING", { s = math.max(0, math.ceil(endsAt - now)) })
	elseif phase == "Match" then
		local stage = workspace:GetAttribute("ZoneStage") or 0
		local phaseEnds = workspace:GetAttribute("ZonePhaseEnds") or 0
		local shrinkStart = workspace:GetAttribute("ZoneShrinkStart") or 0
		if stage > #Config.Zone.Phases then
			topText.Text = T("ZONE_FINAL")
		elseif phaseEnds > now and now < shrinkStart then
			topText.Text = T("ZONE_WAIT", { time = Locale.Time(phaseEnds - now) })
		elseif phaseEnds > now then
			topText.Text = T("ZONE_SHRINK", { time = Locale.Time(phaseEnds - now) })
		else
			topText.Text = ""
		end
	else
		topText.Text = ""
	end
	local showMatch = phase == "Match" or phase == "Ended"
	aliveText.Visible = showMatch
	killsText.Visible = showMatch and inMatch
	aliveText.Text = T("ALIVE", { count = workspace:GetAttribute("Alive") or 0 })
	killsText.Text = T("KILLS", { count = player:GetAttribute("MatchKills") or 0 })

	-- vida e escudo
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	barsBox.Visible = inMatch and humanoid ~= nil
	if humanoid and character then
		local hp = math.max(0, humanoid.Health)
		healthFill.Size = UDim2.new(math.clamp(hp / math.max(humanoid.MaxHealth, 1), 0, 1), 0, 1, 0)
		healthFill.BackgroundColor3 = if hp > 50 then Color3.fromRGB(90, 220, 110) elseif hp > 25 then Color3.fromRGB(240, 190, 60) else Color3.fromRGB(230, 70, 60)
		local shield = character:GetAttribute("Shield") or 0
		shieldFill.Size = UDim2.new(math.clamp(shield / Config.Player.MaxShield, 0, 1), 0, 1, 0)
		healthText.Text = string.format("%d  |  %d", math.ceil(hp), shield)
	end

	-- munição
	local def = weaponDef()
	ammoText.Visible = def ~= nil
	weaponText.Visible = def ~= nil
	if def and equipped then
		local mag = equipped:GetAttribute("Mag") or 0
		local reserve = player:GetAttribute("Ammo_" .. def.Ammo) or 0
		ammoText.Text = if equipped:GetAttribute("Reloading") then T("RELOADING") else string.format("%d / %d", mag, reserve)
		ammoText.TextColor3 = if mag == 0 then Color3.fromRGB(255, 90, 80) else WHITE
		local rarity = equipped:GetAttribute("Rarity") or "Common"
		weaponText.Text = T("W_" .. equipped:GetAttribute("WeaponId")) .. " · " .. T("R_" .. rarity)
		weaponText.TextColor3 = WeaponBuilder.RarityColor(rarity)
	end
	for ammoType, l in reserveTexts do
		local n = player:GetAttribute("Ammo_" .. ammoType) or 0
		l.Text = tostring(n)
		l.Visible = inMatch and n > 0
	end

	-- usando cura
	local using = player:GetAttribute("Using")
	useBar.Visible = using ~= nil
	if using then
		local def2 = Config.Items[using]
		local left = (player:GetAttribute("UseEnds") or now) - now
		local fraction = if def2 then 1 - math.clamp(left / def2.UseTime, 0, 1) else 0
		useFill.Size = UDim2.new(fraction, 0, 1, 0)
		useText.Text = T("USING", { item = T("I_" .. using) })
	end

	-- lobby
	lobbyBox.Visible = not inMatch and spectating == nil and (phase == "Lobby" or phase == "Countdown" or not showMatch)
	statsText.Text = T("STATS", { level = player:GetAttribute("Level") or 1, wins = player:GetAttribute("Wins") or 0, kills = player:GetAttribute("TotalKills") or 0 })
	local need = player:GetAttribute("XPNeed") or 1
	xpFill.Size = UDim2.new(math.clamp((player:GetAttribute("XP") or 0) / math.max(need, 1), 0, 1), 0, 1, 0)
	hintText.Text = T("LOBBY_HINT")
	if phase ~= "Match" and phase ~= "Ended" and specBar.Visible then
		specBar.Visible = false
		spectating = nil
	end
end

task.spawn(function()
	while true do
		local ok, err = pcall(updateHUD)
		if not ok then
			warn("[HUD]", err)
		end
		task.wait(0.1)
	end
end)
