--[[
	Events: CHUVA DE OVOS DOURADOS.
	A cada Config.GoldenRain.Interval, avisa o servidor todo e, por alguns segundos, caem ovos dourados
	em volta do centro da ilha. Quem encostar leva o ovo para a cesta.
	O servidor cria cada ovo e confere quem pegou (dono da cesta, distância, limite por jogador por chuva).
	Atributos para a tela: workspace.GoldenRainStart (aviso: quando começa) e workspace.GoldenRainEnd (quando acaba).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Registry = require(script.Parent.Registry)

local Events = {}

local R = Config.GoldenRain
local alive = 0
local taken: { [Player]: number } = {}
local folder: Folder

-- Ponto aleatório no gramado do centro, fora do celeiro e do silo
local function randomSpot(): Vector3
	for _ = 1, 20 do
		local a = math.random() * math.pi * 2
		local r = math.sqrt(math.random()) * R.Radius
		local x, z = math.cos(a) * r, math.sin(a) * r
		local onBarn = x > -38 and x < 38 and z > -2 and z < 50
		local onCoop = x > -52 and x < -32 and z > 6 and z < 30 -- galinheiro do lado do celeiro
		if not onBarn and not onCoop then
			return Vector3.new(x, 0, z)
		end
	end
	return Vector3.new(0, 0, -30)
end

local function collect(player: Player, egg: BasePart, rare: boolean): boolean
	local data = Registry.Economy.Data(player)
	if not data or not egg.Parent then
		return false
	end
	local root = Registry.Plots.RootOf(player)
	if not root or (root.Position - egg.Position).Magnitude > R.PickDistance then
		return false
	end
	if (taken[player] or 0) >= R.MaxPerPlayer then
		return false
	end
	if Formulas.BasketCount(data) >= Registry.Economy.BasketCapacity(player) then
		return false
	end
	local key = Formulas.EggKey(R.Egg, rare)
	data.Basket[key] = (data.Basket[key] or 0) + 1
	data.Stats.GoldenEggs += 1
	data.Stats.Collected += 1
	taken[player] = (taken[player] or 0) + 1
	Registry.Economy.Mission(player, "collect", 1)
	if rare then
		data.Stats.Rare += 1
		Registry.Economy.Mission(player, "rare", 1)
	end
	Registry.Remotes.Fx:FireClient(player, "collect", egg.Position, 1)
	Registry.Economy.Push(player)
	return true
end

local function dropEgg()
	local egg = Instance.new("Part")
	egg.Name = "OvoDourado"
	egg.Size = Vector3.new(1.6, 2.1, 1.6)
	egg.Color = Color3.fromRGB(255, 200, 40)
	egg.Material = Enum.Material.Metal
	egg.Reflectance = 0.3
	local rare = math.random() < R.RareChance
	if rare then
		egg.Material = Enum.Material.Neon
	end
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = egg
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 215, 110)
	light.Range = 8
	light.Brightness = 1.5
	light.Parent = egg
	local spot = randomSpot()
	egg.CFrame = CFrame.new(spot + Vector3.new(0, 45 + math.random() * 20, 0)) * CFrame.Angles(math.random(), math.random(), math.random())
	egg.Parent = folder
	pcall(function()
		egg:SetNetworkOwner(nil) -- o servidor cuida da queda (ninguém "puxa" o ovo)
	end)
	alive += 1
	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		alive -= 1
		egg:Destroy()
	end
	egg.Touched:Connect(function(hit)
		if done then
			return
		end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and collect(player, egg, rare) then
			finish()
		end
	end)
	task.delay(R.EggLife, finish)
end

local function rain()
	workspace:SetAttribute("GoldenRainStart", workspace:GetServerTimeNow() + R.Warning)
	Registry.Remotes.NotifyAll(("Chuva de ovos dourados em %ds no cercadinho do centro!"):format(R.Warning), nil, "event")
	task.wait(R.Warning)
	workspace:SetAttribute("GoldenRainStart", 0)
	workspace:SetAttribute("GoldenRainEnd", workspace:GetServerTimeNow() + R.Duration)
	taken = {}
	Registry.Remotes.Fx:FireAllClients("sound", nil, "ChuvaDourada")
	Registry.Remotes.NotifyAll("Começou! Corre pro centro da ilha!", nil, "event")
	local ends = os.clock() + R.Duration
	while os.clock() < ends do
		if alive < R.MaxAlive then
			local ok, err = pcall(dropEgg)
			if not ok then
				warn("[Events] ovo:", err)
			end
		end
		task.wait(R.SpawnEvery)
	end
	workspace:SetAttribute("GoldenRainEnd", 0)
end

function Events.Init()
	folder = Instance.new("Folder")
	folder.Name = "ChuvaDourada"
	folder.Parent = workspace
	workspace:SetAttribute("GoldenRainEnd", 0)
	workspace:SetAttribute("GoldenRainStart", 0)
	task.spawn(function()
		while true do
			-- uma chuva a cada Interval: espera o resto do ciclo (aviso + chuva já contam)
			task.wait(math.max(R.Interval - R.Warning - R.Duration, 30))
			local ok, err = pcall(rain)
			if not ok then
				warn("[Events] chuva:", err)
			end
			workspace:SetAttribute("GoldenRainEnd", 0)
			workspace:SetAttribute("GoldenRainStart", 0)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		taken[player] = nil
	end)
end

return Events
