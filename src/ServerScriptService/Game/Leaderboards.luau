--[[
	Leaderboards (ModuleScript em ServerScriptService > Game)
	Três placares GLOBAIS (todos os servidores) nas placas do lobby:
	  • TOP EARNERS: quem mais ganhou dinheiro na vida
	  • TOP THIEVES: quem mais roubou
	  • TOP COLLECTORS: quem descobriu mais bichinhos diferentes no Índice
	Atualiza a cada 60 s. Só funciona com o jogo publicado (no Studio aparece um aviso).
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Registry = require(script.Parent.Registry)

local Leaderboards = {}

local MAX_VALUE = 2 ^ 52
local LOG_SCALE = 1e12

local boards = {
	{ Key = "TotalEarned", Store = "TopEarners_v2", Board = "EarnersBoard", Title = "TOP EARNERS", Money = true, Log = true, Color = Color3.fromRGB(120, 255, 120) },
	{ Key = "Steals", Store = "TopThieves_v1", Board = "ThievesBoard", Title = "TOP THIEVES", Money = false, Color = Color3.fromRGB(255, 120, 120) },
	{ Key = "Collected", Store = "TopCollectors_v1", Board = "CollectorsBoard", Title = "TOP COLLECTORS", Money = false, Color = Color3.fromRGB(120, 200, 255) },
	{ Key = "Likes", Store = "TopLikes_v1", Board = "LikesBoard", Title = "MOST LIKED BASES", Money = false, Color = Color3.fromRGB(255, 130, 190) },
}

local nameCache: { [number]: string } = {}

local function makeText(parent: Instance, text: string, size: UDim2, position: UDim2, color: Color3, alignment: Enum.TextXAlignment?): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextXAlignment = alignment or Enum.TextXAlignment.Center
	label.Text = text
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(20, 20, 35)
	stroke.Parent = label
	label.Parent = parent
	return label
end

local function buildBoard(info)
	local part = workspace:WaitForChild("Map"):FindFirstChild("Leaderboards")
	part = part and part:FindFirstChild(info.Board)
	if not part then
		return
	end
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.LightInfluence = 0
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 30
	surface.Parent = part
	makeText(surface, info.Title, UDim2.new(1, -20, 0.12, 0), UDim2.new(0, 10, 0.02, 0), info.Color)
	info.Rows = {}
	for i = 1, Config.LeaderboardSize do
		local y = 0.16 + (i - 1) * 0.082
		local rankColor = if i == 1 then Color3.fromRGB(255, 215, 60) elseif i == 2 then Color3.fromRGB(220, 220, 230) elseif i == 3 then Color3.fromRGB(230, 150, 90) else Color3.fromRGB(255, 255, 255)
		local nameLabel = makeText(surface, "", UDim2.new(0.62, 0, 0.07, 0), UDim2.new(0.04, 0, y, 0), rankColor, Enum.TextXAlignment.Left)
		local valueLabel = makeText(surface, "", UDim2.new(0.3, 0, 0.07, 0), UDim2.new(0.66, 0, y, 0), info.Color, Enum.TextXAlignment.Right)
		info.Rows[i] = { Name = nameLabel, Value = valueLabel }
	end
	info.Status = info.Rows[1].Name
	info.Rows[1].Name.Text = "Loading..."
end

local function namesFor(userIds: { number })
	local missing = {}
	for _, id in userIds do
		if not nameCache[id] then
			table.insert(missing, id)
		end
	end
	if #missing > 0 then
		local ok, infos = pcall(function()
			return UserService:GetUserInfosByUserIdsAsync(missing)
		end)
		if ok and type(infos) == "table" then
			for _, entry in infos do
				nameCache[entry.Id] = entry.DisplayName
			end
		end
	end
end

local function refresh(info)
	if not info.Rows then
		return
	end
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(info.Store)
	end)
	if not ok then
		info.Rows[1].Name.Text = "Publish the game to see leaderboards"
		return
	end
	-- 1) envia os números de quem está no servidor
	for _, player in Players:GetPlayers() do
		local profile = Registry.Data.Get(player)
		if profile and profile.CanSave and player:GetAttribute("Loaded") then
			local raw = math.max(0, tonumber(profile.Data[info.Key]) or 0)
			-- números gigantes: guarda o log (mantém a ordem certa e cabe no OrderedDataStore)
			local value = if info.Log then math.floor(math.log10(raw + 1) * LOG_SCALE) else math.clamp(math.floor(raw), 0, MAX_VALUE)
			if value > 0 then
				pcall(function()
					store:SetAsync("u_" .. player.UserId, value)
				end)
			end
		end
	end
	-- 2) busca o top 10
	local success, pages = pcall(function()
		return store:GetSortedAsync(false, Config.LeaderboardSize)
	end)
	if not success or not pages then
		info.Rows[1].Name.Text = "Publish the game to see leaderboards"
		return
	end
	local page = pages:GetCurrentPage()
	local ids = {}
	for _, entry in page do
		local id = tonumber(string.sub(entry.key, 3))
		if id then
			table.insert(ids, id)
		end
	end
	namesFor(ids)
	for i = 1, Config.LeaderboardSize do
		local row = info.Rows[i]
		local entry = page[i]
		if entry then
			local id = tonumber(string.sub(entry.key, 3)) or 0
			row.Name.Text = ("#%d  %s"):format(i, nameCache[id] or "Player")
			local shown = if info.Log then 10 ^ (entry.value / LOG_SCALE) - 1 else entry.value
			row.Value.Text = if info.Money then Format.Money(shown) else Format.Short(shown)
		else
			row.Name.Text = if i == 1 then "Be the first!" else ""
			row.Value.Text = ""
		end
	end
end

function Leaderboards.Init()
	for _, info in boards do
		buildBoard(info)
	end
	task.spawn(function()
		task.wait(10)
		while true do
			local ok, err = pcall(function()
				for _, info in boards do
					refresh(info)
				end
			end)
			if not ok then
				warn("[Leaderboards] loop error:", err)
			end
			task.wait(Config.LeaderboardRefresh)
		end
	end)
end

return Leaderboards
