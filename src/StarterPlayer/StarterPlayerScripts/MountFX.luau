--[[
	MountFX (ModuleScript em StarterPlayer > StarterPlayerScripts)
	v21: as MONTARIAS ganham vida na tela de cada jogador (o servidor continua só prendendo o modelo
	no personagem; nada muda na velocidade nem nas regras).
	  • Skate: rodas girando, balança de leve, empina ao acelerar, inclina nas curvas, poeira + faíscas
	  • Go-Kart: rodas girando, motor "tremendo", inclina nas curvas, fumaça no escapamento e rastro colorido
	  • Critter Ride: o bichinho dá pulinhos no ritmo da corrida, rebola, inclina nas curvas, coraçõezinhos
	Como funciona: a montaria do servidor fica INVISÍVEL só na sua tela e uma cópia local (ancorada) é
	desenhada em cima dela, todo frame, com a animação. Longe da câmera (FAR) a cópia some e a original volta.
	"Low graphics" (SETTINGS) desliga as partículas; a animação continua (é barata).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MountFX = {}

local FAR = 220 -- studs: mais longe que isso não anima
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

type Piece = { Server: BasePart, Local: BasePart, Rel: CFrame, Wheel: boolean, Radius: number }
type Rig = {
	Model: Model,
	Root: BasePart,
	Humanoid: Humanoid?,
	Kind: string,
	Pieces: { Piece },
	PivotRel: CFrame,
	Back: number,
	Fx: BasePart?,
	Emitters: { [string]: ParticleEmitter },
	Trails: { Trail },
	Spin: number,
	Lean: number,
	Pitch: number,
	LastSpeed: number,
	LastYaw: number,
	Step: number,
	Phase: number,
	Hidden: boolean?,
}

local rigs: { [Model]: Rig } = {}
local folder: Folder? = nil

local function angleDelta(from: number, to: number): number
	local d = (to - from) % (math.pi * 2)
	if d > math.pi then
		d -= math.pi * 2
	end
	return d
end

local function getFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "MountFX"
	f.Parent = workspace
	folder = f
	return f
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

local function seq(a: number, b: number): NumberSequence
	return NumberSequence.new(a, b)
end

-- Partículas e rastros de cada montaria (ficam numa peça invisível atrás dela)
local function buildFx(rig: Rig, lowGfx: boolean)
	if lowGfx then
		return
	end
	local fx = Instance.new("Part")
	fx.Name = "Fx"
	fx.Anchored = true
	fx.CanCollide = false
	fx.CanQuery = false
	fx.CanTouch = false
	fx.CastShadow = false
	fx.Transparency = 1
	fx.Size = Vector3.new(1.4, 0.4, 0.6)
	fx.CFrame = rig.Root.CFrame
	fx.Parent = getFolder()
	rig.Fx = fx
	local kind = rig.Kind
	if kind == "skate" or kind == "critter" then
		rig.Emitters.Dust = emitter(fx, {
			Name = "Dust",
			Texture = SMOKE,
			Color = ColorSequence.new(Color3.fromRGB(225, 210, 180)),
			Size = seq(0.5, 1.8),
			Transparency = seq(0.55, 1),
			Lifetime = NumberRange.new(0.45, 0.8),
			Speed = NumberRange.new(2, 4),
			SpreadAngle = Vector2.new(25, 25),
			EmissionDirection = Enum.NormalId.Back,
			Rate = 0,
		})
	end
	if kind == "skate" then
		rig.Emitters.Sparks = emitter(fx, {
			Name = "Sparks",
			Texture = SPARK,
			Color = ColorSequence.new(Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 150, 40)),
			LightEmission = 1,
			Size = seq(0.3, 0),
			Lifetime = NumberRange.new(0.2, 0.4),
			Speed = NumberRange.new(6, 11),
			SpreadAngle = Vector2.new(35, 35),
			Acceleration = Vector3.new(0, -30, 0),
			EmissionDirection = Enum.NormalId.Back,
			Rate = 0,
		})
	elseif kind == "cart" then
		rig.Emitters.Smoke = emitter(fx, {
			Name = "Smoke",
			Texture = SMOKE,
			Color = ColorSequence.new(Color3.fromRGB(150, 150, 160), Color3.fromRGB(110, 110, 120)),
			Size = seq(0.6, 2.2),
			Transparency = seq(0.4, 1),
			Lifetime = NumberRange.new(0.6, 1.1),
			Speed = NumberRange.new(3, 5),
			SpreadAngle = Vector2.new(20, 20),
			RotSpeed = NumberRange.new(-60, 60),
			EmissionDirection = Enum.NormalId.Back,
			Rate = 6,
		})
		-- rastro colorido atrás das rodas de trás
		for i, x in { -0.95, 0.95 } do
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(x, 0.25, 0)
			a0.Parent = fx
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(x, -0.25, 0)
			a1.Parent = fx
			local trail = Instance.new("Trail")
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, if i == 1 then Color3.fromRGB(255, 120, 60) else Color3.fromRGB(80, 200, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 240, 120)),
			})
			trail.Transparency = NumberSequence.new(0.25, 1)
			trail.Lifetime = 0.35
			trail.LightEmission = 0.6
			trail.WidthScale = NumberSequence.new(1, 0.2)
			trail.Enabled = false
			trail.Parent = fx
			table.insert(rig.Trails, trail)
		end
	elseif kind == "critter" then
		rig.Emitters.Hearts = emitter(fx, {
			Name = "Hearts",
			Texture = SPARK,
			Color = ColorSequence.new(Color3.fromRGB(255, 120, 180), Color3.fromRGB(255, 200, 230)),
			LightEmission = 0.7,
			Size = seq(0.45, 0.1),
			Transparency = seq(0.1, 1),
			Lifetime = NumberRange.new(0.9, 1.4),
			Speed = NumberRange.new(2, 3.5),
			SpreadAngle = Vector2.new(40, 40),
			EmissionDirection = Enum.NormalId.Top,
			Rate = 1.5,
		})
	end
