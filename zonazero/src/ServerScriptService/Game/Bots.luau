--[[
	Bots: completam a partida quando tem pouca gente online (Config.Match.FillWithBots).
	Cada bot é um avatar R15 padrão do Roblox com uma arma, que:
	  • anda pelo mapa (PathfindingService) e fica dentro da próxima zona
	  • quando vê alguém (linha de visão), espera um tempo de reação e atira em rajadas, errando um pouco
	Os tiros usam o mesmo Combat.Shoot dos jogadores (mesmo dano, mesmas regras).
]]

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local WeaponBuilder = require(ReplicatedStorage.Shared.WeaponBuilder)
local ZoneMath = require(ReplicatedStorage.Shared.ZoneMath)
local Registry = require(script.Parent.Registry)

local Bots = {}

local rng = Random.new()
local folder: Folder
local SKIN = {
	Color3.fromRGB(255, 205, 170), Color3.fromRGB(234, 184, 146), Color3.fromRGB(198, 140, 100),
	Color3.fromRGB(160, 105, 70), Color3.fromRGB(110, 70, 45),
}
local SHIRT = {
	Color3.fromRGB(70, 80, 60), Color3.fromRGB(40, 45, 55), Color3.fromRGB(120, 90, 60),
	Color3.fromRGB(90, 30, 30), Color3.fromRGB(30, 60, 90), Color3.fromRGB(60, 60, 60),
}

local function between(range: { number }): number
	return rng:NextNumber(range[1], range[2])
end

