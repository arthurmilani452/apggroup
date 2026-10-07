--[[
	Leaderboard: placar GLOBAL dos maiores vendedores (todas as moedas já ganhas na vida).
	Grava num OrderedDataStore a cada 2 min e ao sair; a placa da praça atualiza a cada 90 s.
	O OrderedDataStore só guarda inteiros, e as moedas passam muito disso: gravamos log10(moedas) * 1e6.
	Placa: workspace.Map (qualquer peça chamada "LeaderboardBoard" com um SurfaceGui "Gui").
	v6: mais duas placas, cópias da primeira, uma de cada lado dela, viradas para o meio da praça:
	  • esquerda: TOP 10 de RENASCIMENTOS (global, outro OrderedDataStore: Config.RebirthStore)
	  • direita: MAIS RICOS AGORA neste servidor (renda por segundo, ao vivo a cada 10 s)
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Registry = require(script.Parent.Registry)

local Leaderboard = {}

local Sim = require(ReplicatedStorage.Shared.Sim)

local store: OrderedDataStore? = nil
local rebirthStore: OrderedDataStore? = nil
local lastRebirths: { [number]: number } = {}
local extraGuis: { [string]: SurfaceGui } = {}
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
	-- v6: renascimentos (global)
	local rebirths = math.floor(tonumber(data.Rebirths) or 0)
	if rebirthStore and rebirths > 0 and lastRebirths[player.UserId] ~= rebirths then
		local okR, errR = pcall(function()
			(rebirthStore :: OrderedDataStore):SetAsync("u_" .. player.UserId, rebirths)
		end)
		if okR then
			lastRebirths[player.UserId] = rebirths
		else
			warn("[Leaderboard] gravar renascimentos:", errR)
		end
	end
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

-- v6: cópias da placa original ao lado dela (feitas uma vez, ao ligar o servidor)
local function makeExtraBoards()
	local map = workspace:FindFirstChild("Map")
	local board = map and map:FindFirstChild("LeaderboardBoard", true)
	local sign = board and board:FindFirstAncestorOfClass("Model")
	if not sign or not board then
		return
	end
	local pivot = sign:GetPivot()
	local center = pivot.Position
	for key, side in { Rebirths = -1, Richest = 1 } do
		local copy = sign:Clone()
		copy.Name = "LeaderboardSign_" .. key
		-- 21 studs para o lado e virada uns 17° para o meio da praça
		local spot = center + pivot.RightVector * (21 * side)
		local turned = CFrame.new(spot) * CFrame.Angles(0, 0.3 * side, 0) * (pivot - center)
		copy:PivotTo(turned)
		local copyBoard = copy:FindFirstChild("LeaderboardBoard", true)
		if copyBoard then
			copyBoard.Name = "LeaderboardBoard_" .. key -- (a busca da placa original não acha a cópia)
			local gui = copyBoard:FindFirstChildWhichIsA("SurfaceGui")
			if gui then
				extraGuis[key] = gui
			end
		end
		copy.Parent = sign.Parent
	end
end

local function draw(rows: { { name: string, value: number } }, target: SurfaceGui?, heading: string?, show: ((number) -> string)?)
	local gui = target or boardGui()
	if not gui then
		return
	end
	local title = gui:FindFirstChild("Text")
	if title and title:IsA("TextLabel") then
		title.Size = UDim2.fromScale(1, 0.2)
		title.Text = heading or "🏆 TOP 10"
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
		label.Text = ("  %s %s   %s"):format(medals[i] or ("#" .. i), row.name, if show then show(row.value) else "💰 " .. Format.Short(row.value))
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

local function refreshRebirths()
	local gui = extraGuis.Rebirths
	if not gui then
		return
	end
	if not rebirthStore then
		draw({}, gui, "🔄 TOP RENASCIMENTOS")
		return
	end
	local ok, pages = pcall(function()
		return (rebirthStore :: OrderedDataStore):GetSortedAsync(false, 10)
	end)
	if not ok or not pages then
		return
	end
	local rows = {}
	for _, entry in pages:GetCurrentPage() do
		local userId = tonumber(string.match(entry.key, "%d+"))
		if userId then
			table.insert(rows, { name = nameOf(userId), value = entry.value })
		end
	end
	draw(rows, gui, "🔄 TOP RENASCIMENTOS", function(n)
		return "🔄 " .. tostring(math.floor(n))
	end)
end

-- quem está no servidor agora, pela renda por segundo
local function refreshRichest()
	local gui = extraGuis.Richest
	if not gui then
		return
	end
	local rows = {}
	for _, player in Players:GetPlayers() do
		local data = Registry.Game.Data(player)
		if data then
			local ok, income = pcall(Sim.Income, Config, data, Registry.Game.Ctx(player))
			table.insert(rows, { name = player.DisplayName, value = if ok then income else 0 })
		end
	end
	table.sort(rows, function(a, b)
		return a.value > b.value
	end)
	while #rows > 10 do
		table.remove(rows)
	end
	draw(rows, gui, "💰 MAIS RICOS AGORA", function(n)
		return "💰 " .. Format.Short(n) .. "/s"
	end)
end

function Leaderboard.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.LeaderboardStore)
	end)
	if ok then
		store = result
	end
	local okR, resultR = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.RebirthStore)
	end)
	if okR then
		rebirthStore = resultR
	end
	pcall(makeExtraBoards)
	task.spawn(function()
		while true do
			pcall(refreshRichest)
			task.wait(10)
		end
	end)
	task.spawn(function()
		task.wait(5)
		while true do
			pcall(refreshRebirths)
			task.wait(90)
		end
	end)
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
