--[[
	ThumbStudio (SÓ PRO STUDIO, modo edição)
	Monta "fotos" com fundo verde pra fazer ícone e thumbnails do jogo.

	Uso na barra de comando do Studio (sem dar Play):
	  local T = require(game.ServerScriptService.Game.ThumbStudio)
	  T.Shot("hero_gold")      -- noob correndo com o ovo dourado na cabeça
	  T.Shot("guardian_heartcorn")
	  T.Clear()                -- apaga tudo e devolve a câmera

	Nada disso roda no jogo: o módulo não é chamado por nenhum script.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Builder = require(Shared.CritterBuilder)
local Models3D = require(Shared.Models3D)

local T = {}

local ORIGIN = Vector3.new(0, 1000, 0)
local GREEN = Color3.fromRGB(0, 255, 0)

local NOOB = {
	Head = Color3.fromRGB(245, 205, 48),
	Arm = Color3.fromRGB(245, 205, 48),
	Torso = Color3.fromRGB(13, 105, 172),
	Leg = Color3.fromRGB(75, 151, 75),
}

local function folder(): Model
	local f = workspace:FindFirstChild("ThumbStudio")
	if not f then
		f = Instance.new("Model")
		f.Name = "ThumbStudio"
		f.Parent = workspace
	end
	return f :: Model
end

function T.Clear()
	local f = workspace:FindFirstChild("ThumbStudio")
	if f then
		f:Destroy()
	end
	local old = workspace:FindFirstChild("IconStudio")
	if old then
		old:Destroy()
	end
	workspace.CurrentCamera.CameraType = Enum.CameraType.Fixed
	workspace.CurrentCamera.FieldOfView = 70
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

--[[
	Avatar estilo "noob" clássico (R6), feito de peças.
	pose: "carry" (ovo em cima da cabeça), "run" (braços balançando),
	      "scared" (braços pra frente, olhando pra trás), "point" (apontando)
	A frente do boneco é -Z.
]]
function T.Avatar(pose: string?, colors: any?): Model
	pose = pose or "run"
	local c = colors or NOOB
	local m = Instance.new("Model")
	m.Name = "Avatar"

	local lean = if pose == "carry" then -0.12 elseif pose == "scared" then -0.25 else -0.18
	local torsoCf = CFrame.new(0, 3, 0) * CFrame.Angles(lean, 0, 0)
	local torso = part(m, "Torso", Vector3.new(2, 2, 1), torsoCf, c.Torso)
	m.PrimaryPart = torso

	-- cabeça com o rosto clássico
	local headTurn = if pose == "scared" then CFrame.Angles(0, math.rad(35), 0) else CFrame.identity
	local head = part(m, "Head", Vector3.new(2, 1, 1), torsoCf * CFrame.new(0, 1.5, 0) * headTurn, c.Head)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head

	local armLen = if pose == "carry" then 3.1 else 2
	local function limb(name: string, side: number, isArm: boolean, ax: number, az: number, color: Color3)
		local pivot = if isArm
			then torsoCf * CFrame.new(1.5 * side, 0.5, 0)
			else torsoCf * CFrame.new(0.5 * side, -1, 0)
		local len = if isArm then armLen else 2
		local drop = if isArm then len / 2 - 0.5 else 1
		local cf = pivot * CFrame.Angles(ax, 0, az * side) * CFrame.new(0, -drop, 0)
		part(m, name, Vector3.new(1, len, 1), cf, color)
	end

	if pose == "carry" then
		-- braços pra cima segurando o ovo
		limb("Right Arm", 1, true, math.rad(172), math.rad(-9), c.Arm)
		limb("Left Arm", -1, true, math.rad(172), math.rad(-9), c.Arm)
		limb("Right Leg", 1, false, math.rad(40), 0, c.Leg)
		limb("Left Leg", -1, false, math.rad(-35), 0, c.Leg)
	elseif pose == "scared" then
		limb("Right Arm", 1, true, math.rad(100), math.rad(25), c.Arm)
		limb("Left Arm", -1, true, math.rad(120), math.rad(30), c.Arm)
		limb("Right Leg", 1, false, math.rad(50), 0, c.Leg)
		limb("Left Leg", -1, false, math.rad(-45), 0, c.Leg)
	elseif pose == "point" then
		limb("Right Arm", 1, true, math.rad(90), math.rad(-10), c.Arm)
		limb("Left Arm", -1, true, math.rad(-20), math.rad(10), c.Arm)
		limb("Right Leg", 1, false, math.rad(10), 0, c.Leg)
		limb("Left Leg", -1, false, math.rad(-10), 0, c.Leg)
	else
		limb("Right Arm", 1, true, math.rad(-60), math.rad(8), c.Arm)
		limb("Left Arm", -1, true, math.rad(65), math.rad(8), c.Arm)
		limb("Right Leg", 1, false, math.rad(45), 0, c.Leg)
		limb("Left Leg", -1, false, math.rad(-45), 0, c.Leg)
	end
	return m
end


--[[
	Avatar R15 de verdade (com cotovelo e joelho), cores de noob.
	Usa Players:CreateHumanoidModelFromDescription e dobra as juntas (Motor6D.C0).
]]
local POSES = {
	carry = {
		Root = { -8, 0, 0 },
		RightShoulder = { 165, 0, -10 }, LeftShoulder = { 165, 0, 10 },
		RightElbow = { 25, 0, 0 }, LeftElbow = { 25, 0, 0 },
		RightHip = { 35, 0, 0 }, LeftHip = { -30, 0, 0 },
		RightKnee = { -45, 0, 0 }, LeftKnee = { -15, 0, 0 },
		Neck = { 8, 0, 0 },
	},
	run = {
		Root = { -14, 0, 0 },
		RightShoulder = { -55, 0, 0 }, LeftShoulder = { 60, 0, 0 },
		RightElbow = { 70, 0, 0 }, LeftElbow = { 70, 0, 0 },
		RightHip = { 50, 0, 0 }, LeftHip = { -40, 0, 0 },
		RightKnee = { -70, 0, 0 }, LeftKnee = { -20, 0, 0 },
	},
	scared = {
		Root = { -18, 0, 0 },
		RightShoulder = { 120, 0, -40 }, LeftShoulder = { 140, 0, 40 },
		RightElbow = { 20, 0, 0 }, LeftElbow = { 20, 0, 0 },
		RightHip = { 55, 0, 0 }, LeftHip = { -45, 0, 0 },
		RightKnee = { -75, 0, 0 }, LeftKnee = { -25, 0, 0 },
		Neck = { 0, 40, 0 },
	},
}

function T.Avatar15(pose: string?, parent: Instance?): Model?
	local Players = game:GetService("Players")
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = NOOB.Head
	desc.LeftArmColor = NOOB.Arm
	desc.RightArmColor = NOOB.Arm
	desc.TorsoColor = NOOB.Torso
	desc.LeftLegColor = NOOB.Leg
	desc.RightLegColor = NOOB.Leg
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig then
		warn("ThumbStudio: não deu pra criar R15", rig)
		return nil
	end
	rig.Name = "Avatar"
	rig.Parent = parent or folder()
	local hum = rig:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.NameDisplayDistance = 0
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	local headPart = rig:FindFirstChild("Head")
	if headPart then
		for _, d in headPart:GetChildren() do
			if d:IsA("Decal") or d:IsA("FaceControls") then
				d:Destroy()
			end
		end
		if headPart:IsA("MeshPart") then
			pcall(function()
				(headPart :: any).TextureID = ""
			end)
		end
		local face = Instance.new("Decal")
		face.Name = "face"
		face.Face = Enum.NormalId.Front
		face.Texture = "rbxasset://textures/face.png"
		face.Parent = headPart
	end
	local p = POSES[pose or "run"] or POSES.run
	local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart

	-- juntas: Motor6D (antigo) ou AnimationConstraint (novo) -> {parte0, parte1, cf0, cf1, nome}
	local joints = {}
	for _, d in rig:GetDescendants() do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 then
			table.insert(joints, { d.Part0, d.Part1, d.C0, d.C1, d.Name })
		elseif d:IsA("AnimationConstraint") and d.Attachment0 and d.Attachment1 then
			local a0, a1 = d.Attachment0 :: Attachment, d.Attachment1 :: Attachment
			table.insert(joints, { a0.Parent, a1.Parent, a0.CFrame, a1.CFrame, d.Name })
		end
	end
	local placed = { [root] = root.CFrame }
	for _ = 1, 20 do
		local changed = false
		for _, j in joints do
			local p0, p1, c0, c1, name = j[1], j[2], j[3], j[4], j[5]
			if placed[p0] and not placed[p1] then
				local a = p[name]
				local rot = if a then CFrame.Angles(math.rad(a[1]), math.rad(a[2]), math.rad(a[3])) else CFrame.identity
				placed[p1] = placed[p0] * c0 * rot * c1:Inverse()
				changed = true
			end
		end
		if not changed then
			break
		end
	end
	-- tira as juntas e ancora tudo no lugar calculado
	for _, d in rig:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("Constraint") then
			d:Destroy()
		end
	end
	for part, cf in placed do
		part.CFrame = cf
	end
	for _, d in rig:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	root.Transparency = 1
	-- cabeça clássica (a cabeça nova distorce o rosto)
	local oldHead = rig:FindFirstChild("Head") :: BasePart?
	if oldHead then
		local h = part(rig, "ClassicHead", Vector3.new(2, 1, 1), oldHead.CFrame, NOOB.Head)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Head
		mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
		mesh.Parent = h
		local face = Instance.new("Decal")
		face.Name = "face"
		face.Texture = "rbxasset://textures/face.png"
		face.Parent = h
		oldHead.Transparency = 1
		for _, d in oldHead:GetChildren() do
			if d:IsA("Decal") then
				d:Destroy()
			end
		end
		h.Name = "Head"
		oldHead.Name = "OldHead"
	end
	return rig
end

local function zoneById(id: string): any
	for _, z in Config.Zones do
		if z.Id == id then
			return z
		end
	end
	return Config.Zones[1]
end

local GOLD = { Style = "spotted", Color = Color3.fromRGB(255, 200, 40), Accent = Color3.fromRGB(255, 255, 255) }

function T.Egg(kind: string?, size: number?): Model
	local look = GOLD
	if kind and kind ~= "gold" then
		look = zoneById(kind).Egg
	end
	local model = Builder.BuildEgg({ Name = "Egg", Size = size or 6, Style = look.Style, Color = look.Color, Accent = look.Accent })
	return model
end

function T.Critter(id: string, height: number): Model?
	local model = Models3D.Get(id, { Size = height, Fit = "Height" })
	if model then
		return model
	end
	for _, def in require(Shared.Critters).List do
		if def.Id == id then
			local m = Builder.Build(def)
			m:ScaleTo(height / 4)
			return m
		end
	end
	return nil
end

local function bottomAt(model: Model, cf: CFrame)
	model:PivotTo(cf)
	local bcf, size = model:GetBoundingBox()
	local bottom = bcf.Position.Y - size.Y / 2
	model:PivotTo(CFrame.new(0, cf.Position.Y - bottom, 0) * cf)
end

-- Põe a câmera de frente pro conjunto, com fundo verde atrás.
-- yaw: de que lado a câmera olha (graus); pitch: de cima (graus, positivo = de cima)
local function frame(f: Model, yaw: number, pitch: number, fov: number?, screen: Color3?)
	local cf, size = f:GetBoundingBox()
	local center = cf.Position
	local radius = size.Magnitude / 2
	fov = fov or 30
	local cam0 = workspace.CurrentCamera
	local aspect = cam0.ViewportSize.X / math.max(cam0.ViewportSize.Y, 1)
	local half = math.max(size.Y / 2, math.max(size.X, size.Z) / 2 / aspect) * 1.06
	local dist = half / math.tan(math.rad(fov) / 2) + math.max(size.X, size.Z) / 2
	local dir = (CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(math.rad(-pitch), 0, 0)).LookVector
	local camPos = center - dir * dist
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = fov
	cam.CFrame = CFrame.lookAt(camPos, center)

	-- fundo verde bem atrás e bem grande
	local back = part(f, "Backdrop", Vector3.new(4000, 4000, 1), CFrame.lookAt(center + dir * (radius * 6 + 50), camPos), screen or GREEN, Enum.Material.Neon)
	back.CastShadow = false
end

--[[
	Cenas:
	  hero_<ovo>      noob correndo com o ovo na cabeça (ovo: gold, forest, cosmic, cherry, volcano...)
	  scared          noob fugindo, olhando pra trás
	  point           noob apontando
	  guardian_<id>   guardião (chirpy, heartcorn, cosmodragon, volcanoram, megamech...)
	  critter_<id>    qualquer bicho de frente
	  egg_<ovo>       ovo sozinho
	Opções: yaw (lado da câmera), pitch, height
]]
function T.Shot(name: string, opts: any?)
	if not RunService:IsStudio() then
		return
	end
	opts = opts or {}
	T.Clear()
	local f = folder()
	local base = CFrame.new(ORIGIN)
	local yaw = opts.yaw or 0
	local pitch = opts.pitch or 6

	local kind, arg = string.match(name, "^(%a+)_?(.*)$")
	if kind == "hero" then
		local av = (opts.r6 and T.Avatar("carry", opts.colors)) or T.Avatar15("carry", f) or T.Avatar("carry", opts.colors)
		av.Parent = f
		bottomAt(av, base)
		local egg = T.Egg(arg ~= "" and arg or "gold", opts.eggSize or 5)
		egg.Parent = f
		local head = av:FindFirstChild("Head") :: BasePart
		local torso = (av:FindFirstChild("Torso") or av:FindFirstChild("UpperTorso")) :: BasePart
		local rh = av:FindFirstChild("RightHand") :: BasePart?
		local lh = av:FindFirstChild("LeftHand") :: BasePart?
		local spot, wantBottom
		if rh and lh then
			-- R15: ovo apoiado entre as mãos
			local mid = (rh.Position + lh.Position) / 2
			spot = mid + torso.CFrame.LookVector * -(opts.eggBack or 0.1)
			wantBottom = mid.Y + (opts.eggLift or -0.35)
		else
			-- R6: ovo um pouco atrás da cabeça (pra mostrar o rosto) e apoiado nas mãos
			spot = head.Position + torso.CFrame.LookVector * -(opts.eggBack or 0.25)
			wantBottom = head.Position.Y + (opts.eggLift or 1.0)
		end
		egg:PivotTo(CFrame.new(spot) * CFrame.Angles(0, math.rad(25), math.rad(-8)))
		local ecf, es = egg:GetBoundingBox()
		egg:PivotTo(egg:GetPivot() + Vector3.new(spot.X - ecf.Position.X, wantBottom - (ecf.Position.Y - es.Y / 2), spot.Z - ecf.Position.Z))
		yaw = opts.yaw or 215
		pitch = opts.pitch or -3
	elseif kind == "scared" or kind == "point" or kind == "run" then
		local av = (opts.r6 and T.Avatar(kind, opts.colors)) or T.Avatar15(kind, f) or T.Avatar(kind, opts.colors)
		av.Parent = f
		bottomAt(av, base)
		yaw = opts.yaw or 200
	elseif kind == "guardian" or kind == "critter" then
		local h = opts.height or (if kind == "guardian" then 30 else 8)
		local m = T.Critter(arg, h)
		if not m then
			warn("ThumbStudio: bicho não encontrado", arg)
			return
		end
		m.Parent = f
		bottomAt(m, base)
		yaw = opts.yaw or (if kind == "guardian" then 160 else 180)
	elseif kind == "egg" then
		local e = T.Egg(arg ~= "" and arg or "gold", opts.eggSize or 6)
		e.Parent = f
		bottomAt(e, base * CFrame.Angles(0, 0, math.rad(opts.tilt or -10)))
		yaw = opts.yaw or 180
	else
		warn("ThumbStudio: cena desconhecida", name)
		return
	end
	local screen = opts.screen
	if screen == nil and (kind == "hero" or kind == "scared" or kind == "point" or kind == "run") then
		screen = Color3.fromRGB(255, 0, 255)
	end
	frame(f, yaw, pitch, opts.fov, screen)
	-- tira a seleção pra não aparecer contorno azul
	pcall(function()
		game:GetService("Selection"):Set({})
	end)
end

-- Mostra várias cenas uma depois da outra (pra gravar com o capseq.ps1)
-- list = { {"hero_gold", {yaw=215}}, "guardian_heartcorn", ... }
function T.Sequence(list: { any }, hold: number?)
	hold = hold or 4
	task.spawn(function()
		for i, item in list do
			local name, opts = item, nil
			if typeof(item) == "table" then
				name, opts = item[1], item[2]
			end
			print(("ThumbStudio %d/%d %s 3D=%s"):format(i, #list, name, tostring(Models3D.Has(string.match(name, "_(.*)$") or ""))))
			T.Shot(name, opts)
			task.wait(hold)
		end
		T.Clear()
		print("ThumbStudio fim")
	end)
end

return T
