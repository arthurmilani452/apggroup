--[[
	StyleUI (ModuleScript em StarterPlayer > StarterPlayerScripts)
	Tela "STYLE": tema da base, decoração (8 vagas), trilha e título.
	O servidor (Customize.luau) manda a situação de cada item (tem / pode comprar / falta conquista)
	e confere tudo de novo quando você aperta um botão.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Format = require(Shared:WaitForChild("Format"))
local UI = require(script.Parent:WaitForChild("UIKit"))

local StyleUI = {}

local C = UI.Colors
local create, corner, label, button = UI.create, UI.corner, UI.label, UI.button

local TABS = {
	{ Id = "theme", Name = "THEMES", Hint = "Change the look of your whole base. Every world you unlock gives a new theme!" },
	{ Id = "decor", Name = "DECOR", Hint = "Pick a spot (1-2 front, 3-6 sides, 7-8 back), then place a decoration you own." },
	{ Id = "trail", Name = "TRAILS", Hint = "A colorful trail behind you. Some are bought, some are earned." },
	{ Id = "title", Name = "TITLES", Hint = "A title above your head. Earn them by playing!" },
}

function StyleUI.Init(ctx)
	local frame, content = ctx.makePanel("Style", "STYLE", C.Pink)
	content.Position = UDim2.fromOffset(16, 116)
	content.Size = UDim2.new(1, -32, 1, -130)
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = content })

	local state: any = nil
	local tab = "theme"
	local spot = 1
	local tabButtons = {}
	local render: () -> ()

	local tabRow = create("Frame", {
		Position = UDim2.fromOffset(16, 64),
		Size = UDim2.new(1, -32, 0, 42),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = frame,
	}, {
		create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for order, info in TABS do
		tabButtons[info.Id] = button({
			LayoutOrder = order,
			Size = UDim2.new(0.25, -6, 1, 0),
			BackgroundColor3 = C.Row,
			ZIndex = 6,
			Parent = tabRow,
		}, info.Name, function()
			ctx.play("Click")
			tab = info.Id
			render()
		end)
	end

	local function clear()
		for _, child in content:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
	end

	local function row(order: number, title: string, subtitle: string, titleColor: Color3?)
		local rowFrame = create("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, -12, 0, 70),
			BackgroundColor3 = C.Row,
			ZIndex = 5,
			Parent = content,
		}, { corner(14) })
		label({
			Position = UDim2.fromOffset(74, 6),
			Size = UDim2.new(0.6, -80, 0, 32),
			Text = title,
			TextColor3 = titleColor or C.White,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 5,
			Parent = rowFrame,
		})
		label({
			Position = UDim2.fromOffset(74, 40),
			Size = UDim2.new(0.6, -80, 0, 22),
			Text = subtitle,
			TextColor3 = Color3.fromRGB(200, 200, 220),
			TextXAlignment = Enum.TextXAlignment.Left,
			StrokeThickness = 1,
			ZIndex = 5,
			Parent = rowFrame,
		})
		local swatch = create("Frame", {
			Position = UDim2.fromOffset(10, 9),
			Size = UDim2.fromOffset(52, 52),
			BackgroundColor3 = titleColor or C.Gray,
			ZIndex = 5,
			Parent = rowFrame,
		}, { corner(12), UI.border(C.Dark, 2) })
		return rowFrame, swatch
	end

	local function rowButton(rowFrame: Frame, text: string, color: Color3, onClick: () -> ())
		button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.new(0.34, 0, 0, 50),
			BackgroundColor3 = color,
			ZIndex = 5,
			Parent = rowFrame,
		}, text, function()
			ctx.play("Click")
			onClick()
		end)
	end

	local function status(kind: string, id: string): (string, string)
		local entry = state and state.Status and state.Status[kind] and state.Status[kind][id]
		if type(entry) == "table" then
			return entry[1], entry[2]
		end
		return "locked", "..."
	end

	local function buyButton(rowFrame: Frame, kind: string, item)
		rowButton(rowFrame, Format.Money(item.Price), C.Gold, function()
			UI.confirm(ctx.gui, "BUY?", ("Buy %s for %s?"):format(item.Name, Format.Money(item.Price)), "BUY", C.Gold, function()
				ctx.RequestEvent:FireServer("BuyStyle", { Kind = kind, Id = item.Id })
			end, ctx.scaleNow)
		end)
	end

	local function lockedButton(rowFrame: Frame, text: string)
		rowButton(rowFrame, text, C.Gray, function()
			ctx.toast("Locked: " .. text, "info")
		end)
	end

	local function hint(text: string)
		label({
			LayoutOrder = 0,
			Size = UDim2.new(1, -12, 0, 40),
			Text = text,
			TextWrapped = true,
			TextColor3 = Color3.fromRGB(230, 220, 255),
			StrokeThickness = 1.5,
			ZIndex = 5,
			Parent = content,
		})
	end

	local builders = {}

	builders.theme = function()
		for order, item in Cosmetics.Themes do
			local rowFrame = row(order, item.Name, item.Description, item.Swatch)
			local st, text = status("theme", item.Id)
			if st == "owned" then
				if state.Theme == item.Id then
					rowButton(rowFrame, "IN USE", C.Gray, function() end)
				else
					rowButton(rowFrame, "USE", C.Green, function()
						ctx.RequestEvent:FireServer("SetTheme", item.Id)
					end)
				end
			else
				lockedButton(rowFrame, text)
			end
		end
	end

	builders.decor = function()
		-- escolher a vaga
		local picker = create("Frame", { LayoutOrder = 1, Size = UDim2.new(1, -12, 0, 52), BackgroundTransparency = 1, ZIndex = 5, Parent = content }, {
			create("UIGridLayout", { CellSize = UDim2.new(1 / 9, -5, 1, 0), CellPadding = UDim2.fromOffset(5, 0), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		for n = 1, Cosmetics.DecorSpots do
			local placed = state.Decor[n] or ""
			local item = Cosmetics.ById.decor[placed]
			button({
				LayoutOrder = n,
				BackgroundColor3 = if n == spot then C.Pink else (if item then item.Color else C.Row),
				ZIndex = 5,
				Parent = picker,
			}, tostring(n), function()
				ctx.play("Click")
				spot = n
				render()
			end)
		end
		button({ LayoutOrder = 99, BackgroundColor3 = C.Red, ZIndex = 5, Parent = picker }, "CLEAR", function()
			ctx.play("Click")
			ctx.RequestEvent:FireServer("PlaceDecor", { Spot = spot, Id = "" })
		end)
		local current = Cosmetics.ById.decor[state.Decor[spot] or ""]
		label({
			LayoutOrder = 2,
			Size = UDim2.new(1, -12, 0, 26),
			Text = ("Spot %d: %s"):format(spot, if current then current.Name else "empty"),
			TextColor3 = C.Gold,
			ZIndex = 5,
			Parent = content,
		})
		for order, item in Cosmetics.Decor do
			local st, text = status("decor", item.Id)
			local subtitle = if item.Price then Format.Money(item.Price) else "Free reward"
			local rowFrame = row(10 + order, item.Name, subtitle, item.Color)
			if st == "buy" then
				buyButton(rowFrame, "decor", item)
			elseif st == "owned" then
				if state.Decor[spot] == item.Id then
					rowButton(rowFrame, "REMOVE", C.Red, function()
						ctx.RequestEvent:FireServer("PlaceDecor", { Spot = spot, Id = "" })
					end)
				else
					rowButton(rowFrame, "PLACE ON " .. spot, C.Green, function()
						ctx.RequestEvent:FireServer("PlaceDecor", { Spot = spot, Id = item.Id })
					end)
				end
			else
				lockedButton(rowFrame, text)
			end
		end
	end

	builders.trail = function()
		for order, item in Cosmetics.Trails do
			local st, text = status("trail", item.Id)
			local subtitle = if item.Price then Format.Money(item.Price) elseif item.World or item.Requires then "Reward" else "Free"
			local rowFrame, swatch = row(order, item.Name, subtitle, item.Colors[1])
			local keypoints = {}
			for i, color in item.Colors do
				table.insert(keypoints, ColorSequenceKeypoint.new(if #item.Colors == 1 then 0 else (i - 1) / (#item.Colors - 1), color))
			end
			if #keypoints == 1 then
				table.insert(keypoints, ColorSequenceKeypoint.new(1, item.Colors[1]))
			end
			swatch.BackgroundColor3 = C.White
			create("UIGradient", { Color = ColorSequence.new(keypoints), Parent = swatch })
			if st == "buy" then
				buyButton(rowFrame, "trail", item)
			elseif st == "owned" then
				if state.Trail == item.Id then
					rowButton(rowFrame, "ON (tap: off)", C.Gray, function()
						ctx.RequestEvent:FireServer("SetTrail", "")
					end)
				else
					rowButton(rowFrame, "EQUIP", C.Green, function()
						ctx.RequestEvent:FireServer("SetTrail", item.Id)
					end)
				end
			else
				lockedButton(rowFrame, text)
			end
		end
	end

	builders.title = function()
		for order, item in Cosmetics.Titles do
			local st, text = status("title", item.Id)
			local rowFrame = row(order, item.Name, if st == "owned" then "Unlocked!" else text, item.Color)
			if st == "owned" then
				if state.Title == item.Id then
					rowButton(rowFrame, "WEARING (off)", C.Gray, function()
						ctx.RequestEvent:FireServer("SetTitle", "")
					end)
				else
					rowButton(rowFrame, "WEAR", C.Green, function()
						ctx.RequestEvent:FireServer("SetTitle", item.Id)
					end)
				end
			else
				lockedButton(rowFrame, text)
			end
		end
	end

	render = function()
		for id, btn in tabButtons do
			btn.BackgroundColor3 = if id == tab then C.Pink else C.Row
		end
		clear()
		if not state then
			label({ LayoutOrder = 1, Size = UDim2.new(1, -12, 0, 40), Text = "Loading...", ZIndex = 5, Parent = content })
			return
		end
		for _, info in TABS do
			if info.Id == tab then
				hint(info.Hint)
			end
		end
		builders[tab]()
	end

	ctx.StyleEvent.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		state = payload
		state.Decor = if type(payload.Decor) == "table" then payload.Decor else {}
		if frame.Visible then
			render()
		end
	end)

	ctx.panelOpened.Style = function()
		ctx.RequestEvent:FireServer("StyleSync")
		render()
	end
end

return StyleUI
