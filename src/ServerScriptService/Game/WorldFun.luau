--!strict
--[[
	WorldFun (v27): a brincadeira de cada mundo, lado do SERVIDOR.

	• Baús de prêmio (Tag "FunPrize", atributos World e Key) no fim de cada brincadeira:
	  Candy (camas elásticas), Frost (escorregador de gelo), Lava (pular nas pedras),
	  Reef (jatos de bolha) e Galaxy (gravidade baixa). Quem encosta ganha alguns minutos
	  da própria renda e às vezes um ovo daquele mundo. Cada baú volta depois de
	  Config.WorldFun.PrizeCooldown (salvo no perfil: sair e entrar não reseta).
	• Montes de neve (Tag "SnowPile", com ProximityPrompt): joga uma bola de neve para frente.
	  Acertou alguém = "SPLAT" na tela da pessoa. Sem dano e sem empurrão.

	As partes só visuais (camas elásticas, lava que volta para o começo, gravidade baixa)
	ficam no cliente (StarterPlayerScripts > WorldLife): não dão nada, então não precisam do servidor.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Registry = require(script.Parent.Registry)

local WorldFun = {}

local lastNotice: { [Player]: number } = {}
local lastThrow: { [Player]: number } = {}

local function settings()
	return Config.WorldFun
end

local function getData(player: Player)
	local profile = Registry.Data.Get(player)
	return profile and profile.Data
end

local function playerFromPart(hit: BasePart): Player?
	local node: Instance? = hit
	for _ = 1, 3 do
		if not node then
			return nil
		end
		local found = Players:GetPlayerFromCharacter(node)
		if found then
			return found
		end
		node = node.Parent
	end
	return nil
end

-- o ovo mais barato daquele mundo (sem ovos de clima/semana/exploração)
local function cheapestEgg(worldId: string): string?
	local best, bestPrice = nil, math.huge
	for _, egg in Config.EggsOfWorld(worldId) do
		if not egg.Condition and (egg.Weight or 0) > 0 and egg.Price < bestPrice then
			best, bestPrice = egg.Id, egg.Price
		end
	end
	return best
end

local function publish(player: Player)
	local data = getData(player)
	local prizes = data and data.FunPrizes
	if type(prizes) ~= "table" then
		return
	end
	for key, readyAt in prizes do
		if type(key) == "string" and type(readyAt) == "number" then
			player:SetAttribute("Fun_" .. key, readyAt)
		end
	end
end

function WorldFun.Claim(player: Player, prize: BasePart)
	local key = prize:GetAttribute("Key")
	local worldId = prize:GetAttribute("World")
	if typeof(key) ~= "string" or typeof(worldId) ~= "string" or not player:GetAttribute("Loaded") then
		return
	end
	local here = player:GetAttribute("World")
	if (typeof(here) == "string" and here or "meadow") ~= worldId then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - prize.Position).Magnitude > 16 then
		return
	end
	local data = getData(player)
	if not data then
		return
	end
	if type(data.FunPrizes) ~= "table" then
		data.FunPrizes = {}
	end
	local now = os.time()
	local readyAt = tonumber(data.FunPrizes[key]) or 0
	if now < readyAt then
		if os.clock() - (lastNotice[player] or 0) > 4 then
			lastNotice[player] = os.clock()
			Registry.Remotes.Notify(player, ("This treasure is back in %s!"):format(Format.Time(readyAt - now)), "info")
		end
		return
	end
	local cfg = settings()
	data.FunPrizes[key] = now + cfg.PrizeCooldown
	player:SetAttribute("Fun_" .. key, now + cfg.PrizeCooldown)
	local reward: { [string]: any } = { Cash = cfg.PrizeCashMinutes }
	if math.random() < cfg.PrizeEggChance then
		reward.Egg = cheapestEgg(worldId)
	end
	local text = Registry.Retention.Grant(player, reward, cfg.PrizeMinCash, "FunPrize")
	Registry.Remotes.Notify(player, "TREASURE! " .. text, "success")
	Registry.Remotes.Effect(player, "FunPrize", prize.Position)
	local analytics = Registry.Analytics
	if analytics then
		pcall(analytics.Event, player, "FunPrize_" .. key, 1)
	end
end

function WorldFun.Throw(player: Player)
	local cfg = settings()
	local now = os.clock()
	if now - (lastThrow[player] or 0) < cfg.SnowballCooldown then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root then
		return
	end
	lastThrow[player] = now
	local look = root.CFrame.LookVector
	local ball = Instance.new("Part")
	ball.Name = "Snowball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(1.4, 1.4, 1.4)
	ball.Material = Enum.Material.Snow
	ball.Color = Color3.fromRGB(250, 252, 255)
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = true
	ball.Massless = true
	ball.CFrame = CFrame.new(root.Position + look * 3 + Vector3.new(0, 2.5, 0))
	ball.Parent = workspace
	pcall(function()
		ball:SetNetworkOwner(nil)
	end)
	ball.AssemblyLinearVelocity = look * cfg.SnowballSpeed + Vector3.new(0, 26, 0)
	local done = false
	ball.Touched:Connect(function(hit)
		if done or hit:IsDescendantOf(character) or hit.Name == "Snowball" then
			return
		end
		local victim = playerFromPart(hit)
		if victim then
			done = true
			Registry.Remotes.Effect(victim, "Splat")
			Registry.Remotes.Effect(player, "SnowHit", ball.Position)
			ball:Destroy()
		elseif hit.CanCollide then
			done = true
			ball:Destroy()
		end
	end)
	Debris:AddItem(ball, 3)
end

function WorldFun.Init()
	local function setupPrize(prize: Instance)
		if not prize:IsA("BasePart") or prize:GetAttribute("FunReady") then
			return
		end
		prize:SetAttribute("FunReady", true)
		prize.Touched:Connect(function(hit)
			local player = playerFromPart(hit)
			if player then
				WorldFun.Claim(player, prize)
			end
		end)
	end
	local function setupPile(pile: Instance)
		local prompt = pile:FindFirstChildWhichIsA("ProximityPrompt")
		if not prompt or pile:GetAttribute("FunReady") then
			return
		end
		pile:SetAttribute("FunReady", true)
		prompt.Triggered:Connect(function(player)
			WorldFun.Throw(player)
		end)
	end
	for _, prize in CollectionService:GetTagged("FunPrize") do
		setupPrize(prize)
	end
	CollectionService:GetInstanceAddedSignal("FunPrize"):Connect(setupPrize)
	for _, pile in CollectionService:GetTagged("SnowPile") do
		setupPile(pile)
	end
	CollectionService:GetInstanceAddedSignal("SnowPile"):Connect(setupPile)

	-- os relógios dos baús aparecem para o jogador assim que o perfil carrega
	local function watch(player: Player)
		if player:GetAttribute("Loaded") then
			publish(player)
		end
		player:GetAttributeChangedSignal("Loaded"):Connect(function()
			if player:GetAttribute("Loaded") then
				publish(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastNotice[player] = nil
		lastThrow[player] = nil
	end)
end

return WorldFun
