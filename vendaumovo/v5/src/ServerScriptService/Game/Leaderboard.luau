--[[
	Leaderboard: placar GLOBAL dos maiores vendedores (todas as moedas já ganhas na vida).
	Grava num OrderedDataStore a cada 2 min e ao sair; a placa da praça atualiza a cada 90 s.
	O OrderedDataStore só guarda inteiros, e as moedas passam muito disso: gravamos log10(moedas) * 1e6.
	Placa: workspace.Map (qualquer peça chamada "LeaderboardBoard" com um SurfaceGui "Gui").
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Registry = require(script.Parent.Registry)

local Leaderboard = {}

local store: OrderedDataStore? = nil
local names: { [number]: string } = {}
local lastWritten: { [number]: number } = {}

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = if ok and name then name else "?"
	return names[userId]
end

function Leaderboard.Write(player: Player)
	local data = Registry.Game.Data(player)
	if not store or not data then
		return
	end
	local value = if data.TotalEarned >= 1 then math.floor(math.log10(data.TotalEarned) * 1e6) else 0
	if lastWritten[player.UserId] == value or value <= 0 then
		return
	end
	local ok, err = pcall(function()
		(store :: OrderedDataStore):SetAsync("u_" .. player.UserId, value)
	end)
	if ok then
		lastWritten[player.UserId] = value
	else
		warn("[Leaderboard] gravar:", err)
	end
end

local function boardGui(): SurfaceGui?
	local map = workspace:FindFirstChild("Map")
	local board = map and map:FindFirstChild("LeaderboardBoard", true)
	return board and board:FindFirstChildWhichIsA("SurfaceGui")
end

local function draw(rows: { { name: string, value: number } })
	local gui = boardGui()
	if not gui then
		return
	end
	local title = gui:FindFirstChild("Text")
	if title and title:IsA("TextLabel") then
		title.Size = UDim2.fromScale(1, 0.2)
		title.Text = "🏆 TOP 10"
	end
	local list = gui:FindFirstChild("List")
	if not list then
		local frame = Instance.new("Frame")
		frame.Name = "List"
		frame.BackgroundTransparency = 1
		frame.Position = UDim2.fromScale(0.04, 0.21)
		frame.Size = UDim2.fromScale(0.92, 0.77)
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0.01, 0)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = frame
		frame.Parent = gui
		list = frame
	end
	for _, child in (list :: Frame):GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local medals = { "🥇", "🥈", "🥉" }
	for i, row in rows do
		local label = Instance.new("TextLabel")
		label.LayoutOrder = i
		label.Size = UDim2.fromScale(1, 0.09)
		label.BackgroundColor3 = if i % 2 == 0 then Color3.fromRGB(255, 236, 190) else Color3.fromRGB(255, 246, 220)
		label.BorderSizePixel = 0
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = Color3.fromRGB(90, 50, 20)
		label.Text = ("  %s %s   💰 %s"):format(medals[i] or ("#" .. i), row.name, Format.Short(row.value))
		label.Parent = list
	end
	if #rows == 0 then
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 0.2)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(90, 50, 20)
		label.Text = "🥚 ..."
		label.Parent = list
	end
end

local function refresh()
	if not store then
		draw({})
		return
	end
	local ok, pages = pcall(function()
		return (store :: OrderedDataStore):GetSortedAsync(false, 10)
	end)
	if not ok or not pages then
		return
	end
	local rows = {}
	for _, entry in pages:GetCurrentPage() do
		local userId = tonumber(string.match(entry.key, "%d+"))
		if userId then
			table.insert(rows, { name = nameOf(userId), value = 10 ^ (entry.value / 1e6) })
		end
	end
	draw(rows)
end

function Leaderboard.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.LeaderboardStore)
	end)
	if ok then
		store = result
	end
	task.spawn(function()
		while true do
			pcall(refresh)
			task.wait(90)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(120)
			for _, player in Players:GetPlayers() do
				Leaderboard.Write(player)
				task.wait(1)
			end
		end
	end)
end

return Leaderboard
