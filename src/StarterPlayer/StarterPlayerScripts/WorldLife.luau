--[[
	WorldLife (v27): deixa os mundos VIVOS. Tudo aqui é só visual/local (não dá prêmio nenhum).

	• Bichinhos de enfeite em cada mundo: borboletas (Meadow), ursinhos de goma pulando (Candy),
	  pinguins deslizando no lago (Frost), bolhas de lava e bolas de fogo (Lava), peixes pulando
	  do mar (Reef) e estrelas cadentes (Galaxy). Só existem no mundo em que você está.
	• Clima de cada mundo: confete de açúcar, neve + aurora boreal, brasas, bolhas, poeira de estrelas.
	• Chegada no mundo: nome grande na tela + flash.
	• Brincadeiras (a parte do corpo): camas elásticas/jatos (Tag Bounce), lava que volta para o
	  começo (Tag LavaReset), gravidade baixa (Tag LowGravity), gêiseres (Tag Geyser),
	  relógio dos baús (Tag FunPrize) e setas do caminho do Ovo Gigante (Tag Chase).
	• Base: bichinhos dormem à noite (Zzz), festa quando chega um Lendário+, "!" quando alguém invade,
	  sirene girando na base roubada (atributo AlarmUntil do Plot) e "SAVED!" quando você recupera.
	Modo gráfico leve (LowGfx): menos bichos, menos partículas.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Format = require(ReplicatedStorage.Shared:WaitForChild("Format"))

local WorldLife = {}

-- centro (X) de cada ilha, igual ao tools/build_project.py (1000 * posição)
local X0 = { candy = 1000, frost = 2000, lava = 3000, reef = 4000, galaxy = 5000 }
WorldLife.X0 = X0

local player = Players.LocalPlayer
local rng = Random.new()

local function lowGfx(): boolean
	return player:GetAttribute("LowGfx") == true
end

local function currentWorld(): string
	local w = player:GetAttribute("World")
	return if typeof(w) == "string" and w ~= "" then w else "meadow"
end

local function rootPart(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function isMine(hit: BasePart): boolean
	local character = player.Character
	return character ~= nil and hit:IsDescendantOf(character)
end

local function newPart(props): BasePart
	local p = Instance.new(props.Class or "Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = props.Size or Vector3.one
	p.Color = props.Color or Color3.new(1, 1, 1)
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Transparency = props.Transparency or 0
	if props.Shape then
		p.Shape = props.Shape
	end
	p.Parent = props.Parent
	return p
end

local function emitter(parent: Instance, props): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function seq(a: number, b: number): NumberSequence
	return NumberSequence.new(a, b)
end

---------------------------------------------------------------------
-- Bichinhos de enfeite (um conjunto por mundo; some quando você sai)
---------------------------------------------------------------------
type Critter = { Parts: { BasePart }, Update: (number) -> () }

local function butterfly(folder: Folder, center: Vector3, color: Color3): Critter
	local body = newPart({ Size = Vector3.new(0.3, 0.3, 1), Color = Color3.fromRGB(40, 30, 30), Parent = folder })
	local wingL = newPart({ Size = Vector3.new(1.2, 0.1, 1), Color = color, Material = Enum.Material.Neon, Parent = folder })
	local wingR = newPart({ Size = Vector3.new(1.2, 0.1, 1), Color = color, Material = Enum.Material.Neon, Parent = folder })
	local radius, speed, phase, height = rng:NextNumber(6, 14), rng:NextNumber(0.4, 0.8), rng:NextNumber(0, 6.28), rng:NextNumber(4, 8)
	return {
		Parts = { body, wingL, wingR },
		Update = function(t)
			local a = phase + t * speed
			local pos = center + Vector3.new(math.cos(a) * radius, height + math.sin(t * 2 + phase) * 1.2, math.sin(a) * radius)
			local cf = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a)))
			local flap = math.sin(t * 18 + phase) * 0.9
			body.CFrame = cf
			wingL.CFrame = cf * CFrame.Angles(0, 0, flap) * CFrame.new(-0.6, 0, 0)
			wingR.CFrame = cf * CFrame.Angles(0, 0, -flap) * CFrame.new(0.6, 0, 0)
		end,
	}
end

local function gummy(folder: Folder, center: Vector3, color: Color3): Critter
	local body = newPart({ Size = Vector3.new(2.2, 2.6, 2), Color = color, Material = Enum.Material.Glass, Transparency = 0.15, Shape = Enum.PartType.Ball, Parent = folder })
	local earL = newPart({ Size = Vector3.new(0.9, 0.9, 0.9), Color = color, Material = Enum.Material.Glass, Transparency = 0.15, Shape = Enum.PartType.Ball, Parent = folder })
	local earR = newPart({ Size = Vector3.new(0.9, 0.9, 0.9), Color = color, Material = Enum.Material.Glass, Transparency = 0.15, Shape = Enum.PartType.Ball, Parent = folder })
	local radius, speed, phase = rng:NextNumber(10, 22), rng:NextNumber(0.15, 0.3), rng:NextNumber(0, 6.28)
	return {
		Parts = { body, earL, earR },
		Update = function(t)
			local a = phase + t * speed
			local hop = math.abs(math.sin(t * 4 + phase)) * 2.6
			local pos = center + Vector3.new(math.cos(a) * radius, 1.3 + hop, math.sin(a) * radius)
			local cf = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a)))
			body.CFrame = cf
			earL.CFrame = cf * CFrame.new(-0.7, 1.2, 0)
			earR.CFrame = cf * CFrame.new(0.7, 1.2, 0)
		end,
	}
