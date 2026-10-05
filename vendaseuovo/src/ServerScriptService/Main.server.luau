--[[
	VENDA SEU OVO - script principal do servidor (Script "Main" em ServerScriptService).
	Liga os módulos da pasta "Game" e cuida da entrada/saída dos jogadores.
	Pra ajustar o jogo, mexa em ReplicatedStorage > Shared > Config.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Models = require(ReplicatedStorage.Shared.Models)
local GameFolder = script.Parent:WaitForChild("Game")
local Registry = require(GameFolder.Registry)

Registry.Remotes = require(GameFolder.Remotes)
Registry.Data = require(GameFolder.Data)
Registry.Economy = require(GameFolder.Economy)
Registry.Stands = require(GameFolder.Stands)
Registry.Farm = require(GameFolder.Farm)
Registry.Steal = require(GameFolder.Steal)
Registry.Shop = require(GameFolder.Shop)
Registry.Customers = require(GameFolder.Customers)

-- Cada sistema liga sozinho; se um der erro, os outros continuam
for _, name in { "Economy", "Stands", "Farm", "Steal", "Shop", "Customers" } do
	local ok, err = pcall(Registry[name].Init)
	if not ok then
		warn("[Main] " .. name .. ".Init falhou:", err)
	end
end

-- Cenário em 3D (barraca, ninho, fogão, fonte, granja), se os modelos foram importados
local okProps, errProps = pcall(Models.ApplyProps, workspace)
if not okProps then
	warn("[Main] modelos 3D do cenário:", errProps)
end

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.WalkSpeed = Config.WalkSpeed
	-- clientes NPC não esbarram nos jogadores (não dá para bloquear a fila nem o ladrão)
	local function setGroup(part: Instance)
		if part:IsA("BasePart") then
			part.CollisionGroup = "Players"
		end
	end
	for _, d in character:GetDescendants() do
		setGroup(d)
	end
	character.DescendantAdded:Connect(setGroup)
	-- nasce dentro da própria barraca
	local stand = Registry.Stands.Of(player)
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if stand and root then
		task.defer(function()
			character:PivotTo(Registry.Stands.SpawnCFrame(stand))
		end)
	end
end

local function onPlayerAdded(player: Player)
	Registry.Economy.SetupPlayer(player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)

	local profile = Registry.Data.Load(player)
	if not player.Parent then
		if profile.CanSave then
			Registry.Data.Save(player, true)
		end
		Registry.Data.Remove(player)
		return
	end
	if not profile.CanSave and not RunService:IsStudio() then
		player:Kick("Couldn't load your save (Roblox servers are busy). Your progress is safe - please rejoin!")
		return
	end
	player:SetAttribute("Loaded", true)
	local stand = Registry.Stands.Assign(player)
	if not stand then
		player:Kick("This market is full. Please join another server!")
		return
	end
	if profile.Data.Tutorial == 0 then
		Registry.Economy.Log(player, "FirstJoin")
	end
	Registry.Economy.Push(player)
	player:LoadCharacter()
end

local function onPlayerRemoving(player: Player)
	pcall(Registry.Steal.OnPlayerRemoving, player) -- antes do save: devolve o que estava sendo roubado
	pcall(Registry.Stands.Release, player)
	Registry.Remotes.RemovePlayer(player)
	Registry.Data.Save(player, true)
	Registry.Data.Remove(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- Salva todo mundo de tempos em tempos
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in Players:GetPlayers() do
			task.spawn(Registry.Data.Save, player)
		end
	end
end)

-- Salva quando o servidor fecha
game:BindToClose(function()
	local pending = 0
	for _, player in Players:GetPlayers() do
		pending += 1
		task.spawn(function()
			pcall(Registry.Steal.OnPlayerRemoving, player)
			Registry.Data.Save(player, true)
			pending -= 1
		end)
	end
	local started = os.clock()
	while (pending > 0 or Registry.Data.ActiveSaves() > 0) and os.clock() - started < 25 do
		task.wait(0.1)
	end
end)
