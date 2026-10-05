--[[
	VENDA UM OVO - script principal do servidor (Script "Main" em ServerScriptService).
	Liga os módulos da pasta "Game" e cuida da entrada/saída dos jogadores.
	Pra ajustar o jogo, mexa em ReplicatedStorage > Shared > Config.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AssetLib = require(ReplicatedStorage.Shared.AssetLib)
local Config = require(ReplicatedStorage.Shared.Config)
local GameFolder = script.Parent:WaitForChild("Game")
local Registry = require(GameFolder.Registry)

-- Cenário: troca cada objeto pela versão atual de ReplicatedStorage > Assets (arte 3D nova entra aqui)
local okScenery, errScenery = pcall(AssetLib.RefreshScenery, workspace)
if not okScenery then
	warn("[Main] cenário:", errScenery)
end

-- Texturas (Config.Textures): peças com o atributo "Tex" ganham a textura que repete
for _, d in workspace:GetDescendants() do
	local texName = d:IsA("BasePart") and d:GetAttribute("Tex")
	local id = texName and Config.Textures[texName]
	if id and id ~= "" then
		for _, face in { Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
			local texture = Instance.new("Texture")
			texture.Texture = id
			texture.Face = face
			texture.StudsPerTileU = Config.TextureTile
			texture.StudsPerTileV = Config.TextureTile
			texture.Parent = d
		end
	end
end

Registry.Remotes = require(GameFolder.Remotes)
Registry.Data = require(GameFolder.Data)
Registry.Economy = require(GameFolder.Economy)
Registry.Plots = require(GameFolder.Plots)
Registry.Farm = require(GameFolder.Farm)
Registry.Shop = require(GameFolder.Shop)
Registry.Daily = require(GameFolder.Daily)
Registry.Store = require(GameFolder.Store)
Registry.Leaderboard = require(GameFolder.Leaderboard)

-- Cada sistema liga sozinho; se um der erro, os outros continuam
for _, name in { "Economy", "Plots", "Farm", "Shop", "Daily", "Store", "Leaderboard" } do
	local ok, err = pcall(Registry[name].Init)
	if not ok then
		warn("[Main] " .. name .. ".Init falhou:", err)
	end
end

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	Registry.Economy.ApplySpeed(player)
	-- renasce sozinho depois de cair/morrer
	humanoid.Died:Connect(function()
		task.wait(3)
		if player.Parent and player.Character == character then
			player:LoadCharacter()
		end
	end)
	-- nasce dentro da própria granja
	local plot = Registry.Plots.Of(player)
	if plot and character:WaitForChild("HumanoidRootPart", 10) then
		task.defer(function()
			character:PivotTo(Registry.Plots.SpawnCFrame(plot))
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
		player:Kick("Não deu pra carregar seu progresso agora (Roblox ocupado). Ele tá salvo, entra de novo.")
		return
	end
	player:SetAttribute("Loaded", true)
	local plot = Registry.Plots.Assign(player)
	if not plot then
		player:Kick("Servidor cheio. Tenta outro.")
		return
	end
	Registry.Daily.Check(player)
	task.spawn(Registry.Store.CheckPasses, player)
	Registry.Economy.Push(player)
	player:LoadCharacter()
end

local function onPlayerRemoving(player: Player)
	pcall(Registry.Leaderboard.Write, player)
	pcall(Registry.Plots.Release, player)
	Registry.Remotes.RemovePlayer(player)
	Registry.Data.Save(player, true)
	Registry.Data.Remove(player)
end

Players.CharacterAutoLoads = false -- nasce só depois de carregar os dados e ganhar a granja
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
			pcall(Registry.Leaderboard.Write, player)
			Registry.Data.Save(player, true)
			pending -= 1
		end)
	end
	local started = os.clock()
	while (pending > 0 or Registry.Data.ActiveSaves() > 0) and os.clock() - started < 25 do
		task.wait(0.1)
	end
end)