end

local function penguin(folder: Folder, center: Vector3): Critter
	local body = newPart({ Size = Vector3.new(1.8, 2.4, 1.6), Color = Color3.fromRGB(30, 30, 40), Shape = Enum.PartType.Ball, Parent = folder })
	local belly = newPart({ Size = Vector3.new(1.3, 1.8, 0.6), Color = Color3.fromRGB(245, 245, 250), Shape = Enum.PartType.Ball, Parent = folder })
	local beak = newPart({ Size = Vector3.new(0.4, 0.3, 0.6), Color = Color3.fromRGB(255, 160, 40), Parent = folder })
	local radius, speed, phase = rng:NextNumber(8, 16), rng:NextNumber(0.25, 0.45), rng:NextNumber(0, 6.28)
	return {
		Parts = { body, belly, beak },
		Update = function(t)
			local a = phase + t * speed
			local slide = (math.floor((t + phase) / 4) % 2) == 1 -- anda um pouco, desliza um pouco
			local pos = center + Vector3.new(math.cos(a) * radius, if slide then 0.8 else 1.2, math.sin(a) * radius)
			local cf = CFrame.lookAt(pos, pos + Vector3.new(-math.sin(a), 0, math.cos(a)))
			if slide then
				cf *= CFrame.Angles(-1.3, 0, 0)
			else
				cf *= CFrame.Angles(0, 0, math.sin(t * 8 + phase) * 0.18)
			end
			body.CFrame = cf
			belly.CFrame = cf * CFrame.new(0, -0.1, -0.55)
			beak.CFrame = cf * CFrame.new(0, 0.6, -0.95)
		end,
	}
end

local function fish(folder: Folder, x0: number, side: number, color: Color3): Critter
	local body = newPart({ Size = Vector3.new(1, 1, 2), Color = color, Shape = Enum.PartType.Ball, Parent = folder })
	local tail = newPart({ Class = "WedgePart", Size = Vector3.new(0.2, 1, 0.9), Color = color, Parent = folder })
	local x, period, phase = x0 + rng:NextNumber(-140, 140), rng:NextNumber(2.5, 4), rng:NextNumber(0, 4)
	return {
		Parts = { body, tail },
		Update = function(t)
			local k = ((t + phase) % period) / period -- 0..1: um pulo
			local z = side * (96 + k * 14)
			local y = -1 + math.sin(k * math.pi) * 9
			local pos = Vector3.new(x, y, z)
			local dir = Vector3.new(0, math.cos(k * math.pi) * 9, side * 14)
			local cf = CFrame.lookAt(pos, pos + dir)
			body.CFrame = cf
			tail.CFrame = cf * CFrame.new(0, 0, 1.3) * CFrame.Angles(0, math.sin(t * 20) * 0.5, 0)
		end,
	}
