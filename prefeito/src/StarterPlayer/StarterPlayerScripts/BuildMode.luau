--[[
	BuildMode (ModuleScript em StarterPlayerScripts)          Prefeito Tycoon
	Modo construção: menu de prédios por categoria, fantasma na grade (verde = pode, vermelho = não),
	área de alcance do prédio, girar (R), arrastar ruas, demolir (X) e sair (Q).
	No PC: clique constrói. No celular: toque escolhe o lugar e o botão "Construir aqui" confirma.
	O servidor confere tudo de novo; aqui é só para mostrar.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Buildings = require(Shared.Buildings)
local BuildingModels = require(Shared.BuildingModels)
local Grid = require(Shared.Grid)
local Format = require(Shared.Format)
local LotLayout = require(Shared.LotLayout)

local Scripts = script.Parent
local UI = require(Scripts.UI)
local State = require(Scripts.State)
local HUD = require(Scripts.HUD)

local player = Players.LocalPlayer
local T = UI.Theme
local CELL = Config.CellSize

local BuildMode = {}

local active = false
local removing = false
local selected: Buildings.Building? = nil
local rotation = 0
local category = "road"

local ghost: Model? = nil
local ghostKey = ""
local ghostOk: boolean? = nil
local range: Part? = nil
local gridLines: Folder? = nil
local gridExpansion = 0
local highlight: Highlight? = nil
local dragPool: { Part } = {}

local target: { X: number, Z: number }? = nil -- casa do canto do prédio sob o cursor
local dragStart: { X: number, Z: number }? = nil

local palette: Frame
local cardList: ScrollingFrame
local tabButtons: { [string]: TextButton } = {}
local toolbar: Frame
local removeButton: TextButton
local confirmButton: TextButton
local hint: TextLabel
local buildButton: TextButton

local onChanged = Instance.new("BindableEvent")
BuildMode.Changed = onChanged.Event -- (ativo: boolean)

function BuildMode.IsActive(): boolean
	return active
end

local function describe(def: Buildings.Building): string
	local parts = {}
	if def.Housing then
		table.insert(parts, "+" .. def.Housing .. " moradores")
	end
	if def.Income then
		table.insert(parts, "$" .. def.Income .. "/s")
	end
	if def.Jobs then
		table.insert(parts, def.Jobs .. " empregos")
	end
	if def.Need then
		for _, need in Config.Needs do
			if need.Id == def.Need then
				table.insert(parts, need.Name .. " (alcance " .. (def.Radius or 0) .. ")")
			end
		end
	end
	if def.Leisure then
		table.insert(parts, "Felicidade +" .. def.Leisure)
	end
	if def.PowerSupply then
		table.insert(parts, "+" .. def.PowerSupply .. " energia")
	end
	if def.Power then
		table.insert(parts, "usa " .. def.Power .. " energia")
	end
	if def.Pollution then
		table.insert(parts, "polui " .. def.Pollution)
	end
	return table.concat(parts, " · ")
end

-- ===== Ponteiro -> casa da grade =====

local function groundPoint(screenPos: Vector2, isTouch: boolean): Vector3?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local ray = if isTouch then camera:ScreenPointToRay(screenPos.X, screenPos.Y) else camera:ViewportPointToRay(screenPos.X, screenPos.Y)
	if ray.Direction.Y >= -1e-4 then
		return nil
	end
	local t = (Config.LotGroundY - ray.Origin.Y) / ray.Direction.Y
	if t < 0 or t > 2000 then
		return nil
	end
	return ray.Origin + ray.Direction * t
end

local function footprint(): (number, number)
	if selected then
		return Buildings.Footprint(selected, rotation)
	end
	return 1, 1
end

local function anchorFor(cx: number, cz: number): (number, number)
	local w, d = footprint()
	return cx - math.floor((w - 1) / 2), cz - math.floor((d - 1) / 2)
end

local function setTarget(screenPos: Vector2, isTouch: boolean)
	local lot = State.Lot()
	local point = groundPoint(screenPos, isTouch)
	if not lot or not point then
		target = nil
		return
	end
	local cx, cz = LotLayout.ToCell(lot, point)
	if removing then
		target = { X = cx, Z = cz }
	else
		local x, z = anchorFor(cx, cz)
		target = { X = x, Z = z }
	end
end

local function canAfford(def: Buildings.Building): (boolean, string?)
	local stats = State.Stats
	if not stats then
		return false, nil
	end
	if def.Tier > stats.TierReached then
		return false, "Libera em " .. Config.Tiers[def.Tier].Name
	end
	if stats.Cash < def.Cost then
		return false, "Falta dinheiro"
	end
	return true, nil
end

local function check(x: number, z: number): (boolean, string?)
	local stats = State.Stats
	local lot = State.Lot()
	if not selected or not stats or not lot then
		return false, nil
	end
	local ok, reason = canAfford(selected)
	if not ok then
		return false, reason
	end
	return Grid.CanPlace(State.Grid(lot), stats.Expansion, selected, x, z, rotation)
end

-- ===== Desenhos na grade =====

local function clearGhost()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	if range then
		range:Destroy()
		range = nil
	end
	ghostKey = ""
	ghostOk = nil
end

local function hideDrag()
	for _, p in dragPool do
		p.Parent = nil
	end
end

local function dragCells(): { { number } }
	local cells = {}
	if not dragStart or not target then
		return cells
	end
	local dx, dz = target.X - dragStart.X, target.Z - dragStart.Z
	if math.abs(dx) >= math.abs(dz) then
		local stepX = if dx >= 0 then 1 else -1
		for x = dragStart.X, target.X, stepX do
			table.insert(cells, { x, dragStart.Z })
		end
	else
		local stepZ = if dz >= 0 then 1 else -1
		for z = dragStart.Z, target.Z, stepZ do
			table.insert(cells, { dragStart.X, z })
		end
	end
	while #cells > 48 do
		table.remove(cells)
	end
	return cells
end

local function showDrag(lot: number)
	local cells = dragCells()
	local state = State.Grid(lot)
	local stats = State.Stats
	local budget = if stats and selected then math.floor(stats.Cash / selected.Cost) else 0
	local placedCount = 0
	for i, cell in cells do
		local p = dragPool[i]
		if not p then
			p = UI.new("Part", {
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
				Material = Enum.Material.Neon,
				Transparency = 0.45,
				Size = Vector3.new(CELL - 0.4, 0.2, CELL - 0.4),
			})
			dragPool[i] = p
		end
		local ok = selected ~= nil and Grid.CanPlace(state, stats.Expansion, selected, cell[1], cell[2], rotation)
		if ok then
			placedCount += 1
			ok = placedCount <= budget
		end
		p.Color = if ok then T.Good else T.Bad
		p.CFrame = LotLayout.CellCFrame(lot, cell[1], cell[2]) * CFrame.new(0, 0.45, 0)
		p.Parent = workspace
	end
	for i = #cells + 1, #dragPool do
		dragPool[i].Parent = nil
	end
	if selected then
		hint.Text = ("%d x %s = %s"):format(math.min(placedCount, budget), selected.Name, Format.Money(math.min(placedCount, budget) * selected.Cost))
	end
end

local function drawGridLines()
	local stats = State.Stats
	local lot = State.Lot()
	if not stats or not lot then
		return
	end
	if gridLines and gridExpansion == stats.Expansion then
		return
	end
	if gridLines then
		gridLines:Destroy()
	end
	gridExpansion = stats.Expansion
	local folder = UI.new("Folder", { Name = "BuildGrid" })
	local x1, x2, z1, z2 = Grid.Bounds(stats.Expansion)
	local lotCf = LotLayout.CFrame(lot)
	local lx1, lz1 = Grid.LocalPosition(x1, z1)
	local lx2, lz2 = Grid.LocalPosition(x2, z2)
	lx1 -= CELL / 2
	lz1 -= CELL / 2
	lx2 += CELL / 2
	lz2 += CELL / 2
	local function line(cf: CFrame, size: Vector3)
		UI.new("Part", {
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(120, 230, 255),
			Transparency = 0.6,
			Size = size,
			CFrame = cf,
			Parent = folder,
		})
	end
	for x = x1, x2 + 1 do
		local lx = lx1 + (x - x1) * CELL
		line(lotCf * CFrame.new(lx, 0.12, (lz1 + lz2) / 2), Vector3.new(0.15, 0.05, lz2 - lz1))
	end
	for z = z1, z2 + 1 do
		local lz = lz1 + (z - z1) * CELL
		line(lotCf * CFrame.new((lx1 + lx2) / 2, 0.12, lz), Vector3.new(lx2 - lx1, 0.05, 0.15))
	end
	folder.Parent = workspace
	gridLines = folder
end

local function radiusOf(def: Buildings.Building): (number, Color3?)
	if def.Radius then
		return def.Radius, T.Teal
	elseif def.LeisureRadius then
		return def.LeisureRadius, T.Good
	elseif def.PollutionRadius then
		return def.PollutionRadius, Color3.fromRGB(150, 110, 60)
	end
	return 0, nil
end

local function updateGhost()
	local lot = State.Lot()
	if not active or removing or not selected or not target or not lot then
		clearGhost()
		return
	end
	local key = selected.Id
	if ghostKey ~= key then
		clearGhost()
		ghostKey = key
		local radius, color = radiusOf(selected)
		if radius > 0 and color then
			range = UI.new("Part", {
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
				Material = Enum.Material.ForceField,
				Color = color,
				Transparency = 0.2,
			})
		end
	end
	local w, d = footprint()
	local placed = { X = target.X, Z = target.Z, R = rotation, W = w, D = d }
	local ok, reason = check(target.X, target.Z)
	if not ghost or ghostOk ~= ok then
		-- remonta para trocar a cor (MakeGhost troca os materiais de uma vez só)
		ghostOk = ok
		local fresh = BuildingModels.Build(selected)
		BuildingModels.MakeGhost(fresh, ok)
		if ghost then
			ghost:Destroy()
		end
		ghost = fresh
		fresh.Parent = workspace
	end
	(ghost :: Model):PivotTo(LotLayout.BuildingCFrame(lot, placed) * CFrame.new(0, 0.06, 0))
	if range and selected then
		local radius = radiusOf(selected)
		local cx, cz = Grid.Center(placed :: any)
		range.Size = Vector3.new((2 * radius + w) * CELL, 0.3, (2 * radius + d) * CELL)
		range.CFrame = LotLayout.CellCFrame(lot, cx, cz) * CFrame.new(0, 0.2, 0)
		range.Parent = workspace
	end
	if not dragStart then
		hint.Text = if ok
			then ("%s · %s"):format(selected.Name, Format.Money(selected.Cost))
			else (reason or "Não dá para construir aqui")
	end
end

local function updateRemoveHighlight()
	local lot = State.Lot()
	if not active or not removing or not target or not lot then
		if highlight then
			highlight.Adornee = nil
		end
		return
	end
	local uid = Grid.At(State.Grid(lot), target.X, target.Z)
	local lotModel = State.LotModel(lot)
	local model = uid and lotModel and lotModel.Buildings:FindFirstChild(tostring(uid))
	if not highlight then
		highlight = UI.new("Highlight", {
			FillColor = T.Bad,
			OutlineColor = T.Bad,
			FillTransparency = 0.5,
			DepthMode = Enum.HighlightDepthMode.Occluded,
			Parent = workspace,
		})
	end
	(highlight :: Highlight).Adornee = model
	if model then
		local def = Buildings.ById[model:GetAttribute("Id")]
		hint.Text = if def
			then ("Demolir %s (devolve %s)"):format(def.Name, Format.Money(math.floor(def.Cost * Config.SellRefund)))
			else ""
	else
		hint.Text = "Escolha um prédio para demolir"
	end
end

-- ===== Ações =====

local function placeAtTarget()
	if not selected or not target then
		return
	end
	local ok, reason = check(target.X, target.Z)
	if not ok then
		UI.Toast(reason or "Não dá para construir aqui", "erro")
		return
	end
	State.Request("place", { Id = selected.Id, X = target.X, Z = target.Z, R = rotation })
end

local function removeAtTarget()
	local lot = State.Lot()
	if not target or not lot then
		return
	end
	local uid = Grid.At(State.Grid(lot), target.X, target.Z)
	if uid then
		State.Request("remove", { Uid = uid })
	end
end

local refreshCards: () -> ()

local function setRemoving(value: boolean)
	removing = value
	UI.SetButtonColor(removeButton, if removing then T.Bad else T.Card)
	removeButton.Text = if removing then "Demolindo (X)" else "Demolir (X)"
	if removing then
		selected = nil
		clearGhost()
	end
	refreshCards()
end

local function selectBuilding(def: Buildings.Building)
	if removing then
		setRemoving(false)
	end
	selected = def
	if def.W ~= def.D then
		rotation = 0
	end
	clearGhost()
	refreshCards()
	UI.Sound("Click")
end

local function rotate()
	rotation = (rotation + 1) % 4
	clearGhost()
	if selected then
		local lot = State.Lot()
		if lot and target then
			updateGhost()
		end
	end
end

function BuildMode.Exit()
	if not active then
		return
	end
	active = false
	dragStart = nil
	palette.Visible = false
	toolbar.Visible = false
	confirmButton.Visible = false
	clearGhost()
	hideDrag()
	if gridLines then
		gridLines:Destroy()
		gridLines = nil
	end
	if highlight then
		highlight.Adornee = nil
	end
	buildButton.Text = "Construir (B)"
	onChanged:Fire(false)
end

function BuildMode.Enter()
	if active or not State.Stats then
		return
	end
	UI.CloseModals()
	active = true
	palette.Visible = true
	toolbar.Visible = true
	confirmButton.Visible = UI.IsMobile()
	drawGridLines()
	refreshCards()
	buildButton.Text = "Fechar (B)"
	-- longe de casa? volta para a cidade
	local lot = State.Lot()
	local character = player.Character
	local rootPart = character and character.PrimaryPart
	if lot and rootPart and not LotLayout.Contains(lot, rootPart.Position, 80) then
		State.Request("home")
	end
	onChanged:Fire(true)
end

function BuildMode.Toggle()
	if active then
		BuildMode.Exit()
	else
		BuildMode.Enter()
	end
end

-- ===== Menu =====

refreshCards = function()
	for id, button in tabButtons do
		UI.SetButtonColor(button, if id == category then T.Teal:Lerp(T.Card, 0.55) else T.Card)
	end
	for _, child in cardList:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	for _, def in Buildings.List do
		if def.Category == category then
			local affordable, reason = canAfford(def)
			local locked = reason ~= nil and reason ~= "Falta dinheiro"
			local card = UI.Button(cardList, "", {
				LayoutOrder = (def :: any).Order,
				Size = UDim2.fromOffset(170, 112),
				BackgroundColor3 = if selected == def then T.CardHover else T.Card,
			}, function()
				selectBuilding(def)
			end)
			if selected == def then
				UI.Stroke(card, T.Accent, 2, 0)
			end
			UI.Padding(card, 8)
			UI.Label(card, def.Name, 15, { Font = UI.FontBold, Size = UDim2.new(1, -30, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
			UI.Label(card, def.W .. "x" .. def.D, 12, {
				TextColor3 = T.Muted,
				TextXAlignment = Enum.TextXAlignment.Right,
				Size = UDim2.new(1, 0, 0, 16),
			})
			UI.Label(card, Format.Money(def.Cost), 16, {
				Font = UI.FontBlack,
				TextColor3 = if affordable then T.Accent else T.Bad,
				Position = UDim2.fromOffset(0, 20),
			})
			UI.Label(card, if locked then "🔒 " .. (reason :: string) else describe(def), 12, {
				TextColor3 = if locked then T.Warn else T.Muted,
				Position = UDim2.fromOffset(0, 44),
				Size = UDim2.new(1, 0, 0, 52),
				TextYAlignment = Enum.TextYAlignment.Top,
			})
		end
	end
end

local function buildUi()
	local gui = HUD.Gui()
	palette = UI.Panel(gui, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, -80, 1, -14),
		Size = UDim2.new(1, -200, 0, 176),
		Visible = false,
	})
	local tabs = UI.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 32), Parent = palette })
	UI.List(tabs, Enum.FillDirection.Horizontal, 6)
	for i, cat in Buildings.Categories do
		tabButtons[cat.Id] = UI.Button(tabs, cat.Name, { LayoutOrder = i, Size = UDim2.fromOffset(104, 30), TextSize = 14 }, function()
			category = cat.Id
			refreshCards()
		end)
	end
	cardList = UI.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 46),
		Size = UDim2.new(1, -20, 1, -54),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = T.Line,
		Parent = palette,
	})
	UI.List(cardList, Enum.FillDirection.Horizontal, 8)

	toolbar = UI.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, -80, 1, -198),
		Size = UDim2.fromOffset(640, 40),
		Visible = false,
		Parent = gui,
	})
	UI.List(toolbar, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
	UI.Button(toolbar, "Girar (R)", { LayoutOrder = 1, Size = UDim2.fromOffset(110, 38) }, rotate)
	removeButton = UI.Button(toolbar, "Demolir (X)", { LayoutOrder = 2, Size = UDim2.fromOffset(140, 38) }, function()
		setRemoving(not removing)
	end)
	confirmButton = UI.Button(toolbar, "Construir aqui", {
		LayoutOrder = 3,
		Size = UDim2.fromOffset(150, 38),
		BackgroundColor3 = T.Good:Lerp(T.Card, 0.4),
		Visible = false,
	}, function()
		if removing then
			removeAtTarget()
		else
			placeAtTarget()
		end
	end)
	local hintFrame = UI.Panel(toolbar, { LayoutOrder = 4, Size = UDim2.fromOffset(280, 38) })
	hint = UI.Label(hintFrame, "", 14, {
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(6, 0),
		Size = UDim2.new(1, -12, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
	})

	buildButton = HUD.AddButton("Construir (B)", 1, T.Accent:Lerp(T.Card, 0.55), BuildMode.Toggle)
end

-- ===== Entrada =====

local function onPointerMoved(position: Vector2, isTouch: boolean)
	if not active then
		return
	end
	setTarget(position, isTouch)
	if removing then
		updateRemoveHighlight()
	elseif dragStart then
		local lot = State.Lot()
		if lot then
			showDrag(lot)
		end
	else
		updateGhost()
	end
end

function BuildMode.Init()
	buildUi()
	selected = Buildings.ById.rua

	State.Changed.Event:Connect(function()
		if active then
			drawGridLines()
			refreshCards()
			ghostOk = nil -- dinheiro mudou: refaz o fantasma com a cor certa
		end
	end)

	RunService.RenderStepped:Connect(function()
		if active and not UI.IsMobile() then
			onPointerMoved(UserInputService:GetMouseLocation(), false)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.Keyboard then
			local key = input.KeyCode
			if key == Enum.KeyCode.B then
				BuildMode.Toggle()
			elseif active and key == Enum.KeyCode.R then
				rotate()
			elseif active and key == Enum.KeyCode.X then
				setRemoving(not removing)
			elseif active and (key == Enum.KeyCode.Q or key == Enum.KeyCode.Escape) then
				BuildMode.Exit()
			end
		elseif active and input.UserInputType == Enum.UserInputType.MouseButton1 then
			setTarget(UserInputService:GetMouseLocation(), false)
			if removing then
				removeAtTarget()
			elseif selected and selected.W == 1 and selected.D == 1 and target then
				dragStart = { X = target.X, Z = target.Z }
				clearGhost()
				local lot = State.Lot()
				if lot then
					showDrag(lot)
				end
			else
				placeAtTarget()
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 or not dragStart then
			return
		end
		local cells = dragCells()
		dragStart = nil
		hideDrag()
		if not selected or #cells == 0 then
			return
		end
		if #cells == 1 then
			placeAtTarget()
		else
			State.Request("line", { Id = selected.Id, Cells = cells, R = rotation })
		end
	end)

	-- celular: o toque escolhe o lugar (o botão "Construir aqui" confirma)
	UserInputService.TouchTap:Connect(function(positions, processed)
		if not active or processed or #positions == 0 then
			return
		end
		local p = positions[1]
		onPointerMoved(Vector2.new(p.X, p.Y), true)
	end)
end

return BuildMode