-- Avatar R15 padrão; se o Roblox não deixar criar, monta um boneco simples de peças
local function buildBody(name: string): Model
	local skin = SKIN[rng:NextInteger(1, #SKIN)]
	local shirt = SHIRT[rng:NextInteger(1, #SHIRT)]
	local pants = SHIRT[rng:NextInteger(1, #SHIRT)]
	local ok, model = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		desc.HeadColor = skin
		desc.LeftArmColor = skin
		desc.RightArmColor = skin
		desc.TorsoColor = shirt
		desc.LeftLegColor = pants
		desc.RightLegColor = pants
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if ok and model then
		model.Name = name
		local animate = model:FindFirstChild("Animate")
		if animate then
			animate:Destroy() -- o Animate é para jogadores; os bots tocam as animações pelo servidor
		end
		return model
	end
	-- plano B: boneco de peças (sem animação)
	local rig = Instance.new("Model")
	rig.Name = name
	local function p(partName, size, offset, color)
		local part = Instance.new("Part")
		part.Name = partName
		part.Size = size
		part.Color = color
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CFrame = CFrame.new(offset)
		part.Parent = rig
		return part
	end
	local root = p("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), shirt)
	root.Transparency = 1
	local parts = {
		p("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), shirt),
		p("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 4.6, 0), skin),
		p("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 3, 0), skin),
		p("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 3, 0), skin),
		p("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, 1, 0), pants),
		p("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, 1, 0), pants),
	}
	for _, part in parts do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 0
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.RequiresNeck = false
	humanoid.Parent = rig
	rig.PrimaryPart = root
	return rig
end

local function attachWeapon(entry: any)
	local model = entry.Model
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local weapon, handle, muzzle = WeaponBuilder.Weapon(entry.Weapon, entry.Rarity)
	weapon:PivotTo(root.CFrame * CFrame.new(0.9, 0.5, -1.1))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = handle
	weld.Parent = handle
	weapon.Parent = model
	entry.Muzzle = muzzle
	-- braço direito levantado segurando a arma
	local upper = model:FindFirstChild("RightUpperArm")
	local shoulder = upper and upper:FindFirstChild("RightShoulder")
	if shoulder and shoulder:IsA("Motor6D") then
		shoulder.C0 = shoulder.C0 * CFrame.Angles(math.rad(80), 0, 0)
	end
end

-- Um ponto no chão perto do centro (usa os LootSpots do mapa, que estão sempre no chão)
function Bots.GroundPoint(center: Vector3): Vector3
	local map = workspace:FindFirstChild("Map")
	local spots = map and map:FindFirstChild("LootSpots")
	local list = {}
	if spots then
		for _, spot in spots:GetChildren() do
			if spot:IsA("BasePart") then
				local dx, dz = spot.Position.X - center.X, spot.Position.Z - center.Z
				if dx * dx + dz * dz < (Config.Zone.StartRadius * 0.8) ^ 2 then
					table.insert(list, spot.Position)
				end
			end
		end
	end
	if #list > 0 then
		return list[rng:NextInteger(1, #list)] + Vector3.new(rng:NextNumber(-4, 4), 4, rng:NextNumber(-4, 4))
	end
	return center + Vector3.new(rng:NextNumber(-200, 200), 6, rng:NextNumber(-200, 200))
end

---------------------------------------------------------------------
-- Inteligência
---------------------------------------------------------------------
local function headOf(model: Model): BasePart?
	return model:FindFirstChild("Head") :: BasePart?
end

local function canSee(entry: any, target: any): boolean
	local myHead, theirHead = headOf(entry.Model), headOf(target.Model)
	if not myHead or not theirHead then
		return false
	end
	local delta = theirHead.Position - myHead.Position
	if delta.Magnitude > Config.Bots.SightRange then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { entry.Model }
	local loot = workspace:FindFirstChild("Loot")
	if loot then
		table.insert(exclude, loot)
	end
	params.FilterDescendantsInstances = exclude
	local result = workspace:Raycast(myHead.Position, delta, params)
	return result ~= nil and result.Instance:IsDescendantOf(target.Model)
end

local function findTarget(entry: any): any
	local best, bestDist = nil, math.huge
	local myRoot = entry.Model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not myRoot then
		return nil
	end
	for _, other in Registry.Match.AliveEntries() do
		if other ~= entry and other.Model then
			local root = other.Model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local dist = (root.Position - myRoot.Position).Magnitude
				if dist < bestDist and dist <= Config.Bots.SightRange and canSee(entry, other) then
					best, bestDist = other, dist
				end
			end
		end
	end
	return best
end

-- Escolhe um destino dentro da próxima zona
local function wanderPoint(): Vector3
	local cx, cz, r = ZoneMath.Next()
	if (workspace:GetAttribute("ZoneStage") or 0) <= 0 or r <= 0 then
		cx, cz, r = 0, 0, Config.Zone.StartRadius
	end
	local angle = rng:NextNumber() * math.pi * 2
	local dist = math.sqrt(rng:NextNumber()) * math.max(r * 0.7, 4)
	return Vector3.new(cx + math.cos(angle) * dist, 0, cz + math.sin(angle) * dist)
end

local function computePath(from: Vector3, to: Vector3): { PathWaypoint }?
	local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 8 })
	local ok = pcall(function()
		path:ComputeAsync(from, to)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		return path:GetWaypoints()
	end
	return nil
end

local function run(entry: any)
	local model = entry.Model
	local humanoid = entry.Humanoid :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local def = Config.Weapons[entry.Weapon]
	local waypoints: { PathWaypoint }? = nil
	local wpIndex = 1
	local lastPos = root.Position
	local lastMoveCheck = os.clock()
	local target, seenAt = nil, 0
	local nextShot, burstLeft = 0, 0

	-- animações
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local tracks = {}
	for key, id in Config.BotAnimations do
		local ok, track = pcall(function()
			local anim = Instance.new("Animation")
			anim.AnimationId = id
			return animator:LoadAnimation(anim)
		end)
		if ok and track then
			tracks[key] = track
		end
	end
	local playing = nil
	local function play(key: string)
		if playing == key then
			return
		end
		if playing and tracks[playing] then
			tracks[playing]:Stop(0.2)
		end
		playing = key
		if tracks[key] then
			tracks[key]:Play(0.2)
		end
	end

	while entry.Alive and model.Parent and humanoid.Health > 0 do
		task.wait(0.15)
		if Registry.Match.Phase() ~= "Match" then
			humanoid:MoveTo(root.Position)
			play("Idle")
			continue
		end
		local now = os.clock()
		play(if root.AssemblyLinearVelocity.Magnitude > 2 then "Run" else "Idle")

		-- alvo
		if not target or not target.Alive or now - seenAt > 1.2 then
			local found = findTarget(entry)
			if found and found ~= target then
				target = found
				nextShot = now + between(Config.Bots.ReactionTime)
				burstLeft = rng:NextInteger(Config.Bots.BurstShots[1], Config.Bots.BurstShots[2])
			end
			if found then
				seenAt = now
			else
				target = nil
			end
		elseif canSee(entry, target) then
			seenAt = now
		end

		if target and target.Model then
			local targetRoot = target.Model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if targetRoot then
				-- vira para o alvo e anda de lado
				humanoid.AutoRotate = false
				local flat = Vector3.new(targetRoot.Position.X, root.Position.Y, targetRoot.Position.Z)
				root.CFrame = CFrame.lookAt(root.Position, flat)
				local dist = (targetRoot.Position - root.Position).Magnitude
				local side = root.CFrame.RightVector * (if math.floor(now / 1.5) % 2 == 0 then 6 else -6)
				local forward = if dist > def.Falloff then root.CFrame.LookVector * 6 else Vector3.zero
				humanoid:MoveTo(root.Position + side + forward)
				waypoints = nil
				-- atira
				if now >= nextShot then
					local head = headOf(model)
					if head and canSee(entry, target) then
						local aim = targetRoot.Position + Vector3.new(0, rng:NextNumber(-0.5, 1.6), 0)
						Registry.Combat.Shoot(entry, head.Position, aim, entry.Weapon, entry.Rarity, false, if entry.Muzzle then entry.Muzzle.WorldPosition else head.Position, Config.Bots.AccuracyDegrees)
					end
					burstLeft -= 1
					if burstLeft <= 0 then
						burstLeft = rng:NextInteger(Config.Bots.BurstShots[1], Config.Bots.BurstShots[2])
						nextShot = now + between(Config.Bots.BurstPause)
					else
						nextShot = now + math.max(60 / def.Rpm, 0.12)
					end
				end
				continue
			end
		end
		humanoid.AutoRotate = true

		-- andar: segue o caminho até um ponto dentro da próxima zona
		local outsideNext = false
		do
			local cx, cz, r = ZoneMath.Next()
			local dx, dz = root.Position.X - cx, root.Position.Z - cz
			outsideNext = (workspace:GetAttribute("ZoneStage") or 0) > 0 and dx * dx + dz * dz > r * r
		end
		if not waypoints or wpIndex > #waypoints or (outsideNext and rng:NextNumber() < 0.05) then
			local goal = wanderPoint()
			waypoints = computePath(root.Position, Vector3.new(goal.X, root.Position.Y, goal.Z))
			wpIndex = 2
			if not waypoints then
				humanoid:MoveTo(Vector3.new(goal.X, root.Position.Y, goal.Z))
				waypoints = {}
			end
		end
		if waypoints and waypoints[wpIndex] then
			local wp = waypoints[wpIndex]
			if wp.Action == Enum.PathWaypointAction.Jump then
				humanoid.Jump = true
			end
			humanoid:MoveTo(wp.Position)
			if (Vector3.new(wp.Position.X, 0, wp.Position.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude < 4 then
				wpIndex += 1
			end
		end
		-- travou: pula e escolhe outro caminho
		if now - lastMoveCheck > 2 then
			if (root.Position - lastPos).Magnitude < 1.5 then
				humanoid.Jump = true
				waypoints = nil
			end
			lastPos = root.Position
			lastMoveCheck = now
		end
	end
	play("Idle")
end

function Bots.Spawn(entry: any, position: Vector3)
	local model = buildBody(entry.Name)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayName = entry.Name
	humanoid.MaxHealth = Config.Bots.Health
	humanoid.Health = Config.Bots.Health
	humanoid.WalkSpeed = Config.Bots.WalkSpeed
	humanoid.BreakJointsOnDeath = false
	humanoid.NameDisplayDistance = 60
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	model:SetAttribute("Shield", 0)
	model:SetAttribute("IsBot", true)
	model:PivotTo(CFrame.new(position))
	model.Parent = folder
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	pcall(function()
		root:SetNetworkOwner(nil) -- o servidor controla o bot
	end)
	entry.Model = model
	entry.Humanoid = humanoid
	entry.Weapon = Config.Bots.Weapons[rng:NextInteger(1, #Config.Bots.Weapons)]
	entry.Rarity = Registry.Loot.RandomRarity()
	attachWeapon(entry)
	task.spawn(function()
		local ok, err = pcall(run, entry)
		if not ok then
			warn("[Bots] erro na IA de " .. entry.Name .. ":", err)
		end
	end)
end

-- O que o bot deixa cair ao morrer
function Bots.DropLoot(entry: any, position: Vector3)
	local items = {
		{ Kind = "Weapon", Id = entry.Weapon, Rarity = entry.Rarity },
		{ Kind = "Ammo", Id = Config.Weapons[entry.Weapon].Ammo },
	}
	if rng:NextNumber() < 0.5 then
		table.insert(items, { Kind = "Item", Id = if rng:NextNumber() < 0.5 then "Bandage" else "ShieldCell" })
	end
	Registry.Loot.DropList(items, position)
	-- o corpo some depois de um tempo
	local model = entry.Model
	task.delay(6, function()
		if model and model.Parent then
			model:Destroy()
		end
	end)
end

function Bots.Cleanup()
	for _, child in folder:GetChildren() do
		child:Destroy()
	end
end

function Bots.Init()
	folder = Instance.new("Folder")
	folder.Name = "Bots"
	folder.Parent = workspace
end

return Bots
