--[[
	Plots: as granjas (terrenos) do mapa. Dá uma para cada jogador, devolve quando ele sai e DESENHA
	o que ele já comprou: prédios dos negócios, gerentes, enfeites das melhorias, cercados das aves,
	esteiras, ovos raros nos ninhos e os botões do chão. E o que ele AINDA NÃO comprou: um "lote
	trancado" (canteiro de obras com placa) no lugar de cada negócio fechado, para o terreno já mostrar
	o futuro desde o primeiro segundo. De tempos em tempos, o saco de dinheiro que caiu (Plots.SyncBag).
	Versão 5: a chave secreta escondida num canto (Plots.SyncKey) e o Baú Secreto (Plots.SyncChest).

	Cada granja (workspace.Plots.PlotN) vem do build só com o chão, a placa do nome e a peça
	"PlotOrigin" (centro do terreno, na altura do piso). Todo o resto nasce aqui (até a banca, que
	aparece com o botão "banca_unlock") a partir de ReplicatedStorage > Assets, nas posições do módulo
	Layout (coordenadas locais do terreno).

	Plots.Sync(plot) é a peça central: compara o que DEVERIA existir (pelos dados do dono) com o que
	existe e cria/apaga a diferença. Pode chamar quantas vezes quiser.

	O cliente desenha o resto (fregueses, vans, moedas no chão, barras de trabalho) a partir dos
	NOMES em plot.Visuals e dos ATRIBUTOS em plot.Model. Os dois são contrato com o cliente
	(design/V4_SPEC.md, seções 3.1 e 3.2): não mude um sem mudar o outro.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetLib = require(ReplicatedStorage.Shared.AssetLib)
local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Sim = require(ReplicatedStorage.Shared.Sim)
local Registry = require(script.Parent.Registry)

local Plots = {}

export type Plot = {
	Index: number,
	Model: Model,
	Origin: CFrame,
	Owner: Player?,
	Visuals: Folder,
	Run: any, -- estado da sessão (Sim.NewRun)
	Available: { any }, -- botões que estão no chão agora
	Hold: { [string]: number },
	Work: { [number]: { Token: number, EndsAt: number, Len: number } }, -- ciclos manuais em andamento
	LastBuy: number,
	LikedBy: { [number]: boolean },
}

local plots: { Plot } = {}
local byPlayer: { [Player]: Plot } = {}

-- cor de cada tipo de botão do chão (o de abrir negócio é o "botão verde" das dicas)
local PAD_COLORS = {
	unlock = Color3.fromRGB(60, 205, 90),
	manager = Color3.fromRGB(175, 110, 255),
	cash = Color3.fromRGB(255, 205, 50),
	speed = Color3.fromRGB(255, 140, 40),
	bird = Color3.fromRGB(255, 110, 190),
	global = Color3.fromRGB(60, 200, 190),
}
local WORK_COLOR = Color3.fromRGB(70, 160, 255) -- o "tapete azul"
local SELL_COLOR = Color3.fromRGB(80, 220, 110)

function Plots.All(): { Plot }
	return plots
end

function Plots.Of(player: Player): Plot?
	return byPlayer[player]
end

-- Ponto do Layout ({x, z, yaw?}) -> CFrame no mundo (y = altura acima do piso)
function Plots.CF(plot: Plot, x: number, z: number, yaw: number?, y: number?): CFrame
	return plot.Origin * CFrame.new(x, y or 0, z) * CFrame.Angles(0, math.rad(yaw or 0), 0)
end

function Plots.Local(plot: Plot, position: Vector3): Vector3
	return plot.Origin:PointToObjectSpace(position)
end

function Plots.RootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Onde fica o botão de cada compra (ponto {x, z} do Layout)
function Plots.ButtonPoint(button: any): { number }
	local kind = button.Kind
	if kind == "unlock" then
		return Layout.Biz[button.Biz].U
	elseif kind == "manager" then
		return Layout.Biz[button.Biz].M
	elseif kind == "cash" then
		return Layout.Biz[button.Biz].C[button.Step]
	elseif kind == "speed" then
		return Layout.Biz[button.Biz].S[button.Step]
	elseif kind == "bird" then
		return Layout.Lines[button.Line].Pad
	end
	return Layout.Global[button.Spot].Button
end

function Plots.SpawnCFrame(plot: Plot): CFrame
	local s = Layout.Spawn
	return Plots.CF(plot, s[1], s[2], 180, 4)
end

-- só escreve o atributo quando o valor mudou (cada escrita vai pela rede para todo mundo)
local function setAttr(inst: Instance, key: string, value: any)
	if inst:GetAttribute(key) ~= value then
		inst:SetAttribute(key, value)
	end
end

local function ownerId(plot: Plot): number
	return if plot.Owner then plot.Owner.UserId else 0
end

-- ---------------------------------------------------------------------------
-- Construtores
-- ---------------------------------------------------------------------------
local function group(name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	return m
end

-- Coloca um asset no ponto {x, z, yaw?, escala?}. collide nil = como o asset veio.
local function place(plot: Plot, parent: Instance, asset: string, point: { number }, scale: number?, collide: boolean?, y: number?): Model?
	local model = AssetLib.Get(asset, scale or point[4])
	if not model then
		return nil
	end
	if collide ~= nil then
		AssetLib.SetCollide(model, collide)
	end
	model:PivotTo(Plots.CF(plot, point[1], point[2], point[3], y))
	model.Parent = parent
	return model
end

-- Disco deitado no chão (botões e tapetes). O cilindro do Roblox tem o eixo em X: por isso o giro.
local function disc(plot: Plot, name: string, point: { number }, diameter: number, height: number, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(height, diameter, diameter)
	part.CFrame = Plots.CF(plot, point[1], point[2], 0, height / 2 + 0.02) * CFrame.Angles(0, 0, math.rad(90))
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function padKind(button: any): string
	local kind = button.Kind
	if kind == "unlock" or kind == "manager" or kind == "cash" or kind == "speed" or kind == "bird" then
		return kind
	end
	return "global"
end

local function makePad(plot: Plot, button: any): Instance
	local kind = padKind(button)
	local pad = disc(plot, "B_" .. button.Id, Plots.ButtonPoint(button), 5.4, 0.5, PAD_COLORS[kind])
	pad:SetAttribute("ButtonId", button.Id)
	pad:SetAttribute("Cost", button.Cost)
	pad:SetAttribute("OwnerId", ownerId(plot))
	pad:SetAttribute("PadKind", kind)
	CollectionService:AddTag(pad, "VUOButton")
	return pad
end

-- Tapete azul de trabalho: fica no lugar do botão que abriu o negócio, enquanto não tem gerente
local function makeWorkPad(plot: Plot, index: number): Instance
	local pad = disc(plot, "W_" .. Config.Businesses[index].Id, Layout.Biz[index].U, 2 * Config.WorkRadius, 0.3, WORK_COLOR)
	pad.Transparency = 0.35
	pad:SetAttribute("Biz", index)
	pad:SetAttribute("OwnerId", ownerId(plot))
	CollectionService:AddTag(pad, "VUOWork")
	return pad
end

local function mutantFx(model: Model, mutation: any)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local light = Instance.new("PointLight")
	light.Color = mutation.Color
	local strength = mutation.Index or 1 -- 1 brilhante, 2 gigante, 3 mítico
	light.Range = 4 + 2 * strength
	light.Brightness = 0.35 * strength * strength
	light.Parent = root
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(mutation.Color)
	sparkle.Size = NumberSequence.new(0.55, 0)
	sparkle.Lifetime = NumberRange.new(0.6, 1.1)
	sparkle.Rate = 2 + 4 * strength
	sparkle.Speed = NumberRange.new(1.5, 3)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.LightEmission = 1
	sparkle.Parent = root
end

-- Ovo solto (ninho/chocadeira/eventos). mutId "" ou nil = normal.
function Plots.MakeEgg(lineIndex: number, mutId: string?): Model?
	local line = Config.Lines[lineIndex]
	if not line then
		return nil
	end
	local mutation = mutId and Config.MutationById[mutId]
	local model = AssetLib.Get(line.EggAsset, if mutation then mutation.Scale else 1)
	if not model then
		return nil
	end
	AssetLib.SetCollide(model, false)
	if mutation then
		mutantFx(model, mutation)
	end
	model:SetAttribute("Mut", mutId or "")
	return model
end

-- Texto num "Letreiro" do asset. key = chave do Lang: o cliente troca o texto pelo idioma do jogador.
local function signText(model: Model?, text: string, key: string?)
	local face = model and AssetLib.Find(model, "Letreiro")
	if not face then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Gui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.AutoLocalize = false
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.fromRGB(70, 38, 15)
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui
	gui.Parent = face
	if key then
		face:SetAttribute("TextKey", key)
		CollectionService:AddTag(face, "VUOText")
	end
end

-- ---------------------------------------------------------------------------
-- Negócios: prédio (Biz_<id>), gerente (Mgr_<id>) e enfeites das melhorias (P_<idDoBotão>)
-- ---------------------------------------------------------------------------
-- A banca: o modelo, o tapete verde de vender ovos raros (atrás do balcão) e a área de clique.
local function buildStand(plot: Plot, m: Model)
	local s = Layout.Stand
	local stand = place(plot, m, "Banca", s)
	if stand then
		signText(stand, Lang.T("stand.sign"), "stand.sign")
		m.PrimaryPart = stand.PrimaryPart
	end
	local sellPad = disc(plot, "SellPad", Layout.Sell, 11, 0.3, SELL_COLOR)
	sellPad.Transparency = 0.5
	sellPad.Parent = m
	-- Caixa invisível em volta da banca: é nela que o clique do mouse/dedo pega (as peças da banca têm
	-- formas demais para clicar bem). O ClickDetector avisa o servidor, que confere distância e ritmo.
	local area = Instance.new("Part")
	area.Name = "ClickArea"
	area.Size = Vector3.new(12, 10, 8)
	area.CFrame = Plots.CF(plot, s[1], s[2], s[3], 5)
	area.Transparency = 1
	area.Anchored = true
	area.CanCollide = false
	area.CanTouch = false
	area.CanQuery = true
	area.CastShadow = false
	local detector = Instance.new("ClickDetector")
	detector.MaxActivationDistance = Config.ClickRadius + 8
	detector.Parent = area
	detector.MouseClick:Connect(function(player: Player)
		local ok, err = pcall(function()
			if Registry.Farm then
				Registry.Farm.Click(player, plot)
			end
		end)
		if not ok then
			warn("[Plots] clique na banca:", err)
		end
	end)
	area.Parent = m
end

-- prédio de cada negócio (a granja são os cercados; a fábrica são a esteira e as máquinas: sem prédio)
local BIZ_ASSET = { entrega = "Garagem", deposito = "Celeiro_1", omeleteria = "Omeleteria", lab = "Laboratorio", foguete = "Plataforma_Foguete" }
local BIZ_SIGN = { omeleteria = "diner.sign", lab = "lab.sign" }

local function buildBiz(plot: Plot, index: number): Instance
	local biz = Config.Businesses[index]
	local m = group("Biz_" .. biz.Id)
	m:SetAttribute("Biz", index)
	CollectionService:AddTag(m, "VUOBiz")
	if biz.Id == "banca" then
		buildStand(plot, m)
		return m
	end
	local asset = BIZ_ASSET[biz.Id]
	if asset then
		-- os prédios têm parede de verdade (os modelos novos vêm sem colisão)
		local model = place(plot, m, asset, Layout.Biz[index].Model, nil, true)
		if model then
			m.PrimaryPart = model.PrimaryPart
			local key = BIZ_SIGN[biz.Id]
			if key then
				signText(model, Lang.T(key), key)
			end
			if biz.Id == "lab" then
				CollectionService:AddTag(model, "VUOSpin") -- o cliente gira a peça "Gira"
			end
		end
	end
	return m
end

-- O gerente parado no posto dele. Na granja o Model fica vazio: o cliente anima um Fazendeiro andando.
local function buildManager(plot: Plot, index: number): Instance
	local biz = Config.Businesses[index]
	local npc = Layout.Biz[index].Npc
	local model: Model? = nil
	if biz.Id ~= "granja" then
		model = AssetLib.Get("Gerente")
		if model then
			AssetLib.SetCollide(model, false)
			model:PivotTo(Plots.CF(plot, npc[1], npc[2], npc[3]))
		end
	end
	local m = model or group("Mgr_" .. biz.Id)
	m:SetAttribute("Biz", index)
	CollectionService:AddTag(m, "VUOManager")
	return m
end

-- Enfeites que não estão no Layout.Props. banca_ouro: dois pedestais com ovo dourado ao lado da banca.
local EXTRA_PROPS: { [string]: (Plot, Model) -> () } = {}

EXTRA_PROPS.banca_ouro = function(plot, m)
	local s = Layout.Stand
	for _, dx in { -11, 11 } do
		local base = Instance.new("Part")
		base.Name = "Pedestal"
		base.Shape = Enum.PartType.Cylinder
		base.Size = Vector3.new(1.6, 3.2, 3.2)
		base.Anchored = true
		base.Material = Enum.Material.Slate
		base.Color = Color3.fromRGB(216, 207, 192)
		base.CFrame = Plots.CF(plot, s[1] + dx, s[2] - 0.5, 0, 0.8) * CFrame.Angles(0, 0, math.rad(90))
		base.Parent = m
		place(plot, m, "Ovo_Dourado", { s[1] + dx, s[2] - 0.5, 0 }, 2.4, false, 1.6)
	end
end

-- estes enfeites são construções: têm colisão (o resto é enfeite leve e fica como o asset veio)
local function propCollides(asset: string): boolean?
	if string.sub(asset, 1, 8) == "Maquina_" or string.sub(asset, 1, 8) == "Celeiro_" or asset == "Galinheiro" then
		return true
	end
	return nil
end

local function hasProps(id: string): boolean
	return Layout.Props[id] ~= nil or EXTRA_PROPS[id] ~= nil
end

local function buildProps(plot: Plot, id: string): Instance
	local m = group("P_" .. id)
	m:SetAttribute("ButtonId", id)
	for _, item in Layout.Props[id] or {} do
		local model = place(plot, m, item.A, item.P, nil, propCollides(item.A), item.Y)
		if model then
			if item.Tag then
				CollectionService:AddTag(model, item.Tag)
			end
			if item.Sign then
				signText(model, Lang.T(item.Sign), item.Sign)
			end
		end
	end
	local extra = EXTRA_PROPS[id]
	if extra then
		extra(plot, m)
	end
	return m
end

-- ---------------------------------------------------------------------------
-- LOTES TRANCADOS (Lot_<id>): canteiro de obras no lugar de cada negócio que ainda não abriu.
-- Posições em Layout.Lots[i] (conferidas no build: longe dos botões e fora das rotas). Feito de peças
-- simples (14 por lote: 8 lotes num terreno novo = 112 peças), nada de asset, para pesar pouco.
-- O jogador ATRAVESSA tudo (fita, postes, caixote e também a placa de madeira): nada ali pode prender
-- ninguém. Os 8 lotes nascem de uma vez ao renascer, com o jogador parado em qualquer lugar do terreno:
-- uma placa com colisão nasceria atravessada no boneco (tranco de física) e ainda puxaria a câmera para
-- perto toda vez que ficasse entre ela e o jogador.
-- O cliente escreve nome, frase e preço numa plaquinha em cima da placa (tag VUOLot).
-- ---------------------------------------------------------------------------
local LOT_COLORS = {
	Dirt = Color3.fromRGB(128, 88, 56), -- terra revolvida
	Mound = Color3.fromRGB(112, 76, 48),
	Post = Color3.fromRGB(36, 36, 42), -- postes pretos + fita amarela = "obra"
	Tape = Color3.fromRGB(255, 208, 40),
	Wood = Color3.fromRGB(184, 128, 76),
	WoodDark = Color3.fromRGB(126, 84, 48),
	Barrel = Color3.fromRGB(255, 122, 40),
}

local function lotPart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?, shadow: boolean?): Part
	local part = Instance.new("Part")
	part.Name = name
	if shape then
		part.Shape = shape
	end
	part.Size = size
	part.CFrame = cf
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = shadow == true -- só a placa faz sombra (o resto é miúdo: sombra só custaria)
	part.Material = material
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function buildLot(plot: Plot, index: number): Instance
	local biz = Config.Businesses[index]
	local lot = Layout.Lots[index]
	local m = group("Lot_" .. biz.Id)
	m:SetAttribute("Biz", index)
	m:SetAttribute("OwnerId", ownerId(plot))
	CollectionService:AddTag(m, "VUOLot")
	local w, d = lot.Size[1], lot.Size[2]
	local base = Plots.CF(plot, lot.Center[1], lot.Center[2], lot.Center[3])
	local plastic = Enum.Material.SmoothPlastic
	-- chão de terra (um pouco acima do piso e da palha dos cercados, para não piscar)
	lotPart(m, "Chao", Vector3.new(w, 0.16, d), base * CFrame.new(0, 0.11, 0), LOT_COLORS.Dirt, Enum.Material.Ground)
	-- cerquinha: 4 postes e 4 fitas
	for _, corner in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		lotPart(m, "Poste", Vector3.new(0.6, 2.8, 0.6), base * CFrame.new(corner[1] * w / 2, 1.4, corner[2] * d / 2), LOT_COLORS.Post, plastic)
	end
	for _, side in { -1, 1 } do
		lotPart(m, "Fita", Vector3.new(w, 0.5, 0.16), base * CFrame.new(0, 2.25, side * d / 2), LOT_COLORS.Tape, plastic)
		lotPart(m, "Fita", Vector3.new(0.16, 0.5, d), base * CFrame.new(side * w / 2, 2.25, 0), LOT_COLORS.Tape, plastic)
	end
	-- montinho de terra (bola quase toda enterrada: só aparece a calota), caixote e barril de obra
	lotPart(m, "Monte", Vector3.new(5, 5, 5), Plots.CF(plot, lot.Mound[1], lot.Mound[2], 0, -0.9), LOT_COLORS.Mound, Enum.Material.Ground, Enum.PartType.Ball)
	lotPart(m, "Caixote", Vector3.new(2.2, 2.2, 2.2), Plots.CF(plot, lot.Crate[1], lot.Crate[2], lot.Crate[3], 1.29), LOT_COLORS.Wood, Enum.Material.WoodPlanks)
	-- (o cilindro do Roblox tem o eixo em X: o giro põe o barril de pé)
	lotPart(m, "Barril", Vector3.new(2.6, 1.8, 1.8), Plots.CF(plot, lot.Barrel[1], lot.Barrel[2], 0, 1.49) * CFrame.Angles(0, 0, math.rad(90)), LOT_COLORS.Barrel, plastic, Enum.PartType.Cylinder)
	-- placa de madeira grande, de frente para quem chega (frente = -Z, como os modelos)
	local sign = Plots.CF(plot, lot.Sign[1], lot.Sign[2], lot.Sign[3])
	lotPart(m, "PlacaPoste", Vector3.new(0.7, 4.2, 0.7), sign * CFrame.new(0, 2.1, 0.5), LOT_COLORS.WoodDark, Enum.Material.Wood, nil, true)
	local board = lotPart(m, "Placa", Vector3.new(7.5, 3.4, 0.5), sign * CFrame.new(0, 5.6, 0), LOT_COLORS.Wood, Enum.Material.WoodPlanks, nil, true)
	m.PrimaryPart = board
	-- cadeado pintado na placa (não depende de idioma; o resto do texto é do cliente)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Gui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40 -- (o cadeado ocupa a tábua toda: com menos que isto ficava borrado de perto)
	gui.LightInfluence = 0
	gui.AutoLocalize = false
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = "🔒"
	label.Parent = gui
	gui.Parent = board
	return m
end

-- ---------------------------------------------------------------------------
-- Granja: cercados das aves, placa da próxima ave e esteiras (as esteiras só com a Fábrica aberta)
-- ---------------------------------------------------------------------------
local function buildPen(plot: Plot, index: number): Instance
	local layout = Layout.Lines[index]
	local line = Config.Lines[index]
	local m = group("Pen" .. index)
	m:SetAttribute("Line", index)
	for _, point in layout.Fence do
		place(plot, m, "Cerca", point)
	end
	for slot = 1, Config.BirdsPerPen do
		local nest = place(plot, m, "Ninho", layout.Nests[slot], nil, false)
		if nest then
			nest:SetAttribute("Slot", slot)
		end
		local bird = place(plot, m, line.Asset, layout.Birds[slot], nil, false)
		if bird then
			bird.Name = "Ave"
			bird:SetAttribute("Line", index)
			bird:SetAttribute("Slot", slot)
			bird:SetAttribute("Phase", index * 1.7 + slot * 0.9)
			CollectionService:AddTag(bird, "VUOHen")
		end
	end
	return m
end

-- placa pequena no cercado da ave que já dá para comprar (o cliente escreve o nome e o preço)
local function buildPreview(plot: Plot, index: number): Instance
	local sign = AssetLib.Get("Placa", 0.5)
	if not sign then
		return group("Pen" .. index .. "_preview")
	end
	local point = Layout.Lines[index].Preview
	sign:PivotTo(Plots.CF(plot, point[1], point[2], point[3]))
	sign:SetAttribute("Line", index)
	CollectionService:AddTag(sign, "VUOPreview")
	return sign
end

local function buildBelt(plot: Plot, index: number): Instance
	local layout = Layout.Lines[index]
	local m = group("Belt" .. index)
	m:SetAttribute("Line", index)
	for _, point in layout.Belt do
		place(plot, m, "Esteira", point)
	end
	place(plot, m, "Esteira_Ponta", layout.BeltCap)
	return m
end

local function buildTrunk(plot: Plot, row: number): Instance
	local m = group("Trunk" .. row)
	for _, point in Layout.Trunk[row + 1].Tiles do
		place(plot, m, "Esteira", point)
	end
	return m
end

local function buildTrunkEnds(plot: Plot, maxRow: number): Instance
	local m = group("TrunkEnds" .. maxRow)
	place(plot, m, "Esteira_Ponta", Layout.Trunk[maxRow + 1].Cap)
	place(plot, m, "Esteira_Ponta", Layout.TrunkFront)
	return m
end

-- trecho da frente do tronco (passa pelas máquinas da Fábrica)
local function buildTrunkFront(plot: Plot): Instance
	local m = group("TrunkFront")
	for _, point in Layout.TrunkFrontTiles do
		place(plot, m, "Esteira", point)
	end
	return m
end

-- ---------------------------------------------------------------------------
-- Botões gerais
-- ---------------------------------------------------------------------------
local GLOBAL_BUILDERS: { [string]: (Plot) -> Instance } = {}

GLOBAL_BUILDERS.G_sign = function(plot)
	local m = group("G_sign")
	signText(place(plot, m, "Placa", Layout.Global.sign.Model), Lang.T("title"), "title")
	return m
end

GLOBAL_BUILDERS.G_tree = function(plot)
	local m = group("G_tree")
	local tree = place(plot, m, "Arvore", Layout.Global.tree.Model)
	if tree then
		tree.Name = "Tree"
		tree:SetAttribute("OwnerId", ownerId(plot))
		CollectionService:AddTag(tree, "VUOTree")
	end
	return m
end

GLOBAL_BUILDERS.G_fence = function(plot)
	local m = group("G_fence")
	for _, point in Layout.Perimeter do
		place(plot, m, "Cerca", point)
	end
	return m
end

GLOBAL_BUILDERS.G_windmill = function(plot)
	local m = group("G_windmill")
	local mill = place(plot, m, "Moinho", Layout.Global.windmill.Model)
	if mill then
		CollectionService:AddTag(mill, "VUOWindmill")
	end
	return m
end

-- Chocadeiras (o ovo em cima e o relógio são desenhados pelo SyncHatch / cliente)
for slot = 1, 3 do
	local id = "G_incubator" .. slot
	GLOBAL_BUILDERS[id] = function(plot)
		local m = group(id)
		local model = place(plot, m, "Chocadeira", Layout.Global["inc" .. slot].Model, nil, true)
		if model then
			model.Name = "Chocadeira"
			model:SetAttribute("Slot", slot)
			CollectionService:AddTag(model, "VUOIncubator")
		end
		return m
	end
end

local function basketLevel(data: any): number
	local level = 0
	for _, def in Config.GlobalButtons do
		if def.Basket and data.Owned["G_" .. def.Kind] then
			level += 1
		end
	end
	return level
end

-- ---------------------------------------------------------------------------
-- Sync: o que deveria existir agora (nome -> função que constrói)
-- ---------------------------------------------------------------------------
local function desired(plot: Plot, data: any): ({ [string]: () -> Instance }, { any })
	local want: { [string]: () -> Instance } = {}
	-- negócios: prédio, e gerente OU tapete de trabalho (a banca não tem tapete: é no clique)
	for index, biz in Config.Businesses do
		local info = Sim.BizInfo(Config, data, index)
		if info.Unlocked then
			want["Biz_" .. biz.Id] = function()
				return buildBiz(plot, index)
			end
			if info.Manager then
				want["Mgr_" .. biz.Id] = function()
					return buildManager(plot, index)
				end
			elseif index >= 2 then
				want["W_" .. biz.Id] = function()
					return makeWorkPad(plot, index)
				end
			end
		elseif Layout.Lots and Layout.Lots[index] then
			-- negócio fechado: o lote trancado fica no lugar dele (some quando o prédio nasce)
			want["Lot_" .. biz.Id] = function()
				return buildLot(plot, index)
			end
		end
	end
	-- enfeites das melhorias compradas
	for id in data.Owned do
		if hasProps(id) then
			want["P_" .. id] = function()
				return buildProps(plot, id)
			end
		end
	end
	-- aves: cercado; esteira do cercado quando a Fábrica está aberta; placa da próxima ave
	local factory = data.Owned.fabrica_unlock == true
	local maxRow = -1
	for index, line in Config.Lines do
		if Sim.HasBird(Config, data, index) then
			want["Pen" .. index] = function()
				return buildPen(plot, index)
			end
			if factory then
				want["Belt" .. index] = function()
					return buildBelt(plot, index)
				end
				maxRow = math.max(maxRow, Layout.Lines[index].Row)
			end
		elseif index > 1 and Sim.ButtonState(Config, data, "ave_" .. line.Id) == "available" then
			want["Pen" .. index .. "_preview"] = function()
				return buildPreview(plot, index)
			end
		end
	end
	-- tronco da esteira: vai até a fileira mais ao fundo que tem ave
	for row = 0, maxRow do
		want["Trunk" .. row] = function()
			return buildTrunk(plot, row)
		end
	end
	if maxRow >= 0 then
		want["TrunkEnds" .. maxRow] = function()
			return buildTrunkEnds(plot, maxRow)
		end
		want.TrunkFront = function()
			return buildTrunkFront(plot)
		end
	end
	for name, builder in GLOBAL_BUILDERS do
		if data.Owned[name] then
			want[name] = function()
				return builder(plot)
			end
		end
	end
	local level = basketLevel(data)
	if level > 0 then
		want["G_basket" .. level] = function()
			local m = group("G_basket" .. level)
			local p = Layout.Global.basket.Model
			place(plot, m, "Cesta", p, p[4] * (0.7 + 0.3 * level), false)
			return m
		end
	end
	local available = Sim.AvailableButtons(Config, data)
	for _, button in available do
		want["B_" .. button.Id] = function()
			return makePad(plot, button)
		end
	end
	return want, available
end

function Plots.Sync(plot: Plot)
	local owner = plot.Owner
	local data = owner and Registry.Game.Data(owner)
	local want, available = {}, {}
	if data then
		want, available = desired(plot, data)
	end
	for _, child in plot.Visuals:GetChildren() do
		-- ovos raros dos ninhos, ovos das chocadeiras, o saco de dinheiro, a chave secreta e o Baú Secreto
		-- têm o próprio Sync (mudam sem compra nenhuma)
		if string.sub(child.Name, 1, 5) == "Rare_" or string.sub(child.Name, 1, 8) == "HatchEgg" or child.Name == "Bag" or child.Name == "Key" or child.Name == "Chest" then
			continue
		end
		if want[child.Name] then
			want[child.Name] = nil
		else
			child:Destroy()
		end
	end
	for name, builder in want do
		local ok, result = pcall(builder)
		if ok and result then
			result.Name = name
			result.Parent = plot.Visuals
		elseif not ok then
			warn("[Plots] não deu para montar " .. name .. ":", result)
		end
	end
	plot.Available = available
	Plots.SyncRare(plot)
	Plots.SyncBag(plot)
	Plots.SyncKey(plot)
	Plots.SyncChest(plot) -- (aparece quando o dono abre a Granja; some ao renascer, junto com a chave)
	Plots.SyncRates(plot)
	Plots.SyncHatch(plot)
	Plots.RefreshVip(plot) -- o brilho VIP acompanha a banca (some ao renascer, volta quando ela reabre)
	if Registry.Tractor then
		Registry.Tractor.Ensure(plot)
	end
end

-- Ovos raros esperando nos ninhos (plot.Run.Rare): um Model "Rare_<ave>_<ninho>" para cada um
function Plots.SyncRare(plot: Plot)
	local owner = plot.Owner
	local data = owner and Registry.Game.Data(owner)
	local want: { [string]: any } = {}
	if data then
		for _, egg in plot.Run.Rare do
			want[("Rare_%d_%d"):format(egg.Line, egg.Slot)] = egg
		end
	end
	for _, child in plot.Visuals:GetChildren() do
		if string.sub(child.Name, 1, 5) == "Rare_" then
			local egg = want[child.Name]
			if egg and child:GetAttribute("Mut") == egg.Mut then
				want[child.Name] = nil
			else
				child:Destroy()
			end
		end
	end
	for name, egg in want do
		local layout = Layout.Lines[egg.Line]
		local nest = layout and layout.Nests[egg.Slot]
		local model = nest and Plots.MakeEgg(egg.Line, egg.Mut)
		if model then
			model.Name = name
			model:SetAttribute("Line", egg.Line)
			model:SetAttribute("Slot", egg.Slot)
			model:SetAttribute("OwnerId", ownerId(plot))
			CollectionService:AddTag(model, "VUORare")
			model:PivotTo(Plots.CF(plot, nest[1], nest[2], egg.Slot * 40, 0.5))
			model.Parent = plot.Visuals
		end
	end
end

-- Saco de dinheiro (plot.Run.Bag): o Model "Bag" no lugar sorteado (Layout.BagSpots). Atributos para o
-- cliente: Golden (dourado?), Until (hora do servidor em que some), OwnerId, BagId. Sem colisão: quem
-- confere se o dono encostou é o Farm, pela posição. Pode chamar quantas vezes quiser.
function Plots.SyncBag(plot: Plot)
	local owner = plot.Owner
	local data = owner and Registry.Game.Data(owner)
	local bag = if data then plot.Run.Bag else nil
	local old = plot.Visuals:FindFirstChild("Bag")
	if old and (not bag or old:GetAttribute("BagId") ~= bag.Id) then
		old:Destroy()
		old = nil
	end
	if not bag or old then
		return
	end
	-- a hora em que ele some, no relógio que o cliente também tem (carimbada uma vez, quando o saco aparece;
	-- antes de montar o modelo: o Tick leva a mesma hora para a tela mesmo se o asset faltar)
	bag.Until = bag.Until or (workspace:GetServerTimeNow() + bag.Left)
	local B = Config.MoneyBag
	local spot = Layout.BagSpots and Layout.BagSpots[bag.Spot]
	local model = spot and AssetLib.Get("Saco_Dinheiro", if bag.Golden then B.GoldenScale else B.Scale)
	if not model then
		return
	end
	AssetLib.SetCollide(model, false)
	model.Name = "Bag"
	model:SetAttribute("BagId", bag.Id)
	model:SetAttribute("Golden", bag.Golden == true)
	model:SetAttribute("Until", bag.Until)
	model:SetAttribute("OwnerId", ownerId(plot))
	CollectionService:AddTag(model, "VUOBag")
	model:PivotTo(Plots.CF(plot, spot[1], spot[2], (bag.Id * 47) % 360, 0.1))
	model.Parent = plot.Visuals
end

-- ---------------------------------------------------------------------------
-- CHAVE SECRETA e BAÚ SECRETO (versão 5; regras em Sim.KeyTick / Sim.TakeKey / Sim.OpenChest, relógio e
-- coleta no Farm). Como o saco: cada um tem o próprio Sync, e pode chamar quantas vezes quiser.
-- ---------------------------------------------------------------------------
local KEY_SIZE = 1.35 -- tamanho da chave (1 = 2,6 studs de altura); grande o bastante para achar no celular
local KEY_HEIGHT = 2.1 -- altura do meio da chave acima do piso (ela flutua; o cliente gira e faz brilhar)

local function keyPart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	if shape then
		part.Shape = shape
	end
	part.Size = size
	part.CFrame = cf
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false -- (sombra no chão entregaria o esconderijo de longe)
	part.Material = Enum.Material.Metal
	part.Reflectance = 0.15
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- A chave: 5 peças simples (nada de asset). De pé, com a argola em cima e os dois dentes embaixo.
-- PrimaryPart = a haste, no meio do modelo: girar o Model em Y gira a chave em torno dela mesma.
local function buildKey(center: CFrame): Model
	local k = KEY_SIZE
	local gold: Color3 = Config.Keys.Color
	local dark = Color3.new(gold.R * 0.55, gold.G * 0.5, gold.B * 0.35)
	local m = group("Key")
	local shaft = keyPart(m, "Haste", Vector3.new(0.3, 1.5, 0.3) * k, center * CFrame.new(0, -0.15 * k, 0), gold)
	-- argola: disco deitado de frente (o cilindro do Roblox tem o eixo em X: o giro vira o eixo para Z) com um
	-- miolo escuro um pouco mais grosso, que faz as vezes do furo
	local faceZ = CFrame.Angles(0, math.rad(90), 0)
	keyPart(m, "Argola", Vector3.new(0.3, 1.25, 1.25) * k, center * CFrame.new(0, 0.85 * k, 0) * faceZ, gold, Enum.PartType.Cylinder)
	keyPart(m, "Furo", Vector3.new(0.34, 0.6, 0.6) * k, center * CFrame.new(0, 0.85 * k, 0) * faceZ, dark, Enum.PartType.Cylinder)
	keyPart(m, "Dente", Vector3.new(0.55, 0.26, 0.3) * k, center * CFrame.new(0.42 * k, -0.77 * k, 0), gold)
	keyPart(m, "Dente", Vector3.new(0.4, 0.26, 0.3) * k, center * CFrame.new(0.35 * k, -0.32 * k, 0), gold)
	m.PrimaryPart = shaft
	return m
end

-- Chave escondida (plot.Run.Key): o Model "Key" no lugar sorteado (Layout.KeySpots). Atributos para o
-- cliente: KeyId (muda a cada chave), OwnerId, Born (hora do servidor em que nasceu: depois de
-- Config.Keys.Hint segundos o cliente faz a chave brilhar forte). Sem colisão e sem consulta: quem confere
-- se o dono chegou perto é o Farm, pela posição.
function Plots.SyncKey(plot: Plot)
	local owner = plot.Owner
	local data = owner and Registry.Game.Data(owner)
	local key = if data then plot.Run.Key else nil
	local old = plot.Visuals:FindFirstChild("Key")
	if old and (not key or old:GetAttribute("KeyId") ~= key.Id) then
		old:Destroy()
		old = nil
	end
	if not key or old then
		return
	end
	-- carimbada uma vez, quando a chave aparece (o cliente conta o tempo da dica a partir daqui)
	key.Born = key.Born or workspace:GetServerTimeNow()
	local spot = Layout.KeySpots and Layout.KeySpots[key.Spot]
	if not spot or not Config.Keys then
		return
	end
	local model = buildKey(Plots.CF(plot, spot[1], spot[2], (key.Id * 67) % 360, KEY_HEIGHT))
	model:SetAttribute("KeyId", key.Id)
	model:SetAttribute("OwnerId", ownerId(plot))
	model:SetAttribute("Born", key.Born)
	CollectionService:AddTag(model, "VUOKey")
	model.Parent = plot.Visuals
end

-- Baú Secreto: o Model "Chest" (asset "Bau") no lugar fixo do terreno (Layout.KeyChest), enquanto o dono
-- tiver as chaves liberadas (Sim.KeysOpen). Atributos para o cliente: OwnerId, Keys (chaves na mão do
-- dono) e Need (quantas abrem). Sem colisão: fica ao lado do portão e nasce com o jogador em qualquer lugar
-- (parede que surge do nada dá tranco no boneco); quem abre é o Farm, pela posição do dono.
function Plots.SyncChest(plot: Plot)
	local owner = plot.Owner
	local data = owner and Registry.Game.Data(owner)
	local point = Layout.KeyChest
	local want = data ~= nil and point ~= nil and Config.Keys ~= nil and Sim.KeysOpen(Config, data)
	local chest = plot.Visuals:FindFirstChild("Chest")
	if not want then
		if chest then
			chest:Destroy()
		end
		return
	end
	if not chest then
		local model = AssetLib.Get("Bau", point[4])
		if not model then
			return
		end
		AssetLib.SetCollide(model, false)
		model.Name = "Chest"
		model:PivotTo(Plots.CF(plot, point[1], point[2], point[3]))
		CollectionService:AddTag(model, "VUOChest")
		model.Parent = plot.Visuals
		chest = model
	end
	setAttr(chest, "OwnerId", ownerId(plot))
	setAttr(chest, "Keys", Sim.KeyCount(Config, data))
	setAttr(chest, "Need", Config.Keys.Need)
end

-- Chocadeiras: o ovo em cima de cada uma e os atributos que o cliente usa para o relógio
-- (atributo "Hatch<vaga>" = "chave|hora do servidor em que nasce", ou "" se vazia)
function Plots.SyncHatch(plot: Plot)
	local owner = plot.Owner
	local data = owner and Registry.Game.Data(owner)
	local now = os.time()
	local serverNow = workspace:GetServerTimeNow()
	for slot = 1, 3 do
		local hatch = data and data.Hatch[tostring(slot)]
		local owned = data ~= nil and data.Owned["G_incubator" .. slot] == true
		local value = ""
		if hatch and owned then
			value = ("%s|%d"):format(hatch.Key, math.floor(serverNow + (hatch.Ready - now)))
		end
		local name = "HatchEgg" .. slot
		local old = plot.Visuals:FindFirstChild(name)
		if old and (value == "" or old:GetAttribute("Key") ~= (hatch and hatch.Key)) then
			old:Destroy()
			old = nil
		end
		if value ~= "" and not old and hatch then
			local lineId, mut = Sim.ParseKey(hatch.Key)
			local line = Config.LineById[lineId]
			local egg = line and Plots.MakeEgg(line.Index, mut)
			if egg then
				local point = Layout.Global["inc" .. slot].Model
				egg.Name = name
				egg:SetAttribute("Key", hatch.Key)
				egg:PivotTo(Plots.CF(plot, point[1], point[2], 0, 3.0))
				egg.Parent = plot.Visuals
			end
		end
		setAttr(plot.Model, "Hatch" .. slot, value)
	end
end

-- ---------------------------------------------------------------------------
-- Atributos em plot.Model (seção 3.2 da especificação): o cliente desenha a partir deles
-- ---------------------------------------------------------------------------
-- Ciclo manual: endsAt = workspace:GetServerTimeNow() em que termina (0 = nenhum), len = duração.
-- Guarda também a senha do ciclo (plot.Run.Work[i]) para o SyncRates saber se ele ainda vale.
function Plots.SetWork(plot: Plot, index: number, endsAt: number, len: number)
	local token = plot.Run.Work[index]
	if endsAt > 0 and token ~= nil then
		plot.Work[index] = { Token = token, EndsAt = endsAt, Len = len }
	else
		plot.Work[index] = nil
		endsAt, len = 0, 0
	end
	setAttr(plot.Model, "Work" .. index, endsAt)
	setAttr(plot.Model, "WorkLen" .. index, len)
end

-- Moedas no chão do negócio (0 = nada)
function Plots.SetGround(plot: Plot, index: number, amount: number?)
	setAttr(plot.Model, "Ground" .. index, amount or 0)
end

-- Gorjetas no chão da banca
function Plots.SetTips(plot: Plot, n: number?)
	setAttr(plot.Model, "Tips", n or 0)
end

function Plots.SyncRates(plot: Plot)
	local owner = plot.Owner
	local data = owner and Registry.Game.Data(owner)
	local ctx = owner and Registry.Game.Ctx(owner)
	local model = plot.Model
	local run = plot.Run
	local speed = if data then Sim.SpeedMult(Config, data, ctx) else 1
	for index in Config.Businesses do
		local state, rate = 0, 0
		if data then
			local info = Sim.BizInfo(Config, data, index)
			if info.Unlocked then
				state = if info.Manager then 2 else 1
				rate = 1 / Sim.CycleTime(Config, data, ctx, index, info, speed)
			end
		end
		setAttr(model, "Biz" .. index, state)
		setAttr(model, "Rate" .. index, rate)
		-- ciclo manual: só vale enquanto a senha dele for a que está no run (renascer zera o run)
		local work = plot.Work[index]
		if work and (not data or run.Work[index] ~= work.Token) then
			plot.Work[index] = nil
			work = nil
		end
		setAttr(model, "Work" .. index, if work then work.EndsAt else 0)
		setAttr(model, "WorkLen" .. index, if work then work.Len else 0)
		setAttr(model, "Ground" .. index, if data then run.Ground[index] or 0 else 0)
	end
	local birds, vans, machines, barn = 0, 0, 0, 0
	if data then
		birds = Sim.BirdCount(Config, data)
		if data.Owned.entrega_unlock then
			vans = 1 + (if data.Owned.entrega_van2 then 1 else 0) + (if data.Owned.entrega_van3 then 1 else 0)
		end
		-- as melhorias de dinheiro da Fábrica são as 4 máquinas; as do Depósito são as etapas do celeiro
		machines = Sim.BizInfo(Config, data, Config.BizById.fabrica.Index).CashStep
		local deposit = Sim.BizInfo(Config, data, Config.BizById.deposito.Index)
		if deposit.Unlocked then
			barn = 1 + deposit.CashStep
		end
	end
	setAttr(model, "Tips", if data then run.Tips or 0 else 0)
	setAttr(model, "Birds", birds)
	setAttr(model, "Vans", vans)
	setAttr(model, "Machines", machines)
	setAttr(model, "BarnStage", barn)
	setAttr(model, "Apples", if data then run.Apples else 0)
end

-- O dono tem o passe VIP? (aparece para todo mundo: placa do nome e brilho na banca)
local function ownerVip(plot: Plot): boolean
	local owner = plot.Owner
	return owner ~= nil and Registry.Game.HasPass(owner, "VIP")
end

-- Brilho dourado do VIP em cima da banca (Model "VIPFx" direto no terreno, fora de plot.Visuals: o Sync
-- não mexe nele). Existe enquanto o dono for VIP e a banca estiver aberta. Feito no servidor: todos veem.
function Plots.RefreshVip(plot: Plot)
	local owner = plot.Owner
	local data = owner and Registry.Game.Data(owner)
	local want = data ~= nil and data.Owned.banca_unlock == true and ownerVip(plot)
	setAttr(plot.Model, "VIP", ownerVip(plot))
	local old = plot.Model:FindFirstChild("VIPFx")
	if not want then
		if old then
			old:Destroy()
		end
		return
	end
	if old then
		return
	end
	local color = Config.VIP.Color
	local s = Layout.Stand
	local m = group("VIPFx")
	local part = Instance.new("Part")
	part.Name = "Glow"
	part.Size = Vector3.new(9, 0.4, 5)
	part.CFrame = Plots.CF(plot, s[1], s[2], s[3], 9)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 16
	light.Brightness = 0.9
	light.Parent = part
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(color)
	sparkle.Size = NumberSequence.new(0.7, 0)
	sparkle.Lifetime = NumberRange.new(1, 1.8)
	sparkle.Rate = 8
	sparkle.Speed = NumberRange.new(1, 2.5)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.LightEmission = 1
	sparkle.Parent = part
	-- coroa flutuando em cima da banca
	local gui = Instance.new("BillboardGui")
	gui.Name = "Crown"
	gui.Size = UDim2.fromScale(5, 2.2)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	gui.Adornee = part
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.fromRGB(70, 38, 15)
	label.TextStrokeTransparency = 0
	label.Text = "👑 VIP"
	label.Parent = gui
	gui.Parent = part
	part.Parent = m
	m.Parent = plot.Model
end

function Plots.RefreshSign(plot: Plot)
	local plate = plot.Model:FindFirstChild("NamePlate")
	local sign = plate and plate:FindFirstChild("Sign")
	local gui = sign and sign:FindFirstChildWhichIsA("SurfaceGui")
	local label = gui and gui:FindFirstChildWhichIsA("TextLabel")
	local owner = plot.Owner
	local data = owner and Registry.Game.Data(owner)
	if label then
		if owner then
			-- dono VIP: coroa na frente do nome (é o que os outros jogadores veem ao passar)
			label.Text = ("%s%s\n❤ %d"):format(if ownerVip(plot) then "👑 " else "", owner.DisplayName, if data then data.Likes else 0)
		else
			label.Text = "🥚"
		end
	end
	plot.Model:SetAttribute("OwnerId", if owner then owner.UserId else 0)
	plot.Model:SetAttribute("Seal", if data then data.Seal else 0)
	Plots.RefreshVip(plot)
end

-- ---------------------------------------------------------------------------
function Plots.Assign(player: Player): Plot?
	if byPlayer[player] then
		return byPlayer[player]
	end
	for _, plot in plots do
		if not plot.Owner then
			plot.Owner = player
			byPlayer[player] = plot
			plot.Run = Sim.NewRun()
			plot.Hold = {}
			plot.Work = {}
			plot.LastBuy = 0
			plot.LikedBy = {}
			Plots.RefreshSign(plot)
			Plots.Sync(plot)
			return plot
		end
	end
	return nil
end

function Plots.Release(player: Player)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	byPlayer[player] = nil
	plot.Owner = nil
	-- run novo: os ciclos manuais que ainda estavam esperando (task.delay no Farm) deixam de valer
	plot.Run = Sim.NewRun()
	plot.Available = {}
	plot.Hold = {}
	plot.Work = {}
	for _, child in plot.Visuals:GetChildren() do
		child:Destroy()
	end
	Plots.RefreshSign(plot)
	Plots.SyncRates(plot)
	Plots.SyncHatch(plot)
	if Registry.Tractor then
		Registry.Tractor.Ensure(plot)
	end
end

-- Renascer/Selo: o Sim já zerou o run (moedas no chão, ovos raros, senhas de trabalho); redesenha tudo
function Plots.Reset(plot: Plot)
	plot.Hold = {}
	plot.Work = {}
	Plots.RefreshSign(plot)
	Plots.Sync(plot)
end

function Plots.Init()
	local root = workspace:WaitForChild("Plots")
	local models = root:GetChildren()
	table.sort(models, function(a, b)
		return (a:GetAttribute("Index") or 0) < (b:GetAttribute("Index") or 0)
	end)
	for _, model in models do
		local origin = model:IsA("Model") and model:FindFirstChild("PlotOrigin")
		if not origin or not origin:IsA("BasePart") then
			continue
		end
		local visuals = Instance.new("Folder")
		visuals.Name = "Visuals"
		visuals.Parent = model
		local plot: Plot = {
			Index = model:GetAttribute("Index") or (#plots + 1),
			Model = model :: Model,
			Origin = origin.CFrame,
			Owner = nil,
			Visuals = visuals,
			Run = Sim.NewRun(),
			Available = {},
			Hold = {},
			Work = {},
			LastBuy = 0,
			LikedBy = {},
		}
		-- curtir a granja (só aparece para quem NÃO é o dono; o cliente esconde do dono)
		local plate = model:FindFirstChild("NamePlate")
		local sign = plate and plate:FindFirstChild("Sign")
		if sign then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "Like"
			prompt.ActionText = "👍"
			prompt.ObjectText = "❤"
			prompt.HoldDuration = 0.3
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt:SetAttribute("PlotIndex", plot.Index)
			prompt.Parent = sign
			CollectionService:AddTag(prompt, "VUOLike")
			prompt.Triggered:Connect(function(player)
				Registry.Shop.Like(player, plot)
			end)
		end
		table.insert(plots, plot)
		Plots.RefreshSign(plot)
		-- os atributos existem desde o começo (zerados), para o cliente não precisar tratar "nil"
		Plots.SyncRates(plot)
		Plots.SyncHatch(plot)
	end
end

return Plots