end

local function destroyRig(model: Model)
	local rig = rigs[model]
	if not rig then
		return
	end
	rigs[model] = nil
	for _, piece in rig.Pieces do
		if piece.Server.Parent then
			piece.Server.LocalTransparencyModifier = 0
		end
		piece.Local:Destroy()
	end
	if rig.Fx then
		rig.Fx:Destroy()
	end
end

local function buildRig(character: Model, model: Model)
	if rigs[model] then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local player = Players.LocalPlayer
	local owner = Players:GetPlayerFromCharacter(character)
	local kind = owner and owner:GetAttribute("Mounted")
	if typeof(kind) ~= "string" then
		-- o atributo ainda não chegou: descobre pelas peças
		if model:FindFirstChild("Deck") then
			kind = "skate"
		elseif model:FindFirstChild("Body") or model:FindFirstChild("Seat") then
			kind = "cart"
		elseif model:FindFirstChild("Root") then
			kind = "critter"
		else
			kind = "skate"
		end
	end
	local pivot = model:GetPivot()
	local _, size = model:GetBoundingBox()
	local rig: Rig = {
		Model = model,
		Root = root,
		Humanoid = character:FindFirstChildOfClass("Humanoid"),
		Kind = kind,
		Pieces = {},
		PivotRel = root.CFrame:ToObjectSpace(pivot),
		Back = size.Z / 2,
		Fx = nil,
		Emitters = {},
		Trails = {},
		Spin = 0,
		Lean = 0,
		Pitch = 0,
		LastSpeed = 0,
		LastYaw = 0,
		Step = 0,
		Phase = math.random() * 6,
	}
	local holder = getFolder()
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local copy = part:Clone()
			for _, child in copy:GetChildren() do
				if child:IsA("JointInstance") or child:IsA("Constraint") or child:IsA("WeldConstraint") or child:IsA("ProximityPrompt") or child:IsA("BillboardGui") then
					child:Destroy()
				end
			end
			copy.Anchored = true
			copy.CanCollide = false
			copy.CanQuery = false
			copy.CanTouch = false
			copy.Massless = true
			copy.LocalTransparencyModifier = 0
			copy.Parent = holder
			local wheel = part.Name == "Wheel" and part:IsA("Part") and part.Shape == Enum.PartType.Cylinder
			table.insert(rig.Pieces, {
				Server = part,
				Local = copy,
				Rel = pivot:ToObjectSpace(part.CFrame),
				Wheel = wheel,
				Radius = math.max(part.Size.Y / 2, 0.2),
			})
			part.LocalTransparencyModifier = 1
		end
	end
	if #rig.Pieces == 0 then
		return
	end
	buildFx(rig, player:GetAttribute("LowGfx") == true)
	rigs[model] = rig
end

local function watchCharacter(character: Model)
	local function onMount(child: Instance)
		if child.Name == "Mount" and child:IsA("Model") then
			-- as peças podem chegar um pouquinho depois do modelo
			task.delay(0.15, function()
				if child.Parent == character then
					buildRig(character, child)
				end
			end)
		end
	end
	character.ChildAdded:Connect(onMount)
	character.ChildRemoved:Connect(function(child)
		if child:IsA("Model") and rigs[child] then
			destroyRig(child)
		end
	end)
	character.Destroying:Connect(function()
		for model, rig in rigs do
			if rig.Root.Parent == nil or rig.Root:IsDescendantOf(character) then
				destroyRig(model)
			end
		end
	end)
	for _, child in character:GetChildren() do
		onMount(child)
	end
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end
end

local function setHidden(rig: Rig, hidden: boolean)
	if rig.Hidden == hidden then
		return
	end
	rig.Hidden = hidden
	for _, piece in rig.Pieces do
		piece.Local.LocalTransparencyModifier = if hidden then 1 else 0
		if piece.Server.Parent then
			piece.Server.LocalTransparencyModifier = if hidden then 0 else 1
		end
	end
	for _, e in rig.Emitters do
		e.Enabled = not hidden
	end
end