end

local function jumpingCritters(worldId: string, folder: Folder, count: number): { Critter }
	local list = {}
	if worldId == "meadow" then
		local colors = { Color3.fromRGB(255, 140, 200), Color3.fromRGB(255, 220, 90), Color3.fromRGB(140, 200, 255), Color3.fromRGB(200, 150, 255) }
		for i = 1, count do
			local center = Vector3.new(rng:NextNumber(-170, 170), 0, rng:NextNumber(-160, 170))
			table.insert(list, butterfly(folder, center, colors[(i % #colors) + 1]))
		end
	elseif worldId == "candy" then
		local colors = { Color3.fromRGB(255, 80, 110), Color3.fromRGB(120, 220, 120), Color3.fromRGB(255, 200, 60), Color3.fromRGB(150, 120, 255) }
		for i = 1, count do
			local center = Vector3.new(X0.candy + rng:NextNumber(-130, 20), 0, rng:NextNumber(25, 75) * (if i % 2 == 0 then 1 else -1))
			table.insert(list, gummy(folder, center, colors[(i % #colors) + 1]))
		end
	elseif worldId == "frost" then
		for i = 1, count do
			local lake = if i % 2 == 0 then Vector3.new(X0.frost - 90, 0, 56) else Vector3.new(X0.frost - 20, 0, -45)
			table.insert(list, penguin(folder, lake))
		end
	elseif worldId == "reef" then
		local colors = { Color3.fromRGB(255, 150, 60), Color3.fromRGB(80, 200, 255), Color3.fromRGB(255, 230, 80), Color3.fromRGB(255, 110, 150) }
		for i = 1, count do
			table.insert(list, fish(folder, X0.reef, if i % 2 == 0 then 1 else -1, colors[(i % #colors) + 1]))
		end
	end
	return list
end

---------------------------------------------------------------------
-- Clima de cada mundo (emissor que segue a câmera)
---------------------------------------------------------------------
local WEATHER = {
	candy = { Color = ColorSequence.new(Color3.fromRGB(255, 170, 220), Color3.fromRGB(170, 230, 255)), Rate = 22, Size = seq(0.35, 0.25), Speed = NumberRange.new(4, 7), Accel = Vector3.new(0, -2, 0), Light = 0.3, Above = true },
	frost = { Color = ColorSequence.new(Color3.new(1, 1, 1)), Rate = 60, Size = seq(0.3, 0.2), Speed = NumberRange.new(5, 9), Accel = Vector3.new(1, -2, 0), Light = 0.2, Above = true },
	lava = { Color = ColorSequence.new(Color3.fromRGB(255, 190, 70), Color3.fromRGB(255, 70, 20)), Rate = 30, Size = seq(0.25, 0), Speed = NumberRange.new(1, 3), Accel = Vector3.new(0, 5, 0), Light = 1, Above = false },
	reef = { Color = ColorSequence.new(Color3.fromRGB(210, 250, 255)), Rate = 14, Size = seq(0.3, 0.7), Speed = NumberRange.new(1, 2), Accel = Vector3.new(0, 3, 0), Light = 0.4, Above = false },
	galaxy = { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 150, 255)), Rate = 18, Size = seq(0.25, 0), Speed = NumberRange.new(0.5, 1.5), Accel = Vector3.zero, Light = 1, Above = true },
}

function WorldLife.Init(ctx)
	local life = Instance.new("Folder")
	life.Name = "WorldLife"
	life.Parent = workspace
	local defaultGravity = workspace.Gravity

	-- clima
	local anchor = newPart({ Size = Vector3.new(90, 1, 90), Transparency = 1, Parent = life })
	local weather: ParticleEmitter? = nil
	local weatherAbove = true
	local aurora: { BasePart } = {}
	local function setWeather(worldId: string)
		if weather then
			weather:Destroy()
			weather = nil
		end
		for _, p in aurora do
			p:Destroy()
		end
		table.clear(aurora)
		local w = WEATHER[worldId]
		if not w then
			return
		end
		weatherAbove = w.Above
		weather = emitter(anchor, {
			Color = w.Color,
			Rate = if lowGfx() then w.Rate * 0.3 else w.Rate,
			Size = w.Size,
			Speed = w.Speed,
			Acceleration = w.Accel,
			LightEmission = w.Light,
			Lifetime = NumberRange.new(4, 6),
			EmissionDirection = if w.Above then Enum.NormalId.Bottom else Enum.NormalId.Top,
			SpreadAngle = Vector2.new(20, 20),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-90, 90),
			Transparency = seq(0.1, 0.6),
		})
		if worldId == "frost" and not lowGfx() then
			for i = 1, 3 do
				table.insert(aurora, newPart({
					Size = Vector3.new(420, 16, 1),
					Material = Enum.Material.Neon,
					Transparency = 0.65,
					Color = Color3.fromRGB(80, 255, 170),
					Parent = life,
				}))
				aurora[i].CFrame = CFrame.new(X0.frost, 95 + i * 9, -170 - i * 22) * CFrame.Angles(math.rad(-25), 0, math.rad((i - 2) * 4))
			end
		end
	end

	-- bichinhos de enfeite + bolhas/bolas de fogo/estrelas cadentes
	local critters: { Critter } = {}
	local critterFolder: Folder? = nil
	local world = currentWorld()
	local function setCritters(worldId: string)
		if critterFolder then
			critterFolder:Destroy()
		end
		critterFolder = Instance.new("Folder")
		critterFolder.Name = "Critters"
		critterFolder.Parent = life
		local counts = { meadow = 8, candy = 7, frost = 6, reef = 10 }
		local count = counts[worldId] or 0
		if lowGfx() then
			count = math.ceil(count / 3)
		end
		critters = jumpingCritters(worldId, critterFolder :: Folder, count)
	end

	local function burst(pos: Vector3, color: Color3, size: number, rise: number, life_: number)
		local ball = newPart({ Size = Vector3.one * size, Color = color, Material = Enum.Material.Neon, Shape = Enum.PartType.Ball, Parent = critterFolder or life })
		ball.CFrame = CFrame.new(pos)
		TweenService:Create(ball, TweenInfo.new(life_, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.one * size * 2.2,
			Transparency = 1,
			CFrame = CFrame.new(pos + Vector3.new(0, rise, 0)),
		}):Play()
		task.delay(life_ + 0.1, function()
			ball:Destroy()
		end)
	end

	local function arc(from: Vector3, to: Vector3, height: number, duration: number, part: BasePart)
		local start = os.clock()
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local k = (os.clock() - start) / duration
			if k >= 1 or not part.Parent then
				conn:Disconnect()
				if part.Parent then
					part:Destroy()
				end
				return
			end
			local p = from:Lerp(to, k) + Vector3.new(0, math.sin(k * math.pi) * height, 0)
			part.CFrame = CFrame.new(p)
		end)
	end

	local spawnTimer = 0
	local function spawnExtras(dt: number)
		spawnTimer -= dt
		if spawnTimer > 0 or lowGfx() then
			return
		end
		if world == "lava" then
			spawnTimer = 0.35
			local x = X0.lava + rng:NextNumber(-150, 150)
			local z = if rng:NextNumber() < 0.5 then 52 + rng:NextNumber(-5, 5) else 58 + rng:NextNumber(-15, 15)
			burst(Vector3.new(x, 0.6, z), Color3.fromRGB(255, 130, 40), rng:NextNumber(0.8, 1.6), 1.5, 0.8)
			if rng:NextNumber() < 0.12 then -- bola de fogo saindo do vulcão
				local ball = newPart({ Size = Vector3.one * 2, Color = Color3.fromRGB(255, 120, 30), Material = Enum.Material.Neon, Shape = Enum.PartType.Ball, Parent = critterFolder or life })
				emitter(ball, { Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 60, 20)), Rate = 30, Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(0, 1), Size = seq(1.2, 0), LightEmission = 1 })
				local from = Vector3.new(X0.lava + 105, 22, -62)
				arc(from, from + Vector3.new(rng:NextNumber(-40, 40), -22, rng:NextNumber(10, 40)), 26, 2.2, ball)
			end
		elseif world == "galaxy" then
			spawnTimer = rng:NextNumber(0.8, 1.8)
			local star = newPart({ Size = Vector3.new(0.6, 0.6, 5), Color = Color3.fromRGB(255, 250, 220), Material = Enum.Material.Neon, Parent = critterFolder or life })
			local from = Vector3.new(X0.galaxy + rng:NextNumber(-200, 200), rng:NextNumber(70, 110), rng:NextNumber(-150, 150))
			local to = from + Vector3.new(rng:NextNumber(-120, 120), -40, rng:NextNumber(-120, 120))
			star.CFrame = CFrame.lookAt(from, to)
			TweenService:Create(star, TweenInfo.new(1.2, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(to, to + (to - from)), Transparency = 1 }):Play()
			task.delay(1.3, function()
				star:Destroy()
			end)
		elseif world == "reef" then
			spawnTimer = 0.5
			burst(Vector3.new(X0.reef + rng:NextNumber(-150, 150), 0.3, rng:NextNumber(-85, 85)), Color3.fromRGB(200, 250, 255), 0.6, 6, 2.5)
		else
			spawnTimer = 1
		end
	end

	---------------------------------------------------------------------
	-- Brincadeiras: camas elásticas / jatos, lava, gravidade baixa, gêiseres, baús
	---------------------------------------------------------------------
	local lastBounce = 0
	local function setupBounce(pad: Instance)
		if not pad:IsA("BasePart") then
			return
		end
		pad.Touched:Connect(function(hit)
			if not isMine(hit) or os.clock() - lastBounce < 0.35 then
				return
			end
			local root = rootPart()
			if not root then
				return
			end
			lastBounce = os.clock()
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(v.X, tonumber(pad:GetAttribute("Power")) or 80, v.Z)
			ctx.play("Swing")
			local base = pad.Transparency
			pad.Transparency = math.min(base + 0.4, 0.8)
			task.delay(0.15, function()
				pad.Transparency = base
			end)
		end)
	end

	local lastLava = 0
	local function setupLava(pool: Instance)
		if not pool:IsA("BasePart") then
			return
		end
		pool.Touched:Connect(function(hit)
			if not isMine(hit) or os.clock() - lastLava < 1 then
				return
			end
			local root = rootPart()
			local spot = pool:GetAttribute("Respawn")
			if not root or typeof(spot) ~= "string" then
				return
			end
			local x, y, z = string.match(spot, "([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)")
			if not x then
				return
			end
			lastLava = os.clock()
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame = CFrame.new(tonumber(x) :: number, tonumber(y) :: number, tonumber(z) :: number)
			ctx.flash(Color3.fromRGB(255, 120, 40), 0.35)
			ctx.toast("Oops! Hot lava - back to the start!", "warning")
		end)
	end

	for _, tag in { "Bounce", "LavaReset" } do
		local setup = if tag == "Bounce" then setupBounce else setupLava
		for _, p in CollectionService:GetTagged(tag) do
			setup(p)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(setup)
	end

	local lowZone = false
	local function updateGravity()
		local root = rootPart()
		local inside, factor = false, 1
		if root then
			for _, zone in CollectionService:GetTagged("LowGravity") do
				if zone:IsA("BasePart") then
					local offset = root.Position - zone.Position
					local radius = tonumber(zone:GetAttribute("Radius")) or 30
					if Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius and math.abs(offset.Y) < 120 then
						inside, factor = true, tonumber(zone:GetAttribute("Gravity")) or 0.3
						break
					end
				end
			end
		end
		if inside ~= lowZone then
			lowZone = inside
			workspace.Gravity = if inside then defaultGravity * factor else defaultGravity
			if inside then
				ctx.toast("Moon gravity! Jump super high!", "info")
			end
		end
	end
	player.CharacterAdded:Connect(function()
		lowZone = false
		workspace.Gravity = defaultGravity
	end)

	-- gêiser: jorra fogo de tempos em tempos (só visual)
	local geyserTimer = 0
	local function geysers(dt: number)
		geyserTimer -= dt
		if geyserTimer > 0 or world ~= "lava" then
			return
		end
		geyserTimer = rng:NextNumber(3, 5)
		for _, vent in CollectionService:GetTagged("Geyser") do
			if vent:IsA("BasePart") and rng:NextNumber() < 0.6 then
				local e = vent:FindFirstChild("Eruption") :: ParticleEmitter?
				if not e then
					e = emitter(vent, {
						Name = "Eruption",
						Color = ColorSequence.new(Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 70, 20)),
						Rate = 0,
						Lifetime = NumberRange.new(0.8, 1.4),
						Speed = NumberRange.new(28, 40),
						SpreadAngle = Vector2.new(10, 10),
						Acceleration = Vector3.new(0, -30, 0),
						Size = seq(2.2, 0.2),
						LightEmission = 1,
						EmissionDirection = Enum.NormalId.Top,
					})
				end
				(e :: ParticleEmitter):Emit(if lowGfx() then 12 else 40)
			end
		end
	end

	-- relógio em cima de cada baú (READY! ou quanto falta)
	local prizeLabels: { [BasePart]: TextLabel } = {}
	local function setupPrizeLabel(prize: Instance)
		if not prize:IsA("BasePart") or prizeLabels[prize] then
			return
		end
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(170, 44)
		gui.StudsOffset = Vector3.new(0, 6, 0)
		gui.MaxDistance = 120
		gui.AlwaysOnTop = true
		gui.Adornee = prize
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextStrokeTransparency = 0.2
		label.Parent = gui
		gui.Parent = prize
		prizeLabels[prize] = label
	end
	for _, p in CollectionService:GetTagged("FunPrize") do
		setupPrizeLabel(p)
	end
	CollectionService:GetInstanceAddedSignal("FunPrize"):Connect(setupPrizeLabel)
	local function updatePrizes()
		local now = os.time()
		for prize, label in prizeLabels do
			if not prize.Parent then
				prizeLabels[prize] = nil
				continue
			end
			local readyAt = player:GetAttribute("Fun_" .. tostring(prize:GetAttribute("Key")))
			if typeof(readyAt) == "number" and readyAt > now then
				label.Text = "\u{23F3} " .. Format.Time(readyAt - now)
				label.TextColor3 = Color3.fromRGB(210, 210, 230)
			else
				label.Text = "\u{1F381} TREASURE!"
				label.TextColor3 = Color3.fromRGB(255, 230, 90)
			end
		end
	end

	-- setas do caminho do Ovo Gigante (luz correndo em direção ao ovo)
	local chase: { BasePart } = {}
	local function refreshChase()
		chase = {}
		for _, p in CollectionService:GetTagged("Chase") do
			if p:IsA("BasePart") then
				table.insert(chase, p)
			end
		end
		table.sort(chase, function(a, b)
			return (tonumber(a:GetAttribute("Order")) or 0) < (tonumber(b:GetAttribute("Order")) or 0)
		end)
	end
	refreshChase()
	CollectionService:GetInstanceAddedSignal("Chase"):Connect(refreshChase)
	local chaseStep = 0

	---------------------------------------------------------------------
	-- Base: dormir à noite, festa, susto, sirene, SAVED!
	---------------------------------------------------------------------
	local function critterRoot(model: Instance): BasePart?
		if not model:IsA("Model") then
			return nil
		end
		return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	end

	local function addBillboard(model: Instance, name: string, text: string, color: Color3, seconds: number?)
		local root = critterRoot(model)
		if not root or root:FindFirstChild(name) then
			return
		end
		local gui = Instance.new("BillboardGui")
		gui.Name = name
		gui.Size = UDim2.fromOffset(60, 40)
		gui.StudsOffsetWorldSpace = Vector3.new(1.2, 3.5, 0)
		gui.MaxDistance = 90
		gui.Adornee = root
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = text
		label.TextColor3 = color
		label.TextStrokeTransparency = 0.3
		label.Parent = gui
		gui.Parent = root
		if seconds then
			task.delay(seconds, function()
				gui:Destroy()
			end)
		end
	end

	local function myBaseCritters(): { Instance }
		local list = {}
		for _, model in CollectionService:GetTagged("BaseCritter") do
			if model:GetAttribute("OwnerUserId") == player.UserId then
				table.insert(list, model)
			end
		end
		return list
	end

	local sleeping = false
	local function updateSleep()
		local night = workspace:GetAttribute("Night") == true and not lowGfx()
		local camera = workspace.CurrentCamera
		for _, model in CollectionService:GetTagged("BaseCritter") do
			local root = critterRoot(model)
			if root then
				local zzz = root:FindFirstChild("Zzz")
				local near = camera and (root.Position - camera.CFrame.Position).Magnitude < 90
				if night and near and not zzz then
					addBillboard(model, "Zzz", "z Z z", Color3.fromRGB(190, 210, 255))
				elseif (not night or not near) and zzz then
					zzz:Destroy()
				end
			end
		end
		sleeping = night
	end

	local loadedAt = os.clock()
	CollectionService:GetInstanceAddedSignal("BaseCritter"):Connect(function(model)
		if os.clock() - loadedAt < 15 or model:GetAttribute("OwnerUserId") ~= player.UserId then
			return
		end
		local rarity = model:GetAttribute("Rarity")
		if rarity ~= "Legendary" and rarity ~= "Mythic" and rarity ~= "Secret" then
			return
		end
		task.wait(0.5) -- espera ele chegar no pedestal
		for _, other in myBaseCritters() do
			local root = critterRoot(other)
			if root then
				local e = emitter(root, {
					Color = ColorSequence.new(Color3.fromRGB(255, 120, 200), Color3.fromRGB(120, 220, 255)),
					Rate = 0,
					Lifetime = NumberRange.new(1, 1.6),
					Speed = NumberRange.new(8, 14),
					SpreadAngle = Vector2.new(35, 35),
					Acceleration = Vector3.new(0, -18, 0),
					Size = seq(0.5, 0.3),
					Rotation = NumberRange.new(0, 360),
					RotSpeed = NumberRange.new(-200, 200),
					EmissionDirection = Enum.NormalId.Top,
				})
				e:Emit(if lowGfx() then 6 else 16)
				task.delay(2, function()
					e:Destroy()
				end)
				addBillboard(other, "Party", "\u{1F389}", Color3.new(1, 1, 1), 3)
			end
		end
	end)

	-- sirene girando na base que está sendo roubada (qualquer jogador vê)
	local sirens: { [Instance]: BasePart } = {}
	local function updateSirens(t: number)
		local plotsFolder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Plots")
		if not plotsFolder then
			return
		end
		local now = os.time()
		for _, plot in plotsFolder:GetChildren() do
			local untilTime = plot:GetAttribute("AlarmUntil")
			local active = typeof(untilTime) == "number" and untilTime > now
			local siren = sirens[plot]
			if active and not siren then
				local sign = plot:FindFirstChild("Sign")
				local base = if sign and sign:IsA("BasePart") then sign.Position + Vector3.new(0, sign.Size.Y / 2 + 2, 0) else nil
				if base then
					siren = newPart({ Size = Vector3.new(2.4, 2.4, 2.4), Color = Color3.fromRGB(255, 40, 40), Material = Enum.Material.Neon, Shape = Enum.PartType.Ball, Parent = life })
					siren.CFrame = CFrame.new(base)
					local light = Instance.new("SpotLight")
					light.Color = Color3.fromRGB(255, 40, 40)
					light.Brightness = 8
					light.Range = 40
					light.Angle = 50
					light.Parent = siren
					sirens[plot] = siren
				end
			elseif not active and siren then
				siren:Destroy()
				sirens[plot] = nil
			end
			if active and sirens[plot] then
				local s = sirens[plot]
				s.CFrame = CFrame.new(s.Position) * CFrame.Angles(0, t * 8, 0) * CFrame.Angles(math.rad(-20), 0, 0)
			end
		end
	end

	-- efeitos que o servidor manda
	ctx.EffectEvent.OnClientEvent:Connect(function(kind, data)
		if kind == "Saved" and typeof(data) == "Vector3" then
			ctx.floatingText(data + Vector3.new(0, 2, 0), "SAVED!", Color3.fromRGB(120, 255, 140))
			ctx.bigText("SAVED!", Color3.fromRGB(120, 255, 140))
			ctx.play("Rare")
			burst(data, Color3.fromRGB(120, 255, 140), 3, 4, 0.8)
		elseif kind == "Alarm" then
			for _, model in myBaseCritters() do
				addBillboard(model, "Scared", "!", Color3.fromRGB(255, 80, 80), 3)
			end
		elseif kind == "FunPrize" and typeof(data) == "Vector3" then
			ctx.bigText("TREASURE!", Color3.fromRGB(255, 220, 90))
			ctx.play("Rare")
			burst(data, Color3.fromRGB(255, 220, 90), 4, 6, 1)
		elseif kind == "SnowHit" and typeof(data) == "Vector3" then
			ctx.floatingText(data, "SPLAT!", Color3.fromRGB(230, 245, 255))
			ctx.play("Bonk")
		elseif kind == "Splat" then
			local screen = ctx.gui
			for _ = 1, 3 do
				local blob = Instance.new("Frame")
				blob.AnchorPoint = Vector2.new(0.5, 0.5)
				blob.Position = UDim2.fromScale(rng:NextNumber(0.3, 0.7), rng:NextNumber(0.3, 0.7))
				blob.Size = UDim2.fromOffset(rng:NextInteger(120, 200), rng:NextInteger(100, 170))
				blob.BackgroundColor3 = Color3.fromRGB(250, 252, 255)
				blob.BackgroundTransparency = 0.1
				blob.ZIndex = 50
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0.5, 0)
				corner.Parent = blob
				blob.Parent = screen
				TweenService:Create(blob, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()
				task.delay(1.5, function()
					blob:Destroy()
				end)
			end
			ctx.play("Bonk")
		end
	end)

	---------------------------------------------------------------------
	-- Chegada no mundo + troca de clima/bichos
	---------------------------------------------------------------------
	local function enterWorld(worldId: string, announce: boolean)
		world = worldId
		setWeather(worldId)
		setCritters(worldId)
		if announce and worldId ~= "meadow" then
			local info = Config.WorldById and Config.WorldById[worldId]
			local name = if info and info.Name then string.upper(info.Name) else string.upper(worldId)
			local color = if info and typeof(info.Color) == "Color3" then info.Color else Color3.fromRGB(255, 220, 90)
			ctx.flash(color, 0.35)
			ctx.bigText(name, color)
			ctx.play("Swing")
		end
	end
	enterWorld(world, false)
	player:GetAttributeChangedSignal("World"):Connect(function()
		local now = currentWorld()
		if now ~= world then
			enterWorld(now, true)
		end
	end)
	player:GetAttributeChangedSignal("LowGfx"):Connect(function()
		enterWorld(world, false)
	end)

	---------------------------------------------------------------------
	-- Um loop só (por frame: bichos e clima; devagar: o resto)
	---------------------------------------------------------------------
	local slow, slower = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		local t = os.clock()
		local camera = workspace.CurrentCamera
		if camera then
			local offset = if weatherAbove then Vector3.new(0, 25, 0) else Vector3.new(0, -8, 0)
			anchor.CFrame = CFrame.new(camera.CFrame.Position + offset)
		end
		for _, c in critters do
			c.Update(t)
		end
		for i, p in aurora do
			p.Color = Color3.fromHSV((0.35 + 0.15 * math.sin(t * 0.3 + i)) % 1, 0.7, 1)
			p.Transparency = 0.55 + 0.2 * math.sin(t * 0.8 + i * 1.7)
		end
		spawnExtras(dt)
		geysers(dt)
		updateGravity()
		updateSirens(t)
		slow += dt
		if slow >= 0.12 then
			slow = 0
			chaseStep += 1
			local n = #chase
			for i, p in chase do
				local lit = ((chaseStep - i) % math.max(n, 1)) < 3
				p.Transparency = if lit then 0 else 0.65
			end
		end
		slower += dt
		if slower >= 1 then
			slower = 0
			updatePrizes()
			updateSleep()
		end
	end)
	WorldLife.IsSleeping = function()
		return sleeping
	end
end

return WorldLife
