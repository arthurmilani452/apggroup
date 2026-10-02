--[[
	Leaderboards (ModuleScript em ServerScriptService > Game)          Prefeito Tycoon
	Placares globais no hub (OrderedDataStore): Prefeitos mais recomendados (estrelas) e
	Maiores cidades (pico de população). Grava os jogadores do servidor e lê o top 10 a cada 2 min.
	As placas são Workspace > Hub > BoardStars / BoardPopulation (o builder do lugar cria).
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local Leaderboards = {}

local REFRESH = 120

local boards = {
	{ Store = Config.LeaderboardStores.Stars, Attribute = "Stars", Part = "BoardStars", Title = "PREFEITOS MAIS RECOMENDADOS", Suffix = " ★" },
	{ Store = Config.LeaderboardStores.Population, Attribute = "PeakPopulation", Part = "BoardPopulation", Title = "MAIORES CIDADES", Suffix = " hab." },
}

local nameCache: { [number]: string } = {}

local function nameOf(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	nameCache[userId] = if ok then name else "?"
	return nameCache[userId]
end

local function boardLabel(partName: string, title: string): TextLabel?
	local hub = workspace:FindFirstChild("Hub")
	local target = hub and hub:FindFirstChild(partName)
	if not target or not target:IsA("BasePart") then
		return nil
	end
	local gui = target:FindFirstChild("BoardGui") :: SurfaceGui?
	if not gui then
		local newGui = Instance.new("SurfaceGui")
		newGui.Name = "BoardGui"
		newGui.Face = Enum.NormalId.Front
		newGui.PixelsPerStud = 30
		newGui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundColor3 = Color3.fromRGB(16, 20, 30)
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(235, 240, 255)
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.Text = title
		label.Parent = newGui
		newGui.Parent = target
		gui = newGui
	end
	return (gui :: any).Text
end

local function refresh(board: any)
	local okStore, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, board.Store)
	if not okStore then
		return
	end
	for _, player in Players:GetPlayers() do
		local value = player:GetAttribute(board.Attribute)
		if type(value) == "number" and value > 0 then
			pcall(store.SetAsync, store, "u_" .. player.UserId, math.floor(value))
		end
	end
	local label = boardLabel(board.Part, board.Title)
	if not label then
		return
	end
	local ok, pages = pcall(store.GetSortedAsync, store, false, 10)
	if not ok then
		return
	end
	local lines = { board.Title, "" }
	for rank, entry in pages:GetCurrentPage() do
		local userId = tonumber(string.match(entry.key, "^u_(%d+)$"))
		local name = if userId then nameOf(userId) else "?"
		table.insert(lines, ("%d. %s  %s%s"):format(rank, name, Format.Short(entry.value), board.Suffix))
	end
	label.Text = table.concat(lines, "\n")
end

function Leaderboards.Init()
	local title = boardLabel("Title", "PREFEITO TYCOON")
	if title then
		title.Font = Enum.Font.GothamBlack
		title.TextYAlignment = Enum.TextYAlignment.Center
		title.TextColor3 = Color3.fromRGB(255, 196, 70)
		title.Text = "PREFEITO TYCOON\n\nConstrua a sua cidade.\nCresça, colete o cofre, roube moradores dos vizinhos."
	end
	task.spawn(function()
		task.wait(15)
		while true do
			for _, board in boards do
				local ok, err = pcall(refresh, board)
				if not ok then
					warn("[Leaderboards]", err)
				end
			end
			task.wait(REFRESH)
		end
	end)
end

return Leaderboards