local function stepRig(rig: Rig, dt: number, cameraPosition: Vector3, now: number)
	local root = rig.Root
	local cf = root.CFrame
	if (cf.Position - cameraPosition).Magnitude > FAR then
		setHidden(rig, true)
		return
	end
	setHidden(rig, false)
	-- o Roblox mexe no LocalTransparencyModifier do personagem ao dar zoom: garante todo frame
	for _, piece in rig.Pieces do
		if piece.Server.Parent then
			piece.Server.LocalTransparencyModifier = 1
		end
	end

	local vel = root.AssemblyLinearVelocity
	local flat = Vector3.new(vel.X, 0, vel.Z)
	local speed = flat.Magnitude
	local look = cf.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	local forwardSpeed = if flatLook.Magnitude > 0.01 then flat:Dot(flatLook.Unit) else 0
	local yaw = math.atan2(-look.X, -look.Z)
	local yawRate = angleDelta(rig.LastYaw, yaw) / dt
	rig.LastYaw = yaw
	local accel = (forwardSpeed - rig.LastSpeed) / dt
	rig.LastSpeed = forwardSpeed
	local moving = math.clamp(speed / 6, 0, 1)
	local grounded = true
	if rig.Humanoid then
		grounded = rig.Humanoid.FloorMaterial ~= Enum.Material.Air
	end

	-- inclina nas curvas e empina ao acelerar (suave)
	local leanGoal = math.clamp(-yawRate * 0.11 * math.clamp(speed / 14, 0, 1), -0.42, 0.42)
	rig.Lean += (leanGoal - rig.Lean) * (1 - math.exp(-dt * 8))
	local pitchGoal = math.clamp(accel * 0.012, -0.22, 0.28)
	if not grounded then
		pitchGoal += 0.12 -- no ar: nariz para cima
	end
	rig.Pitch += (pitchGoal - rig.Pitch) * (1 - math.exp(-dt * 5))

	local bob, roll, pitch, kind = 0, 0, 0, rig.Kind
	if kind == "skate" then
		bob = math.sin(now * 9 + rig.Phase) * 0.05 * moving
		roll = math.sin(now * 4.5 + rig.Phase) * 0.05 * moving
	elseif kind == "cart" then
		bob = math.sin(now * 38) * 0.02 * (0.35 + moving)
		roll = math.sin(now * 38 + 1) * 0.008
	elseif kind == "critter" then
		-- pulinhos no ritmo da corrida (igual aos pets)
		local rate = math.clamp(1.8 + speed * 0.12, 1.8, 4.4)
		if moving > 0.05 or rig.Step % 1 > 0.02 then
			rig.Step += dt * rate
		end
		local k = rig.Step % 1
		local amount = math.max(moving, if k > 0.02 then 0.3 else 0)
		bob = 4 * k * (1 - k) * 0.45 * amount
		roll = math.sin(rig.Step * math.pi) * math.rad(8) * moving
		pitch = -math.rad(9) * math.clamp(speed / 20, 0, 1)
	end

	local pivotWorld = cf * rig.PivotRel
	local visual = pivotWorld * CFrame.Angles(rig.Pitch + pitch, 0, rig.Lean + roll) * CFrame.new(0, bob, 0)
	if grounded then
		rig.Spin += forwardSpeed * dt
	end
	for _, piece in rig.Pieces do
		local target = visual * piece.Rel
		if piece.Wheel then
			target = target * CFrame.Angles(-rig.Spin / piece.Radius, 0, 0)
		end
		piece.Local.CFrame = target
	end

	-- efeitos
	local fx = rig.Fx
	if fx then
		fx.CFrame = visual * CFrame.new(0, 0.25, rig.Back - 0.2)
		local dust = rig.Emitters.Dust
		if dust then
			dust.Rate = if grounded then 16 * moving else 0
		end
		local sparks = rig.Emitters.Sparks
		if sparks then
			sparks.Rate = if grounded and speed > 15 then 12 + (speed - 15) * 1.5 else 0
		end
		local smoke = rig.Emitters.Smoke
		if smoke then
			smoke.Rate = 5 + 18 * moving
		end
		for _, trail in rig.Trails do
			trail.Enabled = speed > 8
		end
	end
end

function MountFX.Init()
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local character = player.Character
		if character then
			for model, rig in rigs do
				if rig.Root:IsDescendantOf(character) then
					destroyRig(model)
				end
			end
		end
	end)
	-- Low graphics ligado depois: tira as partículas
	Players.LocalPlayer:GetAttributeChangedSignal("LowGfx"):Connect(function()
		if Players.LocalPlayer:GetAttribute("LowGfx") == true then
			for _, rig in rigs do
				if rig.Fx then
					rig.Fx:Destroy()
					rig.Fx = nil
					rig.Emitters = {}
					rig.Trails = {}
				end
			end
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		dt = math.clamp(dt, 1 / 240, 0.1)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local cameraPosition = camera.CFrame.Position
		local now = os.clock()
		for model, rig in rigs do
			if not model.Parent or not rig.Root.Parent then
				destroyRig(model)
			else
				stepRig(rig, dt, cameraPosition, now)
			end
		end
	end)
end

return MountFX
