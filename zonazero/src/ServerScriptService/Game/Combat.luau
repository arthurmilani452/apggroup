--[[
	Combat: armas (Tools), tiros, dano, escudo, recarga e curas. TUDO é decidido no servidor:
	o jogador só manda "atirei mirando aqui"; o servidor confere a arma, a munição, a cadência,
	faz o próprio raycast a partir da cabeça do personagem e aplica o dano.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local WeaponBuilder = require(ReplicatedStorage.Shared.WeaponBuilder)
local Registry = require(script.Parent.Registry)

local Combat = {}

local lastShot: { [any]: number } = {}
local reloading: { [Player]: boolean } = {}
local lastAttacker: { [Humanoid]: { Entry: any, Time: number } } = {}

local rng = Random.new()

local function rarityMultiplier(rarity: string?): number
	for _, r in Config.Rarities do
		if r.Id == rarity then
			return r.Damage
		end
	end
	return 1
end

local function broadcast(kind: string, data: any)
	Registry.Remotes.Effect:FireAllClients(kind, data)
end

local function finite(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 and math.abs(v.Z) < 1e6
end

-- Direção com imprecisão aleatória dentro de um cone (graus)
local function spreadDirection(direction: Vector3, degrees: number): Vector3
	if degrees <= 0 then
		return direction
	end
	local angle = math.rad(degrees) * math.sqrt(rng:NextNumber())
	local spin = rng:NextNumber() * math.pi * 2
	local cf = CFrame.lookAt(Vector3.zero, direction)
	return (cf * CFrame.Angles(0, 0, spin) * CFrame.Angles(angle, 0, 0)).LookVector
end

---------------------------------------------------------------------
-- Ferramentas (o que vai para a mochila do jogador)
---------------------------------------------------------------------
function Combat.MakeWeaponTool(id: string, rarity: string, mag: number?): Tool
	local def = Config.Weapons[id]
	local tool = Instance.new("Tool")
	tool.Name = id
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = id .. " (" .. rarity .. ")"
	tool:SetAttribute("WeaponId", id)
	tool:SetAttribute("Rarity", rarity)
	tool:SetAttribute("Mag", math.clamp(mag or def.Mag, 0, def.Mag))
	local model = WeaponBuilder.Weapon(id, rarity)
	for _, child in model:GetChildren() do
		child.Parent = tool
	end
	model:Destroy()
	tool.Grip = CFrame.new(0, -0.1, 0.15)
	return tool
end

function Combat.MakeItemTool(id: string, count: number): Tool
	local tool = Instance.new("Tool")
	tool.Name = id
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("ItemId", id)
	tool:SetAttribute("Count", count)
	local model = WeaponBuilder.Item(id)
	for _, child in model:GetChildren() do
		child.Parent = tool
	end
	model:Destroy()
	tool.Activated:Connect(function()
		local player = Players:GetPlayerFromCharacter(tool.Parent)
		if player then
			Combat.UseItem(player, tool)
		end
	end)
	return tool
end

function Combat.PlayerTools(player: Player): { Tool }
	local list = {}
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") then
					table.insert(list, child)
				end
			end
		end
	end
	return list
end

function Combat.WeaponCount(player: Player): number
	local n = 0
	for _, tool in Combat.PlayerTools(player) do
		if tool:GetAttribute("WeaponId") then
			n += 1
		end
	end
	return n
end

-- Junta a cura com uma que o jogador já tem (pilha) ou cria uma nova
function Combat.GiveItem(player: Player, id: string, count: number)
	for _, tool in Combat.PlayerTools(player) do
		if tool:GetAttribute("ItemId") == id then
			tool:SetAttribute("Count", (tool:GetAttribute("Count") or 0) + count)
			return
		end
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		Combat.MakeItemTool(id, count).Parent = backpack
	end
end

function Combat.AddAmmo(player: Player, ammoType: string, amount: number): number
	local info = Config.AmmoTypes[ammoType]
	if not info then
		return 0
	end
	local key = "Ammo_" .. ammoType
	local current = player:GetAttribute(key) or 0
	local added = math.max(0, math.min(amount, info.Max - current))
	player:SetAttribute(key, current + added)
	return added
end

function Combat.ResetPlayer(player: Player)
	for ammoType in Config.AmmoTypes do
		player:SetAttribute("Ammo_" .. ammoType, 0)
	end
	reloading[player] = nil
	player:SetAttribute("Using", nil)
end

---------------------------------------------------------------------
-- Dano
---------------------------------------------------------------------
function Combat.LastAttacker(humanoid: Humanoid): any
	local info = lastAttacker[humanoid]
	if info and os.clock() - info.Time < 30 then
		return info.Entry
	end
	return nil
end

-- Aplica dano: primeiro no escudo (atributo "Shield" do personagem), depois na vida
function Combat.Damage(victim: any, amount: number, attacker: any?, ignoreShield: boolean?)
	local humanoid: Humanoid = victim.Humanoid
	if not humanoid or humanoid.Health <= 0 or amount <= 0 then
		return
	end
	local model = victim.Model
	if not ignoreShield then
		local shield = model:GetAttribute("Shield") or 0
		if shield > 0 then
			local absorbed = math.min(shield, amount)
			model:SetAttribute("Shield", shield - absorbed)
			amount -= absorbed
		end
	end
	if attacker then
		lastAttacker[humanoid] = { Entry = attacker, Time = os.clock() }
	end
	if amount > 0 then
		humanoid.Health = math.max(0, humanoid.Health - amount)
	end
	-- usar uma cura é cancelado ao levar dano de outro jogador
	if attacker and victim.Player then
		victim.Player:SetAttribute("Using", nil)
	end
end

--[[ Dispara a arma de "shooter" (entrada da partida: jogador ou bot).
	origin = de onde sai o raio (cabeça); aimPoint = para onde mirou; extraSpread = erro extra (bots). ]]
function Combat.Shoot(shooter: any, origin: Vector3, aimPoint: Vector3, weaponId: string, rarity: string?, aiming: boolean, muzzle: Vector3, extraSpread: number?)
	local def = Config.Weapons[weaponId]
	if not def then
		return
	end
	local Match = Registry.Match
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { shooter.Model }
	local loot = workspace:FindFirstChild("Loot")
	if loot then
		table.insert(exclude, loot)
	end
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true

	local baseDir = aimPoint - origin
	if baseDir.Magnitude < 0.01 then
		return
	end
	baseDir = baseDir.Unit
	local spread = def.Spread * (if aiming then def.AimSpread else 1) + (extraSpread or 0)
	local damageBy: { [any]: { Amount: number, Head: boolean } } = {}
	local ends = {}
	for _ = 1, def.Pellets do
		local dir = spreadDirection(baseDir, spread)
		local result = workspace:Raycast(origin, dir * def.Range, params)
		local hitPos = if result then result.Position else origin + dir * def.Range
		table.insert(ends, hitPos)
		if result then
			local model = result.Instance:FindFirstAncestorOfClass("Model")
			local victim = model and Match.EntryFromModel(model)
			if victim and victim ~= shooter and victim.Alive then
				local distance = (hitPos - origin).Magnitude
				local falloff = if distance <= def.Falloff then 1 else math.max(0.6, 1 - (distance - def.Falloff) / math.max(def.Range - def.Falloff, 1) * 0.4)
				local head = result.Instance.Name == "Head"
				local amount = def.Damage * rarityMultiplier(rarity) * falloff * (if head then def.Headshot else 1)
				local acc = damageBy[victim] or { Amount = 0, Head = false }
				acc.Amount += amount
				acc.Head = acc.Head or head
				damageBy[victim] = acc
			end
		end
	end
	-- efeito do tiro para todos (o próprio atirador já desenhou o dele na hora)
	broadcast("Shot", { From = muzzle, Ends = ends, W = weaponId, S = if shooter.Player then shooter.Player.UserId else 0 })
	for victim, acc in damageBy do
		local before = victim.Humanoid.Health
		Combat.Damage(victim, acc.Amount, shooter)
		local killed = before > 0 and victim.Humanoid.Health <= 0
		if shooter.Player then
			Registry.Remotes.Effect:FireClient(shooter.Player, "Hit", { Head = acc.Head, Kill = killed, Damage = math.floor(acc.Amount + 0.5) })
		end
		if victim.Player then
			Registry.Remotes.Effect:FireClient(victim.Player, "Damaged", { From = origin })
		end
	end
end

---------------------------------------------------------------------
-- Recarregar
---------------------------------------------------------------------
function Combat.Reload(player: Player)
	if reloading[player] then
		return
	end
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	local id = tool and tool:GetAttribute("WeaponId")
	local def = id and Config.Weapons[id]
	if not tool or not def then
		return
	end
	local mag = tool:GetAttribute("Mag") or 0
	local key = "Ammo_" .. def.Ammo
	if mag >= def.Mag or (player:GetAttribute(key) or 0) <= 0 then
		return
	end
	reloading[player] = true
	tool:SetAttribute("Reloading", true)
	task.delay(def.Reload, function()
		reloading[player] = nil
		if tool.Parent then
			tool:SetAttribute("Reloading", nil)
		end
		-- trocou de arma ou morreu no meio: cancela
		if not player.Parent or tool.Parent ~= player.Character then
			return
		end
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end
		local current = tool:GetAttribute("Mag") or 0
		local reserve = player:GetAttribute(key) or 0
		local take = math.min(def.Mag - current, reserve)
		tool:SetAttribute("Mag", current + take)
		player:SetAttribute(key, reserve - take)
	end)
end

---------------------------------------------------------------------
-- Curas
---------------------------------------------------------------------
function Combat.UseItem(player: Player, tool: Tool)
	local id = tool:GetAttribute("ItemId")
	local def = id and Config.Items[id]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not def or not humanoid or humanoid.Health <= 0 or player:GetAttribute("Using") then
		return
	end
	local entry = Registry.Match.EntryFor(player)
	if not entry or not entry.Alive then
		return
	end
	if def.Heal and humanoid.Health >= def.MaxHeal then
		Registry.Remotes.NotifyPlayer(player, "HEALTH_FULL")
		return
	end
	if def.Shield and (character:GetAttribute("Shield") or 0) >= Config.Player.MaxShield then
		Registry.Remotes.NotifyPlayer(player, "SHIELD_FULL")
		return
	end
	player:SetAttribute("Using", id)
	player:SetAttribute("UseEnds", workspace:GetServerTimeNow() + def.UseTime)
	local started = os.clock()
	while os.clock() - started < def.UseTime do
		task.wait(0.1)
		-- cancelou (guardou a cura, levou tiro, morreu)
		if player:GetAttribute("Using") ~= id or tool.Parent ~= player.Character or humanoid.Health <= 0 then
			if player:GetAttribute("Using") == id then
				player:SetAttribute("Using", nil)
			end
			return
		end
	end
	if player:GetAttribute("Using") ~= id then
		return
	end
	player:SetAttribute("Using", nil)
	if def.Heal then
		humanoid.Health = math.max(humanoid.Health, math.min(def.MaxHeal, humanoid.Health + def.Heal))
	end
	if def.Shield then
		character:SetAttribute("Shield", math.min(Config.Player.MaxShield, (character:GetAttribute("Shield") or 0) + def.Shield))
	end
	local count = (tool:GetAttribute("Count") or 1) - 1
	if count <= 0 then
		tool:Destroy()
	else
		tool:SetAttribute("Count", count)
	end
end

---------------------------------------------------------------------
function Combat.Init()
	local Remotes = Registry.Remotes
	Remotes.Fire.OnServerEvent:Connect(function(player: Player, aimPoint: any, aiming: any)
		if typeof(aimPoint) ~= "Vector3" or not finite(aimPoint) then
			return
		end
		local entry = Registry.Match.EntryFor(player)
		local character = player.Character
		local tool = character and character:FindFirstChildOfClass("Tool")
		local id = tool and tool:GetAttribute("WeaponId")
		local def = id and Config.Weapons[id]
		local head = character and character:FindFirstChild("Head") :: BasePart?
		if not entry or not entry.Alive or not def or not head or reloading[player] or player:GetAttribute("Using") then
			return
		end
		local now = os.clock()
		if now - (lastShot[player] or 0) < 60 / def.Rpm * 0.85 then
			return -- mais rápido que a arma permite
		end
		local mag = tool:GetAttribute("Mag") or 0
		if mag <= 0 then
			return
		end
		lastShot[player] = now
		tool:SetAttribute("Mag", mag - 1)
		local handle = tool:FindFirstChild("Handle") :: BasePart?
		local muzzleAtt = handle and handle:FindFirstChild("Muzzle") :: Attachment?
		local muzzle = if muzzleAtt then muzzleAtt.WorldPosition else head.Position
		Combat.Shoot(entry, head.Position, aimPoint, id, tool:GetAttribute("Rarity"), aiming == true, muzzle)
	end)
	Remotes.Reload.OnServerEvent:Connect(function(player: Player)
		Combat.Reload(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastShot[player] = nil
		reloading[player] = nil
	end)
	-- limpa o "último atacante" de quem já não existe
	task.spawn(function()
		while true do
			task.wait(30)
			for humanoid in lastAttacker do
				if not humanoid.Parent then
					lastAttacker[humanoid] = nil
				end
			end
		end
	end)
end

return Combat
