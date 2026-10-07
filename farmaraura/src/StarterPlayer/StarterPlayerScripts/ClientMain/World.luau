--[[
	World (versão 4): tudo que o jogador vê NO MAPA e que é só visual. Roda no cliente e NUNCA mexe em dinheiro:
	o servidor cria as peças (botões, tapetes, prédios, ovos raros) e publica atributos no terreno; aqui a gente
	só pinta, escreve e anima a partir deles.

	O que mora aqui:
	  botões do chão (corpo 3D verde/vermelho, ícone, plaquinha do preço)   tapetes de trabalho (barra de progresso)
	  placa de cada negócio (renda, ciclo, estado)     moedas e gorjetas no chão
	  fregueses na banca e na omeleteria               vans, caminhão, esteira da fábrica, foguete
	  fumaça da chaminé, bolhas do laboratório         fazendeiro da granja, ovos raros nos ninhos
	  lotes trancados (plaquinha de cada negócio que ainda vai abrir)       saco de dinheiro (facho de luz)
	  seta de ajuda, pets, chocadeiras, Mega Ovo, roleta, baú, moinhos, eventos, textos e moedas voando
	  versão 5: clima (luz, céu, partículas, arco-íris, selo nos prédios ajudados), chave secreta e Baú
	  Secreto de cada terreno, efeitos dos poderes (blocos 13d, 15 e 16)

	Regras da casa (para funcionar em celular fraco):
	  * tudo que anima olha a distância até a câmera e para quando está longe;
	  * tudo tem teto de quantidade (moedas, fregueses, ovos na esteira, efeitos);
	  * o que é de um terreno some quando o terreno fica sem dono ou sai de perto;
	  * nada depende de peças internas dos modelos, só das nomeadas na especificação (os modelos podem virar malha);
	  * as instâncias chegam e somem a qualquer momento (replicação): tudo confere nil e roda protegido.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetLib = require(Shared:WaitForChild("AssetLib"))
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Lang = require(Shared:WaitForChild("Lang"))
local Layout = require(Shared:WaitForChild("Layout"))
local Sim = require(Shared:WaitForChild("Sim"))
local UI = require(script.Parent:WaitForChild("UI"))

local World = {}

World.ArrowOn = true
-- v6: Modo leve (Configurações): sem partículas, aves paradas e sem pets dos outros. Para celular fraco.
World.Light = false
local lightConn: RBXScriptConnection? = nil

local function lightFx(object: Instance, on: boolean)
	if object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam") then
		if on then
			if object:GetAttribute("LightWas") == nil then
				object:SetAttribute("LightWas", (object :: any).Enabled)
			end
			(object :: any).Enabled = false
		elseif object:GetAttribute("LightWas") ~= nil then
			(object :: any).Enabled = object:GetAttribute("LightWas")
			object:SetAttribute("LightWas", nil)
		end
	end
end

function World.SetLight(on: boolean)
	if World.Light == on then
		return
	end
	World.Light = on
	for _, object in workspace:GetDescendants() do
		lightFx(object, on)
	end
	if lightConn then
		lightConn:Disconnect()
		lightConn = nil
	end
	if on then
		lightConn = workspace.DescendantAdded:Connect(function(object)
			task.defer(lightFx, object, true)
		end)
	end
	if World.ResetPets then
		World.ResetPets()
	end
end
World.OnWheel = nil :: (() -> ())? -- a tela liga aqui: abrir a roleta

local player = Players.LocalPlayer
local C = UI.C
local new = UI.New
local T = Lang.T
local short = Format.Short

local state: any = nil
local fxFolder: Folder

local NUM_BIZ = #Config.Businesses
local LBIZ: { any } = Layout.Biz or {} -- pontos de cada negócio (vazio se o Layout for antigo: aí nada da v4 é desenhado)
local HAS_V4 = #LBIZ >= NUM_BIZ
local PLOT_Z0: number = if Layout.Size then Layout.Size[2] else -122 -- frente do terreno (depois disso é a estrada)
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

-- nomes dos atributos do terreno, montados uma vez (para não criar texto novo a cada leitura)
local ATTR = { Biz = {}, Rate = {}, Work = {}, WorkLen = {}, Ground = {} }
for i = 1, NUM_BIZ do
	ATTR.Biz[i] = "Biz" .. i
	ATTR.Rate[i] = "Rate" .. i
	ATTR.Work[i] = "Work" .. i
	ATTR.WorkLen[i] = "WorkLen" .. i
	ATTR.Ground[i] = "Ground" .. i
end

local GOLD = Color3.fromRGB(255, 200, 40)
local GREEN = Color3.fromRGB(64, 222, 84)
local PLATE = Color3.fromRGB(22, 24, 34)
local TEXT_GREEN = Color3.fromRGB(110, 240, 120)
local TEXT_RED = Color3.fromRGB(255, 105, 95)
local TEXT_YELLOW = Color3.fromRGB(255, 220, 80)

-- ---------------------------------------------------------------------------
-- Ajudantes gerais
-- ---------------------------------------------------------------------------
local function num(value: any): number
	return if type(value) == "number" then value else 0
end

-- Um erro num pedaço do desenho não pode derrubar o resto: roda protegido e avisa UMA vez por erro.
local warned: { [string]: boolean } = {}
local function safe(name: string, fn: (...any) -> ...any, ...: any)
	local ok, err = pcall(fn, ...)
	if not ok then
		local message = name .. ": " .. tostring(err)
		if not warned[message] then
			warned[message] = true
			warn("[World] " .. message)
		end
	end
end

local function rootPart(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function originOf(plot: Instance): CFrame?
	local origin = plot:FindFirstChild("PlotOrigin")
	if origin and origin:IsA("BasePart") then
		return origin.CFrame
	end
	return nil
end

local function plotOf(inst: Instance): Instance?
	local current = inst.Parent
	while current and current ~= workspace do
		if current:GetAttribute("Index") ~= nil and current.Parent and current.Parent.Name == "Plots" then
			return current
		end
		current = current.Parent
	end
	return nil
end

-- posição da câmera, lida uma vez por quadro
local eye = Vector3.new(0, 0, 0)
-- quantos pixels tem 1 stud a 1 stud da câmera (a "d" studs: pxStud / d). Depende do tamanho da tela:
-- num celular a mesma placa fica com metade dos pixels de um PC, então as distâncias das placas saem daqui.
local pxStud = 514
local function updateEye()
	local camera = workspace.CurrentCamera
	if camera then
		eye = camera.CFrame.Position
		local height = camera.ViewportSize.Y
		if height > 50 then
			pxStud = height / (2 * math.tan(math.rad(math.clamp(camera.FieldOfView, 20, 120)) / 2))
		end
	end
end

local function fxPart(props: { [string]: any }): Part
	local base: { [string]: any } = { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }
	for key, value in props do
		base[key] = value
	end
	return new("Part", base)
end

local function anchor(position: Vector3): Part
	return fxPart({ Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), Position = position, Parent = fxFolder })
end

-- Solta "count" partículas de uma vez num emissor RECÉM-CRIADO. No Roblox, o Emit chamado no mesmo quadro em que
-- o emissor entrou no mundo pode não soltar nada: fica para o quadro seguinte (se ele ainda existir).
local function burst(emitter: ParticleEmitter, count: number)
	task.delay(0.03, function()
		if emitter.Parent then
			emitter:Emit(count)
		end
	end)
end

-- peças de um modelo (para sumir/aparecer aos poucos sem depender do nome de nenhuma)
local function partsOf(model: Instance): { BasePart }
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

local function setAlpha(item: any, alpha: number)
	alpha = math.floor(math.clamp(alpha, 0, 1) * 8 + 0.5) / 8 -- em degraus: só mexe nas peças quando muda de verdade
	if item.Alpha ~= alpha then
		item.Alpha = alpha
		for _, part in item.Parts do
			part.LocalTransparencyModifier = alpha
		end
	end
end

-- "pulo" com passadinha do alvo (para coisas que aparecem com um pop)
local function backOut(a: number): number
	a = math.clamp(a, 0, 1) - 1
	return 1 + 2.70158 * a * a * a + 1.70158 * a * a
end

local function nearestRoot(at: Vector3, radius: number): BasePart?
	local best: BasePart? = nil
	local bestDist = radius
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local d = (root.CFrame.Position - at).Magnitude
			if d < bestDist then
				best, bestDist = root, d
			end
		end
	end
	return best
end

-- ---------------------------------------------------------------------------
-- Retrato de cada terreno: os atributos que o servidor publica, lidos algumas vezes por segundo
-- (em vez de centenas de GetAttribute por quadro). Os desenhos do terreno ficam pendurados aqui também,
-- então quando o terreno some dá para limpar tudo de uma vez.
-- ---------------------------------------------------------------------------
local snaps: { [Instance]: any } = {}
local mine: any = nil -- retrato do MEU terreno (nil se ainda não tenho)

local function newSnap(plot: Instance, origin: CFrame): any
	local s: any = {
		Plot = plot,
		Origin = origin,
		Owner = 0,
		Mine = false,
		Biz = table.create(NUM_BIZ, 0),
		Rate = table.create(NUM_BIZ, 0),
		Work = table.create(NUM_BIZ, 0),
		WorkLen = table.create(NUM_BIZ, 0),
		Ground = table.create(NUM_BIZ, 0),
		Tips = 0,
		Birds = 0,
		Vans = 0,
		Machines = 0,
		BarnStage = 0,
		Cash = {}, -- ponto das moedas de cada negócio (mundo)
		Piles = {}, -- montes de moedas no chão
	}
	local function at(point: { number }, y: number?): Vector3
		return origin:PointToWorldSpace(Vector3.new(point[1], y or 0, point[2]))
	end
	s.StandAt = at(Layout.Stand or { 0, -98 })
	s.PensAt = at({ 0, 48 })
	s.TrunkAt = at({ 0, -20 })
	if HAS_V4 then
		for i = 1, NUM_BIZ do
			s.Cash[i] = at(LBIZ[i].Cash)
		end
		s.GarageAt = at(LBIZ[3].Model)
		s.DinerAt = at(LBIZ[6].Model)
		s.LabAt = at(LBIZ[7].Model)
		s.RocketAt = at(LBIZ[8].Model, Layout.RocketY or 2)
	end
	return s
end

local function readSnap(s: any)
	local plot = s.Plot
	s.Owner = num(plot:GetAttribute("OwnerId"))
	s.Mine = s.Owner ~= 0 and s.Owner == player.UserId
	for i = 1, NUM_BIZ do
		s.Biz[i] = num(plot:GetAttribute(ATTR.Biz[i]))
		s.Rate[i] = num(plot:GetAttribute(ATTR.Rate[i]))
		s.Work[i] = num(plot:GetAttribute(ATTR.Work[i]))
		s.WorkLen[i] = num(plot:GetAttribute(ATTR.WorkLen[i]))
		s.Ground[i] = num(plot:GetAttribute(ATTR.Ground[i]))
	end
	s.Tips = num(plot:GetAttribute("Tips"))
	s.Birds = num(plot:GetAttribute("Birds"))
	s.Vans = num(plot:GetAttribute("Vans"))
	s.Machines = num(plot:GetAttribute("Machines"))
	s.BarnStage = num(plot:GetAttribute("BarnStage"))
end

-- O negócio i está rodando agora? (com gerente, ou com um ciclo na mão em andamento)
local function running(s: any, i: number, now: number): boolean
	local b = s.Biz[i]
	return b == 2 or (b == 1 and s.Work[i] > now)
end

-- Fração 0..1 do ciclo na mão do negócio i (nil se não há ciclo). Segura "cheio" por um instante depois do
-- fim, porque o ciclo seguinte demora um pouquinho para chegar pela rede (senão a barra pisca).
local function workFraction(s: any, i: number, now: number): number?
	local ends, length = s.Work[i], s.WorkLen[i]
	if ends <= 0 or length <= 0 then
		return nil
	end
	local left = ends - now
	if left > 0 then
		return math.clamp(1 - left / length, 0, 1)
	elseif left > -0.45 then
		return 1
	end
	return nil
end

-- Acabou um ciclo na mão? Vale tanto se o servidor zera o atributo no fim quanto se deixa a hora antiga lá.
local function cycleDone(tracker: any, ends: number, now: number): boolean
	local done = false
	if ends ~= tracker.End then
		if tracker.End > 0 and not tracker.Fired and now >= tracker.End - 0.4 then
			done = true
		end
		tracker.End = ends
		tracker.Fired = false
	end
	if tracker.End > 0 and not tracker.Fired and now >= tracker.End then
		tracker.Fired = true
		done = true
	end
	return done
end

-- ---------------------------------------------------------------------------
-- Plaquinhas (BillboardGui). Padrão novo, por causa dos textos "bugados" da versão 3:
--   * tamanho em STUDS (a placa é um objeto do mundo: nunca invade o vizinho);
--   * FUNDO escuro arredondado (dá para ler contra qualquer cenário);
--   * NENHUM UIStroke (a espessura dele é em pixels: de longe engolia a letra e virava borrão);
--   * cada linha tem a SUA caixa com TextScaled: o texto encolhe para caber, nunca corta nem sobrepõe.
-- ---------------------------------------------------------------------------
local function billboard(props: { [string]: any }): BillboardGui
	local base: { [string]: any } = { LightInfluence = 0, AutoLocalize = false, ClipsDescendants = false, ResetOnSpawn = false }
	for key, value in props do
		base[key] = value
	end
	return new("BillboardGui", base)
end

-- StudsOffsetWorldSpace é medido nos eixos DA PEÇA (não do mundo). Os botões e tapetes são cilindros deitados
-- (o "para cima" deles aponta para o lado): sem esta conversão a placa saía ao lado do botão, rente ao chão.
local function liftOf(adornee: Instance?, lift: number): Vector3
	if adornee and adornee:IsA("BasePart") then
		return adornee.CFrame:VectorToObjectSpace(Vector3.new(0, lift, 0))
	end
	return Vector3.new(0, lift, 0)
end

local function corner(radius: number): UICorner
	return new("UICorner", { CornerRadius = UDim.new(radius, 0) })
end

local function plateBg(parent: Instance, transparency: number?, radius: number?): Frame
	return new("Frame", {
		Name = "Bg",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = PLATE,
		BackgroundTransparency = transparency or 0.2,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = parent,
	}, { corner(radius or 0.2) })
end

local function plateText(parent: Instance, props: { [string]: any }): TextLabel
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		Font = UI.Font,
		TextScaled = true,
		TextColor3 = C.White,
		TextStrokeTransparency = 0.45, -- contorno do próprio texto: acompanha o tamanho da letra (não é UIStroke)
		TextStrokeColor3 = Color3.fromRGB(10, 10, 16),
		Text = "",
		ZIndex = 2,
		Parent = parent,
	}
	for key, value in props do
		base[key] = value
	end
	return new("TextLabel", base)
end

local function ulen(text: string): number
	return utf8.len(text) or #text
end

-- ---------------------------------------------------------------------------
-- Textos que sobem, moedas voando, fumaça de compra
-- ---------------------------------------------------------------------------
local coins, MAX_COINS, stepCoins, throw, stepArcs, stepFlyers, collectParts
do
	function World.FloatText(position: Vector3?, text: string, color: Color3)
		if not position then
			local root = rootPart()
			if not root then
				return
			end
			position = root.CFrame.Position + Vector3.new(0, 4, 0)
		end
		local a = anchor(position :: Vector3)
		-- tamanho em pixels (não em studs): aqui o contorno é do próprio texto e acompanha a letra
		local bb = billboard({ Size = UDim2.new(0, 240, 0, 56), AlwaysOnTop = true, Adornee = a, Parent = a })
		local l = plateText(bb, { Size = UDim2.fromScale(1, 1), Text = text, TextColor3 = color, TextStrokeTransparency = 0.25, TextStrokeColor3 = C.DarkBrown })
		new("UITextSizeConstraint", { MaxTextSize = 40, MinTextSize = 8, Parent = l })
		TweenService:Create(a, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = (position :: Vector3) + Vector3.new(0, 6, 0) }):Play()
		TweenService:Create(l, TweenInfo.new(1.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.delay(1.5, function()
			a:Destroy()
		end)
	end

	-- peças soltas com "física" de mentira (moedas, cascas, caixas): sobem, caem e somem
	coins = {}
	MAX_COINS = 60

	function World.CoinBurst(position: Vector3?, amount: number)
		if not position then
			local root = rootPart()
			if not root then
				return
			end
			position = root.CFrame.Position + Vector3.new(0, 3, 0)
		end
		for _ = 1, math.min(amount, 16) do
			if #coins >= MAX_COINS then
				break
			end
			local coin = fxPart({
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.18, 0.9, 0.9),
				Color = C.Yellow,
				Material = Enum.Material.Neon,
				CFrame = CFrame.new(position :: Vector3) * CFrame.Angles(math.random() * 6, math.random() * 6, 0),
				Parent = fxFolder,
			})
			table.insert(coins, { Part = coin, Velocity = Vector3.new((math.random() - 0.5) * 16, 14 + math.random() * 10, (math.random() - 0.5) * 16), Life = 0.9 })
		end
	end

	function stepCoins(dt: number)
		for i = #coins, 1, -1 do
			local coin = coins[i]
			coin.Life -= dt
			if coin.Life <= 0 then
				coin.Part:Destroy()
				table.remove(coins, i)
			else
				coin.Velocity -= Vector3.new(0, 60 * dt, 0)
				coin.Part.CFrame = (coin.Part.CFrame + coin.Velocity * dt) * CFrame.Angles(dt * 9, 0, dt * 7)
			end
		end
	end

	function World.Puff(position: Vector3, color: Color3?)
		local a = anchor(position)
		local emitter = new("ParticleEmitter", {
			Texture = SPARK,
			Color = ColorSequence.new(color or C.Yellow),
			Size = NumberSequence.new(1.2, 0),
			Lifetime = NumberRange.new(0.5, 0.9),
			Speed = NumberRange.new(8, 14),
			SpreadAngle = Vector2.new(180, 180),
			LightEmission = 1,
			Rate = 0,
			Parent = a,
		})
		burst(emitter, 24)
		task.delay(1.2, function()
			a:Destroy()
		end)
	end

	-- "puf" de fumaça/poeira (o saco de dinheiro que sumiu, a obra do lote que virou prédio)
	function World.Poof(position: Vector3, color: Color3?)
		local a = anchor(position)
		local emitter = new("ParticleEmitter", {
			Texture = SMOKE,
			Color = ColorSequence.new(color or Color3.fromRGB(225, 225, 230)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 4.5) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.6, 1.1),
			Speed = NumberRange.new(4, 9),
			SpreadAngle = Vector2.new(180, 180),
			Rate = 0,
			Parent = a,
		})
		burst(emitter, 14)
		task.delay(1.4, function()
			a:Destroy()
		end)
	end

	function World.Ping(position: Vector3, color: Color3)
		local ring = fxPart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 2, 2),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.2,
			CFrame = CFrame.new(position - Vector3.new(0, 4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Parent = fxFolder,
		})
		TweenService:Create(ring, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.3, 34, 34), Transparency = 1 }):Play()
		task.delay(1, function()
			ring:Destroy()
		end)
	end

	-- Coisas pequenas que fazem um arco de A até B (o ovo que sai do balcão, a moeda que cai no chão).
	-- As peças são reaproveitadas (clicar rápido na banca não pode criar e destruir peça sem parar).
	local arcs: { any } = {}
	local arcPool: { [string]: { Part } } = { egg = {}, coin = {} }
	local MAX_ARCS = 24

	function throw(kind: string, from: Vector3, to: Vector3, duration: number, height: number)
		if #arcs >= MAX_ARCS then
			return
		end
		local part = table.remove(arcPool[kind])
		if not part then
			if kind == "egg" then
				part = fxPart({ Name = "OvoFx", Shape = Enum.PartType.Ball, Size = Vector3.new(0.95, 0.95, 0.95), Color = Color3.fromRGB(250, 240, 220), Material = Enum.Material.SmoothPlastic })
			else
				part = fxPart({ Name = "MoedaFx", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 1.15, 1.15), Color = GOLD, Material = Enum.Material.Neon })
			end
		end
		local p = part :: Part
		p.CFrame = CFrame.new(from)
		p.Parent = fxFolder
		table.insert(arcs, { Part = p, Kind = kind, From = from, To = to, T = 0, Dur = math.max(duration, 0.05), H = height })
	end

	function stepArcs(dt: number)
		for i = #arcs, 1, -1 do
			local a = arcs[i]
			a.T += dt
			local k = a.T / a.Dur
			if k >= 1 then
				a.Part.Parent = nil
				table.insert(arcPool[a.Kind], a.Part)
				table.remove(arcs, i)
			else
				local p = a.From:Lerp(a.To, k) + Vector3.new(0, 4 * a.H * k * (1 - k), 0)
				a.Part.CFrame = CFrame.new(p) * CFrame.Angles(k * 9, k * 7, 0)
			end
		end
	end

	-- moedas "puxadas" para quem pegou (efeito de coleta)
	local flyers: { any } = {}
	local MAX_FLYERS = 40

	function stepFlyers(dt: number)
		for i = #flyers, 1, -1 do
			local f = flyers[i]
			f.T += dt
			if f.T >= 0 then
				local k = f.T / f.Dur
				local target = f.Target
				if target and target.Parent then
					f.To = target.CFrame.Position
				end
				if k >= 1 then
					f.Part:Destroy()
					table.remove(flyers, i)
				else
					local p = f.From:Lerp(f.To, k * k) + Vector3.new(0, math.sin(k * math.pi) * 2.6, 0)
					f.Part.CFrame = CFrame.new(p) * CFrame.Angles(0, f.T * 14, 0)
				end
			end
		end
	end

	-- As moedas de um monte somem: voam para quem está perto (quem pegou) ou pulam e desaparecem.
	function collectParts(list: { any }, at: Vector3)
		local target = nearestRoot(at, 30)
		local used = 0
		for _, coin in list do
			local part = coin.Part
			if target and used < 8 and #flyers < MAX_FLYERS then
				used += 1
				table.insert(flyers, { Part = part, From = part.CFrame.Position, To = target.CFrame.Position, Target = target, T = -0.03 * used, Dur = 0.32 })
			elseif used < 8 and #coins < MAX_COINS then
				used += 1
				table.insert(coins, { Part = part, Velocity = Vector3.new((math.random() - 0.5) * 10, 16 + math.random() * 8, (math.random() - 0.5) * 10), Life = 0.5 })
			else
				part:Destroy()
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- 1. BOTÕES DO CHÃO (tag VUOButton)
-- O servidor cria um disco liso (cilindro deitado, 5,4 de diâmetro e 0,5 de altura, sem colisão). Aqui ele ganha
-- cara de botão de tycoon, com peças LOCAIS que moram dentro dele (somem junto quando o servidor o apaga):
--   Rim     aro escuro mais largo, rente ao chão (contraste com a grama). DOURADO e aceso no botão da vez.
--   Kind    anel fino na COR DO TIPO, entre o aro e o botão: abrir negócio = branco, gerente = azul,
--           +dinheiro = ciano, +velocidade = laranja, ave = rosa, geral = roxo. (Nunca verde, vermelho nem
--           dourado: essas três cores são só do estado e do botão da vez.)
--   (o disco do servidor vira a LATERAL do botão: a cor do estado, mais escura)
--   Cap     tampa na cor viva do estado;   Shine  anel claro em cima dela, ACESO (Neon) quando dá para comprar
--           (dourado no botão da vez);     Dome   miolo abaulado, também aceso quando dá;
--   Art     o ícone do item deitado em cima (para quem olha de cima);
--   Float   o MESMO ícone de pé, flutuando acima do botão e girando devagar (duas faces): é o que se
--           reconhece de longe. No botão da vez ele é maior e quica. Some enquanto o dono está em cima.
--   Pulse   onda que sai do botão quando dá para comprar (verde; dourada no botão da vez).
-- Estados: VERDE vivo = o dono pode pagar (pulsa de leve); VERMELHO = ainda não; cinza = terreno dos outros.
-- O botão DA VEZ (state.Next: o que a fila manda comprar) tem aro e anel dourados, selo "PRÓXIMO!" na plaquinha,
-- o ícone quicando e umas faíscas (UMA peça no jogo inteiro, em VUOFx.PadNextFx, que muda de botão; nenhum
-- emissor fica ligado: quem solta as faíscas, poucas por vez, é a varredura das placas, e só de perto).
-- Com o dono em cima a tampa afunda. Na compra (World.PadBought, chamado pelo Fx "buy") a tampa afunda de vez,
-- sai um anel, confete e (para quem comprou) umas moedinhas: o botão de verdade já foi apagado pelo servidor,
-- então quem aparece é um "fantasma".
-- Custo: 8 peças por botão, nenhuma luz, nenhum emissor de partículas dentro dele, nenhuma conexão por botão.
-- Um laço só (stepPads) mexe, por quadro, só nos MEUS botões que estão perto da câmera.
-- Em cima, a plaquinha:  [PRÓXIMO!]  /  (ícone) nome  /  efeito (amarelo)  /  faixa do preço (moeda + número
-- grande, verde ou vermelho; "GRÁTIS" em faixa DOURADA quando custa 0)  /  barrinha "Faltam X" (só enquanto o
-- dinheiro não dá: enche com o que o jogador já tem, de laranja até verde). De longe sobra só a faixa do preço
-- (com a barrinha fina embaixo), para não poluir a tela.
-- Foco: a placa do botão ao meu lado (e a do botão da vez) cresce para dar para ler com a câmera afastada. As
-- dos vizinhos que ela cobriria viram só o preço e ela sobe um andar: uma placa nunca fica em cima da outra.
-- ---------------------------------------------------------------------------
local pads, addPad, removePad, refreshPads, stepPads, padPaint, padText, padMode
do
	local GREEN_HI = Color3.fromRGB(170, 255, 175)
	local GREEN_LIT = Color3.fromRGB(96, 240, 112)
	local RED = Color3.fromRGB(235, 64, 58)
	local GRAY = Color3.fromRGB(150, 152, 160)
	local RIM = Color3.fromRGB(30, 32, 42)
	local GOLD_HI = Color3.fromRGB(255, 236, 150)
	local TAG_HI = Color3.fromRGB(255, 150, 40)
	local TAG_INK = Color3.fromRGB(60, 34, 10)
	-- cores de cada estado: { lateral, tampa, miolo, anel claro, fundo da faixa do preço, letra do preço }
	local PAINT: { [number]: { Color3 } } = {
		[0] = { Color3.fromRGB(104, 106, 116), GRAY, Color3.fromRGB(188, 190, 198), Color3.fromRGB(222, 224, 230), Color3.fromRGB(52, 54, 66), C.White },
		[1] = { Color3.fromRGB(152, 30, 32), RED, Color3.fromRGB(255, 122, 110), Color3.fromRGB(255, 200, 194), Color3.fromRGB(88, 22, 26), TEXT_RED },
		[2] = { Color3.fromRGB(24, 150, 56), GREEN, GREEN_LIT, Color3.fromRGB(206, 255, 210), Color3.fromRGB(16, 78, 36), TEXT_GREEN },
	}
	-- corpo do botão (studs). "IN" = quanto o diâmetro da peça é menor que o do disco do servidor.
	local PAD_D = 5.4 -- diâmetro do disco do servidor (só para o "fantasma" da compra; o resto mede a peça de verdade)
	local RIM_H, RIM_OUT = 0.22, 1.6 -- aro: 7,0 de diâmetro (os botões ficam a 8,2 ou mais um do outro)
	local KIND_H, KIND_OUT = 0.3, 0.8 -- anel do tipo: 0,4 de largura, um degrau acima do aro
	local CAP_H, CAP_IN = 0.18, 0.5
	local SHINE_H, SHINE_IN = 0.05, 0.9
	local DOME_H, DOME_IN = 0.16, 1.5
	local ART_SIZE = 2.9 -- lado do ícone deitado em cima do botão
	-- O ícone fica de pé para quem entra no terreno pela frente (vindo da rua). Num SurfaceGui virado para cima
	-- o "em cima" do desenho aponta para o -Z da peça: a peça é girada 180° em relação ao terreno.
	local ART_YAW = math.pi
	-- ícone flutuando (de pé, duas faces): lado, altura do meio acima do topo do botão e até que distância da
	-- câmera ele gira (mais longe fica parado: de longe não dá para ver o giro e não vale o custo)
	local FLOAT_SIZE, FLOAT_NEXT, FLOAT_LIFT, FLOAT_NEAR = 2.2, 2.7, 2.6, 75
	local PRESS = 0.16 -- quanto a tampa afunda com o dono em cima
	local PRESS_REACH = 0.45 -- folga em volta da tampa para contar que ele está "em cima"
	local PAD_W = 8.0 -- largura da placa em studs (os botões ficam a 8,2 ou mais um do outro: nunca encosta)
	local PAD_LIFT = 5.0 -- altura da base da placa acima do botão (acima da cabeça de quem pisa nele)
	local PAD_PADX = 0.035 -- margem lateral (fração da largura)
	local PAD_ICON = 1.2 -- o ícone redondo fica na linha do título
	local TAG_H = 0.95 -- selo "PRÓXIMO!"
	local PRICE_H = 1.7 -- faixa do preço (a linha mais alta da placa: é o que se lê de longe)
	local NEED_H = 0.72 -- barrinha "Faltam X" (só quando o dinheiro não dá)
	local MINI_W, MINI_H = 5.6, 1.9
	local MINI_NEED = 0.3 -- a barrinha da plaquinha pequena (sem texto), que ganha 0,4 de altura para ela caber
	local FOCUS_PX = 300 -- a placa do botão em foco (o meu, ao meu lado) ocupa pelo menos isto de largura na tela
	local PAD_TITLE_PX = 12 -- a placa completa só aparece enquanto a letra do título tiver pelo menos isto na tela
	local PAD_PRICE_PX = 10 -- de longe, a plaquinha do preço cresce (até 1,5x) para a letra não ficar menor que isto

	-- (até onde aparece a placa completa, até onde aparece alguma placa). Tela grande: ~43 e 68 studs;
	-- celular: ~23 e 46. Na granja dos outros, metade (lá o jogador só está de visita).
	local function padLimits(isMine: boolean): (number, number)
		local full = math.clamp(pxStud / PAD_TITLE_PX, 16, 44)
		local max = math.clamp(pxStud / 7.5, 46, 68)
		if isMine then
			return full, max
		end
		return full * 0.5, max * 0.7
	end

	local BIZ_ICON = { banca = "🥚", granja = "🐔", entrega = "🚚", fabrica = "🏭", deposito = "📦", omeleteria = "🍳", lab = "🧪", foguete = "🚀" }
	local BIRD_ICON = { pata = "🦆", codorna = "🐦", dragao = "🐉" }
	local GLOBAL_ICON = { basket = "🧺", incubator = "🐣", tree = "🍎", sign = "📢", tractor = "🚜", fence = "🏡", windmill = "🌾" }
	local KIND_ICON = { unlock = "🏪", manager = "👔", cash = "💰", speed = "⚡", bird = "🐔", global = "⭐" }
	-- A cor de cada TIPO de botão (o anel "Kind" no chão e a bolinha do ícone na plaquinha). De propósito
	-- nenhuma é verde, vermelha ou dourada: verde/vermelho dizem se dá para comprar, dourado é o botão da vez.
	local KIND_COLOR = {
		unlock = Color3.fromRGB(250, 250, 255), -- abrir negócio: branco
		manager = Color3.fromRGB(60, 130, 255), -- gerente: azul
		cash = Color3.fromRGB(70, 222, 250), -- +dinheiro: ciano
		speed = Color3.fromRGB(255, 140, 40), -- +velocidade: laranja
		bird = Color3.fromRGB(255, 120, 190), -- ave: rosa
		global = Color3.fromRGB(180, 110, 255), -- geral: roxo
	}
	local CONFETTI = { Color3.fromRGB(255, 214, 64), Color3.fromRGB(255, 110, 190), Color3.fromRGB(90, 200, 255) }
	-- barrinha "Faltam X": vazia = laranja, pela metade = amarela, quase cheia = verde
	local NEED_BG = Color3.fromRGB(12, 12, 18)
	local NEED_COLOR = { Color3.fromRGB(255, 120, 50), Color3.fromRGB(255, 208, 60), Color3.fromRGB(96, 232, 104) }

	pads = {}
	local crowd: { [Instance]: number } = {} -- botões que, nesta varredura, mostram só o preço para dar lugar à placa em foco
	local nextFx: Part? = nil -- a peça das faíscas do botão da vez (uma só)
	local nextSpark: ParticleEmitter? = nil
	local nextShown: any = nil -- o botão da vez do MEU terreno que está com as faíscas agora
	local sparkTick = 0

	-- imagem do ícone (id do Config.Images) ou nil quando não há imagem enviada para este tipo de botão
	local GLOBAL_IMAGE = { basket = "Cesta", incubator = "Pet" }
	local function padImage(button: any): string?
		local kind = button.Kind
		local name: string? = nil
		if kind == "unlock" then
			local biz = Config.Businesses[button.Biz]
			name = biz and ("Biz_" .. biz.Id)
		elseif kind == "manager" then
			name = "Gerente"
		elseif kind == "cash" then
			name = "Moeda"
		elseif kind == "speed" then
			name = "Raio"
		elseif kind == "bird" then
			local line = Config.Lines[button.Line]
			name = line and ("R_" .. line.Asset)
		else
			name = GLOBAL_IMAGE[(string.gsub(tostring(kind), "%d+$", ""))]
		end
		local id = name and Config.Images[name]
		return if type(id) == "string" and id ~= "" then id else nil
	end

	local function padIcon(button: any, padKind: string): string
		local kind = button.Kind
		if kind == "unlock" then
			local biz = Config.Businesses[button.Biz]
			return (biz and BIZ_ICON[biz.Id]) or KIND_ICON.unlock
		elseif kind == "bird" then
			local line = Config.Lines[button.Line]
			return (line and BIRD_ICON[line.Id]) or KIND_ICON.bird
		elseif kind == "manager" or kind == "cash" or kind == "speed" then
			return KIND_ICON[kind]
		end
		local base = string.gsub(tostring(kind), "%d+$", "")
		return GLOBAL_ICON[base] or KIND_ICON[padKind] or KIND_ICON.global
	end

	-- Moeda + número, JUNTOS e no meio de uma faixa (x0, y0, largura w, altura rowH, em studs, dentro de uma placa
	-- de W x H). A largura do número é estimada pelo tamanho do texto (a letra encolhe sozinha se passar).
	local function priceRow(coin: any, label: any, free: boolean, x0: number, y0: number, w: number, rowH: number, W: number, H: number)
		local inner = rowH * 0.8 -- altura da letra e da moeda
		local hasCoin = coin ~= nil and not free
		local coinW = if hasCoin then inner + 0.16 else 0
		local textW = math.min(ulen(label.Text) * inner * 0.6 + 0.3, w - 0.3 - coinW)
		local x = x0 + (w - textW - coinW) / 2
		local top = (y0 + (rowH - inner) / 2) / H
		if coin then
			coin.Visible = hasCoin
			coin.Position = UDim2.fromScale(x / W, top)
			coin.Size = UDim2.fromScale(inner / W, inner / H)
		end
		label.Position = UDim2.fromScale((x + coinW) / W, top)
		label.Size = UDim2.fromScale(textW / W, inner / H)
	end

	-- Arruma as linhas da placa:   [PRÓXIMO!]  (só no botão da vez)
	--                              (ícone) Título
	--                              efeito (amarelo, largura toda)
	--                              faixa do preço (moeda + número, no meio)
	--                              barrinha "Faltam X" (só quando o dinheiro não dá: info.NeedOn)
	-- Cada linha tem a sua caixa (o texto encolhe para caber: nunca corta nem invade a linha de baixo) e a
	-- placa cresce para CIMA quando o título precisa de duas linhas, quando ganha o selo ou a barrinha.
	local function padLayout(info: any)
		local title, desc = info.Title.Text, info.Desc.Text
		local free = info.Cost <= 0
		local needOn = info.NeedOn == true
		-- alturas em studs. Título comprido ("Acelerador de Gemas", "Gerente do Depósito") ganha caixa de 2 linhas.
		local titleH = if ulen(title) > 16 and string.find(title, " ", 1, true) then 1.9 else 1.15
		local descH = if desc == "" then 0 elseif ulen(desc) > 27 and string.find(desc, " ", 1, true) then 1.4 else 0.8
		local tagH = if info.Next then TAG_H + 0.1 else 0
		local needH = if needOn then NEED_H + 0.1 else 0
		local h = 0.16 + tagH + titleH + 0.05 + descH + 0.09 + PRICE_H + needH + 0.16
		info.FullH = h
		local wide = 1 - 2 * PAD_PADX
		local iconW = PAD_ICON / PAD_W
		local titleX = PAD_PADX + iconW + 0.18 / PAD_W
		local y = 0.16
		info.Tag.Visible = info.Next
		info.Tag.Position = UDim2.fromScale(0.21, y / h)
		info.Tag.Size = UDim2.fromScale(0.58, TAG_H / h)
		y += tagH
		info.Icon.Position = UDim2.fromScale(PAD_PADX, (y + titleH / 2) / h)
		info.Icon.Size = UDim2.fromScale(iconW, PAD_ICON / h)
		info.Title.Position = UDim2.fromScale(titleX, y / h)
		info.Title.Size = UDim2.fromScale(1 - titleX - PAD_PADX, titleH / h)
		y += titleH + 0.05
		info.Desc.Position = UDim2.fromScale(PAD_PADX, y / h)
		info.Desc.Size = UDim2.fromScale(wide, math.max(descH, 0.01) / h)
		info.Desc.Visible = descH > 0
		y += descH + 0.09
		info.Band.Position = UDim2.fromScale(PAD_PADX, y / h)
		info.Band.Size = UDim2.fromScale(wide, PRICE_H / h)
		priceRow(info.Coin, info.Price, free, PAD_PADX * PAD_W, y, wide * PAD_W, PRICE_H, PAD_W, h)
		y += PRICE_H + 0.1
		info.Need.Visible = needOn
		info.Need.Position = UDim2.fromScale(PAD_PADX, y / h)
		info.Need.Size = UDim2.fromScale(wide, NEED_H / h)
		-- plaquinha pequena: o preço fica do mesmo tamanho; com a barrinha ela ganha um pouco de altura embaixo
		local miniH = if needOn then MINI_H + MINI_NEED + 0.1 else MINI_H
		info.MiniH = miniH
		priceRow(info.MiniCoin, info.MiniPrice, free, 0.25, 0.2, MINI_W - 0.5, MINI_H - 0.4, MINI_W, miniH)
		info.MiniNeed.Visible = needOn
		info.MiniNeed.Position = UDim2.fromScale(0.4 / MINI_W, (MINI_H - 0.2) / miniH)
		info.MiniNeed.Size = UDim2.fromScale((MINI_W - 0.8) / MINI_W, MINI_NEED / miniH)
	end

	-- A barrinha "Faltam X" de um botão que o dinheiro ainda não paga: enche com o que o jogador já tem (de
	-- laranja até verde) e diz quanto falta. Só mexe na tela quando o desenho muda (degraus de 2%).
	local function padNeed(info: any, coins: number)
		local cost = info.Cost
		local frac = if cost > 0 then math.clamp(coins / cost, 0, 1) else 1
		local step = math.floor(frac * 50 + 0.5)
		if step ~= info.NeedStep then
			info.NeedStep = step
			local f = step / 50
			local color = if f < 0.5 then NEED_COLOR[1]:Lerp(NEED_COLOR[2], f * 2) else NEED_COLOR[2]:Lerp(NEED_COLOR[3], (f - 0.5) * 2)
			local size = UDim2.fromScale(math.max(f, 0.05), 1) -- (sempre um pedacinho à mostra: barra vazia parece defeito)
			info.NeedFill.Size = size
			info.NeedFill.BackgroundColor3 = color
			info.MiniFill.Size = size
			info.MiniFill.BackgroundColor3 = color
		end
		local left = short(math.max(cost - coins, 0))
		if left ~= info.NeedLeft then
			info.NeedLeft = left
			info.NeedText.Text = T("pad.left", { n = left })
		end
	end

	-- Escreve os textos (no idioma de agora) e arruma as linhas
	function padText(info: any)
		local button = info.Button
		local ok, title, desc = pcall(Lang.Button, Config, button, short)
		if not ok or type(title) ~= "string" then
			title, desc = tostring(button.Id), ""
		end
		desc = if type(desc) == "string" then desc else ""
		-- com a imagem da moeda ao lado, o texto é só o número; sem imagem (IDs não enviados), o saquinho de sempre
		local price = if info.Cost <= 0 then T("btn.free") elseif info.Coin then short(info.Cost) else "💰 " .. short(info.Cost)
		info.Title.Text = title
		info.Desc.Text = desc
		info.Price.Text = price
		info.MiniPrice.Text = price
		info.TagText.Text = T("lot.next")
		info.NeedLeft = nil -- ("Faltam X" no idioma de agora)
		if info.NeedOn then
			padNeed(info, if state then num(state.Coins) else 0)
		end
		padLayout(info)
	end

	-- escala da plaquinha pequena (só o preço) a "d" studs da câmera: cresce até 1,5x para a letra não sumir
	local function miniScale(d: number): number
		return math.floor(math.clamp(d * PAD_PRICE_PX / pxStud, 1, 1.5) * 10 + 0.5) / 10
	end

	-- Qual placa mostrar a esta distância da câmera: (modo, escala).
	--   completa: de perto; ou quando EU estou ao lado do botão (aí vale ler mesmo com a câmera afastada, e a
	--   placa cresce até 1,9x: como só o botão ao meu lado e o da vez ficam em foco, ela não encosta no vizinho);
	--   senão só o preço, que cresce até 1,5x. Com folga de 4 studs para não ficar trocando de modo no limite.
	local function padWant(info: any, d: number, focus: boolean): (string, number)
		local limit = if info.Mode == "full" then info.FullDist + 4 else info.FullDist
		if focus and d < info.MaxDist then
			-- em foco: cresce o que precisar para a placa ter FOCUS_PX de largura na tela (até 1,9x)
			return "full", math.floor(math.clamp(FOCUS_PX * d / (PAD_W * pxStud), 1, 1.9) * 20 + 0.5) / 20
		elseif d < limit then
			return "full", 1
		end
		return "mini", miniScale(d)
	end

	-- raise = quantos studs a placa sobe além do normal (a placa em foco fica um andar acima das plaquinhas de
	-- preço dos vizinhos); sem ele, fica como estava.
	function padMode(info: any, mode: string, k: number, raise: number?)
		local up = raise or info.Raise or 0
		info.Mode = mode
		info.K = k
		info.Raise = up
		local gui = info.Gui
		-- (de longe a plaquinha do preço cresce um pouco, até 1,5x, para continuar legível sem passar do vizinho)
		local w, h = if mode == "full" then PAD_W else MINI_W, if mode == "full" then info.FullH else info.MiniH
		gui.Size = UDim2.new(w * k, 0, h * k, 0)
		gui.StudsOffsetWorldSpace = liftOf(gui.Adornee, PAD_LIFT + up + h * k / 2)
		info.Top = PAD_LIFT + up + h * k -- (do meio do botão até o topo da placa: a seta de ajuda fica acima disto)
		info.Full.Visible = mode == "full"
		info.Mini.Visible = mode ~= "full"
	end

	-- Põe a tampa, o anel, o miolo e o ícone na altura certa (info.Press: 0 = solta, 1 = afundada)
	local function padPose(info: any)
		local y = info.TopY - PRESS * info.Press
		local flat: CFrame = info.Flat
		info.Cap.CFrame = flat + Vector3.new(0, y + CAP_H / 2, 0)
		info.Shine.CFrame = flat + Vector3.new(0, y + CAP_H + SHINE_H / 2 - 0.01, 0)
		info.Dome.CFrame = flat + Vector3.new(0, y + CAP_H + SHINE_H + DOME_H / 2 - 0.02, 0)
		info.Art.CFrame = CFrame.new(info.At.X, y + CAP_H + SHINE_H + DOME_H + 0.015, info.At.Z) * info.Facing
	end

	-- Cores do botão e do preço. Só mexe nas peças quando a situação muda (pode pagar / não pode / não é meu,
	-- é ou não é o botão da vez).
	function padPaint(pad: BasePart, info: any)
		local coins = if state then num(state.Coins) else 0
		local can = info.Mine and state ~= nil and coins >= info.Cost
		local paint = if not info.Mine then 0 elseif can then 2 else 1
		if paint == 1 then
			padNeed(info, coins) -- a barrinha "Faltam X" acompanha o dinheiro (só mexe na tela quando o desenho muda)
		end
		local look = paint * 2 + (if info.Next then 1 else 0)
		if look == info.Look then
			return
		end
		info.Look = look
		info.Paint = paint
		local lit =if paint == 2 then Enum.Material.Neon else Enum.Material.SmoothPlastic -- aceso só quando dá
		local colors = PAINT[paint]
		pad.Color = colors[1]
		pad.Material = Enum.Material.SmoothPlastic
		info.Cap.Color = colors[2]
		info.Dome.Color = colors[3]
		info.Dome.Material = lit
		info.Dome.Size = Vector3.new(DOME_H, info.DomeD, info.DomeD)
		info.Shine.Color = if info.Next then GOLD_HI else colors[4]
		info.Shine.Material = lit -- a borda da tampa acende junto
		info.Rim.Color = if info.Next then GOLD else RIM
		info.Rim.Material = if info.Next then Enum.Material.Neon else Enum.Material.SmoothPlastic
		info.Ring.Color = if info.Next then GOLD else GREEN
		info.Ring.Transparency = 1
		-- "GRÁTIS" (custa 0 e é meu): faixa dourada com letra escura, para ninguém passar batido
		local free = paint == 2 and info.Cost <= 0
		local band = if free then GOLD else colors[5]
		local ink = if free then TAG_INK else colors[6]
		local outline = if free then 1 else 0.45
		info.Band.BackgroundColor3 = band
		info.MiniBg.BackgroundColor3 = band
		info.Price.TextColor3 = ink
		info.Price.TextStrokeTransparency = outline
		info.MiniPrice.TextColor3 = ink
		info.MiniPrice.TextStrokeTransparency = outline
		-- o dinheiro não dá: aparece a barrinha "Faltam X" (a placa ganha uma linha); deu: ela some
		local needOn = paint == 1
		if needOn ~= info.NeedOn then
			info.NeedOn = needOn
			padLayout(info)
			if info.Mode ~= "" then
				padMode(info, info.Mode, info.K)
			end
		end
	end

	function addPad(pad: Instance)
		if pads[pad] or not pad:IsA("BasePart") or not pad.Parent then
			return
		end
		local button = Config.ButtonById[pad:GetAttribute("ButtonId")]
		if not button then
			return -- o atributo ainda não chegou: a varredura tenta de novo daqui a pouco
		end
		local padKind = tostring(pad:GetAttribute("PadKind") or "global")
		local plot = plotOf(pad)
		local ownerId = pad:GetAttribute("OwnerId")
		if ownerId == nil then
			ownerId = plot and plot:GetAttribute("OwnerId") -- sem o atributo no botão: vale o dono do terreno
		end
		local isMine = ownerId ~= nil and ownerId == player.UserId
		-- o disco é um cilindro deitado: o lado menor é a altura, o maior é o diâmetro
		local size = pad.Size
		local height = math.min(size.X, size.Y, size.Z)
		local diameter = math.max(size.X, size.Y, size.Z)
		local at = pad.CFrame.Position
		local floorY = at.Y - height / 2
		-- (as peças locais copiam a orientação do disco do servidor: cilindro tem o eixo no X, e ele já vem deitado)
		local flat = (pad.CFrame - at) + Vector3.new(at.X, 0, at.Z)
		local origin = plot and originOf(plot)
		local facing = if origin then (origin - origin.Position) * CFrame.Angles(0, ART_YAW, 0) else CFrame.Angles(0, ART_YAW, 0)

		-- CORPO do botão. Tudo DENTRO do disco do servidor: quando ele apaga o botão, some junto. (fxPart já faz
		-- cada peça ancorada, sem colisão, sem toque e fora das consultas.)
		local function disc(name: string, h: number, d: number, color: Color3): Part
			return fxPart({ Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, d, d), Color = color, Material = Enum.Material.SmoothPlastic, CFrame = flat + Vector3.new(0, floorY + h / 2, 0), Parent = pad })
		end
		local accent = KIND_COLOR[padKind] or KIND_COLOR.global
		local rim = disc("Rim", RIM_H, diameter + RIM_OUT, RIM)
		-- (no terreno dos outros o anel do tipo fica apagado, como o resto do botão)
		disc("Kind", KIND_H, diameter + KIND_OUT, if isMine then accent else accent:Lerp(GRAY, 0.55))
		local cap = disc("Cap", CAP_H, diameter - CAP_IN, GRAY)
		local shine = disc("Shine", SHINE_H, diameter - SHINE_IN, C.White)
		local dome = disc("Dome", DOME_H, diameter - DOME_IN, GRAY)
		local ring = disc("Pulse", 0.1, diameter + 0.6, GREEN)
		ring.Material = Enum.Material.Neon
		ring.Transparency = 1
		ring.CFrame = flat + Vector3.new(0, floorY + 0.3, 0)
		-- ÍCONE do item deitado em cima do miolo (a imagem do jogo quando existe; senão o emoji de sempre)
		local image = padImage(button)
		local art = fxPart({ Name = "Art", Size = Vector3.new(ART_SIZE, 0.05, ART_SIZE), Transparency = 1, Parent = pad })
		local face = new("SurfaceGui", { Name = "Face", Face = Enum.NormalId.Top, CanvasSize = Vector2.new(256, 256), LightInfluence = 0, MaxDistance = 120, Parent = art })
		local dim = if isMine then 0 else 0.35
		local emoji = padIcon(button, padKind)
		local function iconIn(parent: Instance)
			if image then
				new("ImageLabel", { Name = "Icon", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = image, ImageTransparency = dim, ScaleType = Enum.ScaleType.Fit, Parent = parent })
			else
				new("TextLabel", { Name = "Icon", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = UI.Font2, TextScaled = true, Text = emoji, TextColor3 = C.White, TextTransparency = dim, Parent = parent })
			end
		end
		iconIn(face)
		-- O MESMO ícone de pé, flutuando acima do botão (uma peça fina e invisível com o desenho nas duas faces):
		-- é o que diz de longe que botão é aquele. Nasce de frente para quem entra no terreno; o stepPads gira.
		local turn = if origin then origin - origin.Position else CFrame.new()
		local floatAt = CFrame.new(at.X, floorY + height + FLOAT_LIFT, at.Z) * turn
		local float = fxPart({ Name = "Float", Size = Vector3.new(FLOAT_SIZE, FLOAT_SIZE, 0.06), Transparency = 1, CFrame = floatAt, Parent = pad })
		local floatFaces: { SurfaceGui } = {}
		for _, side in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local surface = new("SurfaceGui", { Name = side.Name, Face = side, CanvasSize = Vector2.new(192, 192), LightInfluence = 0, MaxDistance = 110, Parent = float })
			iconIn(surface)
			table.insert(floatFaces, surface)
		end

		-- PLAQUINHA
		local fullDist, maxDist = padLimits(isMine)
		local gui = billboard({
			Name = "Label",
			Size = UDim2.new(PAD_W, 0, 3, 0),
			StudsOffsetWorldSpace = liftOf(pad, PAD_LIFT + 1.5),
			MaxDistance = maxDist,
			Adornee = pad,
			Parent = pad,
		})
		local full = new("Frame", { Name = "Full", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
		plateBg(full, 0.06, 0.14)
		local tag = new("Frame", { Name = "Tag", BackgroundColor3 = GOLD, BorderSizePixel = 0, ZIndex = 3, Visible = false, Parent = full }, { corner(0.45) })
		local tagText = plateText(tag, { Name = "Text", Position = UDim2.fromScale(0.06, 0.1), Size = UDim2.fromScale(0.88, 0.8), TextColor3 = TAG_INK, TextStrokeTransparency = 1, ZIndex = 4 })
		local icon = new("Frame", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(PAD_PADX, 0.2),
			Size = UDim2.fromScale(PAD_ICON / PAD_W, 0.3),
			BackgroundColor3 = accent,
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = full,
		}, { corner(0.5) })
		if image then
			new("ImageLabel", { Name = "Art", BackgroundTransparency = 1, Position = UDim2.fromScale(0.06, 0.06), Size = UDim2.fromScale(0.88, 0.88), Image = image, ScaleType = Enum.ScaleType.Fit, ZIndex = 3, Parent = icon })
		else
			plateText(icon, { Position = UDim2.fromScale(0.14, 0.14), Size = UDim2.fromScale(0.72, 0.72), Font = UI.Font2, Text = emoji, ZIndex = 3 })
		end
		local title = plateText(full, { Name = "Title", TextXAlignment = Enum.TextXAlignment.Left })
		local desc = plateText(full, { Name = "Desc", Font = UI.Font2, TextColor3 = TEXT_YELLOW, TextXAlignment = Enum.TextXAlignment.Left })
		-- faixa do preço: fundo na cor do estado, a moeda do jogo e o número grande
		local band = new("Frame", { Name = "PriceBg", BackgroundColor3 = PAINT[0][5], BorderSizePixel = 0, ZIndex = 2, Parent = full }, { corner(0.36) })
		local coinImage = Config.Images.Moeda
		local hasCoin = type(coinImage) == "string" and coinImage ~= ""
		local coin = if hasCoin then new("ImageLabel", { Name = "Coin", BackgroundTransparency = 1, Image = coinImage, ScaleType = Enum.ScaleType.Fit, ZIndex = 3, Parent = full }) else nil
		local price = plateText(full, { Name = "Price", ZIndex = 3 })
		-- barrinha "Faltam X" (trilho escuro, enchimento colorido, texto por cima); só aparece quando o dinheiro não dá
		local need = new("Frame", { Name = "Need", BackgroundColor3 = NEED_BG, BorderSizePixel = 0, ZIndex = 2, Visible = false, Parent = full }, { corner(0.5) })
		local needFill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0.05, 1), BackgroundColor3 = NEED_COLOR[1], BorderSizePixel = 0, ZIndex = 2, Parent = need }, { corner(0.5) })
		local needText = plateText(need, { Name = "Text", Position = UDim2.fromScale(0.04, 0.04), Size = UDim2.fromScale(0.92, 0.92), TextStrokeTransparency = 0.2, ZIndex = 3 })
		local mini = new("Frame", { Name = "Mini", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = gui })
		local miniBg = plateBg(mini, 0.08, 0.42)
		local miniCoin = if hasCoin then new("ImageLabel", { Name = "Coin", BackgroundTransparency = 1, Image = coinImage, ScaleType = Enum.ScaleType.Fit, ZIndex = 2, Parent = mini }) else nil
		local miniPrice = plateText(mini, { Name = "Price" })
		local miniNeed = new("Frame", { Name = "Need", BackgroundColor3 = NEED_BG, BorderSizePixel = 0, ZIndex = 2, Visible = false, Parent = mini }, { corner(0.5) })
		local miniFill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0.05, 1), BackgroundColor3 = NEED_COLOR[1], BorderSizePixel = 0, ZIndex = 2, Parent = miniNeed }, { corner(0.5) })

		local info = {
			Gui = gui,
			Full = full,
			Mini = mini,
			MiniBg = miniBg,
			Tag = tag,
			TagText = tagText,
			Icon = icon,
			Title = title,
			Desc = desc,
			Band = band,
			Coin = coin,
			Price = price,
			MiniCoin = miniCoin,
			MiniPrice = miniPrice,
			Need = need,
			NeedFill = needFill,
			NeedText = needText,
			MiniNeed = miniNeed,
			MiniFill = miniFill,
			NeedOn = false, -- a barrinha "Faltam X" está à mostra? (padPaint)
			NeedStep = -1,
			NeedLeft = nil :: string?,
			MiniH = MINI_H,
			Rim = rim,
			Cap = cap,
			Shine = shine,
			Dome = dome,
			Art = art,
			Ring = ring,
			Float = float,
			FloatFaces = floatFaces,
			FloatAt = floatAt,
			FloatOn = true, -- o ícone flutuante está à mostra? (some com o dono em cima do botão)
			FloatBig = false, -- no botão da vez ele é maior
			Spin = false, -- gira neste momento? (meu, perto da câmera e à mostra)
			Button = button,
			Cost = num(button.Cost or pad:GetAttribute("Cost")),
			Mine = isMine,
			Next = false,
			Focus = false, -- placa em foco nesta varredura (o botão ao meu lado ou o da vez)
			Raise = 0,
			D = 0, -- distância até a câmera, da última varredura
			At = at,
			Flat = flat,
			Facing = facing,
			TopY = floorY + height, -- topo do disco do servidor: a tampa assenta aqui
			Diameter = diameter,
			DomeD = diameter - DOME_IN,
			Press = 0,
			PressGoal = 0,
			FullDist = fullDist,
			MaxDist = maxDist,
			Seed = math.random(),
			FullH = 3,
			Top = PAD_LIFT + 3,
			Mode = "",
			K = 1,
			Paint = -1,
			Look = -1,
			Near = false,
		}
		pads[pad] = info
		pad.Transparency = 0
		padPose(info)
		padText(info)
		local d = (info.At - eye).Magnitude
		info.Near = d < 95
		padMode(info, padWant(info, d, false))
		padPaint(pad, info)
	end

	-- (as peças e a plaquinha moram DENTRO do botão do servidor e somem com ele; aqui só sai da lista)
	function removePad(pad: Instance)
		local info = pads[pad]
		if info and info == nextShown then
			nextShown = nil
		end
		pads[pad] = nil
		crowd[pad] = nil
	end

	-- As faíscas do botão da vez: UMA peça para o jogo inteiro, que vai para o botão certo. O emissor nunca
	-- fica ligado (Enabled = false): a cada varredura das placas (5 por segundo) ele solta 1 ou 2 faíscas, e só
	-- enquanto o botão da vez existe e está perto da câmera. Sem botão da vez, nada é solto.
	local function sparkOn(info: any?)
		sparkTick += 1
		if info and info == nextShown and nextSpark and nextSpark.Parent then
			nextSpark:Emit(1 + sparkTick % 2)
			return
		end
		nextShown = info
		if not info then
			return
		end
		local part = nextFx
		if not part or not part.Parent or not part.Parent.Parent then
			-- (dentro de uma pasta própria: não se mistura com as faíscas soltas dos outros efeitos)
			local holder = new("Folder", { Name = "PadNextFx", Parent = fxFolder })
			part = fxPart({ Name = "Glow", Transparency = 1, Size = Vector3.new(4.4, 0.2, 4.4), Parent = holder })
			nextFx = part
			nextSpark = new("ParticleEmitter", {
				Name = "Spark",
				Texture = SPARK,
				Color = ColorSequence.new(GOLD_HI, GOLD),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.3, 0.8), NumberSequenceKeypoint.new(1, 0) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
				Lifetime = NumberRange.new(0.9, 1.5),
				Speed = NumberRange.new(2.5, 5),
				SpreadAngle = Vector2.new(16, 16),
				EmissionDirection = Enum.NormalId.Top,
				LightEmission = 0.9,
				Rate = 0,
				Enabled = false,
				Parent = part,
			})
		end
		(part :: Part).CFrame = CFrame.new(info.At + Vector3.new(0, 0.7, 0))
	end

	-- A placa em foco cresce (até 1,9x: 15 studs de largura) e passaria por cima das placas dos vizinhos, que
	-- ficam a 8,2 studs. Quem ela encostaria (se estivesse com a placa completa) mostra só o preço nesta
	-- varredura (crowd[botão] = escala da plaquinha); e, se ainda assim as duas se encontrariam, a placa em
	-- foco sobe um andar (devolve quantos studs): fica acima das plaquinhas de preço. Quem já está em foco
	-- não cede o lugar.
	local function padCrowd(focusPad: Instance, focus: any, k: number): number
		local half = PAD_W * k / 2
		local raise = 0
		for pad, info in pads do
			if pad ~= focusPad and not info.Focus then
				local dist = ((info.At - focus.At) * Vector3.new(1, 0, 1)).Magnitude
				if dist < half + PAD_W / 2 + 0.2 then
					local kn = miniScale(info.D)
					crowd[pad] = kn
					if dist < half + MINI_W * kn / 2 + 0.3 then
						raise = math.max(raise, (MINI_H + MINI_NEED + 0.1) * kn + 0.4)
					end
				end
			end
		end
		return raise
	end

	-- algumas vezes por segundo: de perto a placa completa, de longe só o preço; quem é o botão da vez; a tampa
	-- afunda no botão em que eu estou em cima
	function refreshPads()
		-- o botão MEU mais perto de mim (até 18 studs) fica "em foco"
		local root = rootPart()
		local here = root and root.CFrame.Position
		local focusPad: Instance? = nil
		local best = 18
		local nextButton = state and state.Next
		local nextId = if type(nextButton) == "table" then nextButton.Id elseif type(nextButton) == "string" then nextButton else nil
		local fullMine, maxMine = padLimits(true)
		local fullOther, maxOther = padLimits(false)
		local sparkFor: any = nil
		local nextPad: Instance? = nil
		for pad, info in pads do
			if not pad.Parent then
				removePad(pad)
				continue
			end
			if info.Mine and here then
				local flatDist = ((info.At - here) * Vector3.new(1, 0, 1)).Magnitude
				local d = (info.At - here).Magnitude
				if d < best then
					focusPad, best = pad, d
				end
				info.PressGoal = if flatDist <= (info.Diameter - CAP_IN) / 2 + PRESS_REACH and math.abs(here.Y - info.At.Y) < 7 then 1 else 0
			else
				info.PressGoal = 0
			end
		end
		for pad, info in pads do
			-- a tela mudou de tamanho (ou girou): as distâncias das placas acompanham
			info.FullDist = if info.Mine then fullMine else fullOther
			local maxDist = if info.Mine then maxMine else maxOther
			if math.abs(maxDist - info.MaxDist) > 1 then
				info.MaxDist = maxDist
				info.Gui.MaxDistance = maxDist
			end
			local d = (info.At - eye).Magnitude
			info.D = d
			info.Focus = false
			local near = d < 95
			if info.Near ~= near then
				info.Near = near
				if not near then
					info.Ring.Transparency = 1
				end
			end
			-- o botão da vez (o PRÓXIMO da fila, o que a seta aponta): aro dourado, selo na placa, ícone maior
			-- quicando e as faíscas
			local isNext = info.Mine and nextId ~= nil and info.Button.Id == nextId
			if isNext ~= info.Next then
				info.Next = isNext
				padLayout(info)
				padMode(info, info.Mode, info.K)
				padPaint(pad :: any, info)
			end
			if isNext then
				nextPad = pad
				if near then
					sparkFor = info
				end
			end
			-- ÍCONE FLUTUANTE: some com o dono em cima do botão (ficaria atravessado no boneco); no botão da vez
			-- é maior; só gira (stepPads) nos meus botões que estão perto da câmera
			local floatOn = info.PressGoal == 0
			if floatOn ~= info.FloatOn then
				info.FloatOn = floatOn
				for _, surface in info.FloatFaces do
					surface.Enabled = floatOn
				end
			end
			if isNext ~= info.FloatBig then
				info.FloatBig = isNext
				local side = if isNext then FLOAT_NEXT else FLOAT_SIZE
				info.Float.Size = Vector3.new(side, side, 0.06)
			end
			local spin = info.Mine and floatOn and d < FLOAT_NEAR
			if spin ~= info.Spin then
				info.Spin = spin
				if not spin then
					info.Float.CFrame = info.FloatAt -- parado: de frente para a entrada do terreno
				end
			end
		end
		-- EM FOCO (placa completa e crescida, para dar para ler com a câmera afastada): o botão ao meu lado e o
		-- botão da vez. Cada um faz os vizinhos que cobriria mostrarem só o preço (padCrowd). O botão ao meu lado
		-- tem a preferência: se o da vez é vizinho dele, o da vez também cede (continua com o aro dourado, o
		-- ícone quicando e as faíscas).
		table.clear(crowd)
		for turn = 1, 2 do
			local pad = if turn == 1 then focusPad else nextPad
			local info = pad and pads[pad]
			if info and not info.Focus and not crowd[pad] then
				local mode, k = padWant(info, info.D, true)
				if mode == "full" and info.D <= info.MaxDist + 12 then
					info.Focus = true
					info.RaiseWant = if k > 1 then padCrowd(pad :: Instance, info, k) else 0
				end
			end
		end
		for pad, info in pads do
			if info.D > info.MaxDist + 12 then
				continue -- longe demais: o próprio Roblox já escondeu a placa
			end
			local mode, k, raise = "mini", crowd[pad], 0
			if k == nil then
				mode, k = padWant(info, info.D, info.Focus)
				raise = if info.Focus then info.RaiseWant else 0
			end
			if info.Mode ~= mode or info.K ~= k or info.Raise ~= raise then
				padMode(info, mode, k, raise)
			end
		end
		sparkOn(sparkFor)
	end

	-- todo quadro (um laço só para todos os botões): a tampa que afunda/volta (só o botão em que alguém pisou);
	-- nos MEUS botões perto da câmera, o ícone flutuante girando devagar e subindo e descendo (no botão da vez
	-- ele quica); e, nos que dá para comprar, a onda, o miolo aceso pulsando e "respirando"
	function stepPads(t: number)
		for pad, info in pads do
			if not pad.Parent then
				continue
			end
			local goal = info.PressGoal
			if info.Press ~= goal then
				-- afunda depressa, volta um pouco mais devagar
				info.Press = if goal > info.Press then math.min(goal, info.Press + 0.34) else math.max(goal, info.Press - 0.2)
				padPose(info)
			end
			if info.Spin then
				local seed = info.Seed * 6.283
				local hop = if info.Next then math.abs(math.sin(t * 4.2 + seed)) * 0.6 else math.sin(t * 1.8 + seed) * 0.16
				info.Float.CFrame = info.FloatAt * CFrame.new(0, hop, 0) * CFrame.Angles(0, t * 1.1 + seed, 0)
			end
			if info.Paint == 2 and info.Near then
				local phase = (t * 0.85 + info.Seed) % 1
				local d = info.Diameter + 0.6 + phase * 2.8
				info.Ring.Size = Vector3.new(0.1, d, d)
				info.Ring.Transparency = 0.4 + 0.6 * phase
				local wave = 0.5 + 0.5 * math.sin(t * 5 + info.Seed * 6)
				info.Dome.Color = GREEN_LIT:Lerp(GREEN_HI, wave)
				local dd = info.DomeD * (1 + 0.035 * wave)
				info.Dome.Size = Vector3.new(DOME_H, dd, dd)
			end
		end
		-- o selo "PRÓXIMO!" do botão da vez pisca (um botão só)
		local shown = nextShown
		if shown and shown.Mode == "full" then
			shown.Tag.BackgroundColor3 = GOLD:Lerp(TAG_HI, 0.5 + 0.5 * math.sin(t * 5))
		end
	end

	-- Um botão foi comprado em "position" (Fx "buy": o ponto do botão, 2 studs acima do chão). O servidor já
	-- apagou o botão de verdade; aqui aparece o "fantasma" dele: a tampa dá o APERTO (afunda depressa e volta,
	-- sumindo na volta), um anel de luz se abre no chão e sai confete (um punhado de cada cor, de uma vez só);
	-- para quem comprou, também pulam umas moedinhas. Tudo some sozinho em menos de 2 segundos.
	function World.PadBought(position: Vector3, _buttonId: any, isMine: boolean?)
		if (position - eye).Magnitude > 160 then
			return
		end
		local floorY = position.Y - 2
		local flat = CFrame.new(position.X, 0, position.Z) * CFrame.Angles(0, 0, math.rad(90))
		local capD = PAD_D - CAP_IN
		local ghost = fxPart({ Name = "PadGhost", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, capD, capD), Color = GREEN_LIT, Material = Enum.Material.Neon, Transparency = 0.05, CFrame = flat + Vector3.new(0, floorY + 0.62, 0), Parent = fxFolder })
		-- (o 5º número do TweenInfo = vai e volta; o 6º = espera antes de começar)
		TweenService:Create(ghost, TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), { CFrame = flat + Vector3.new(0, floorY + 0.16, 0) }):Play()
		TweenService:Create(ghost, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.12), { Transparency = 1 }):Play()
		local ring = fxPart({ Name = "PadRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.14, PAD_D, PAD_D), Color = GOLD_HI, Material = Enum.Material.Neon, Transparency = 0.15, CFrame = flat + Vector3.new(0, floorY + 0.34, 0), Parent = fxFolder })
		TweenService:Create(ring, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.14, PAD_D + 9, PAD_D + 9), Transparency = 1 }):Play()
		local confetti = anchor(Vector3.new(position.X, floorY + 0.9, position.Z))
		confetti.Name = "PadConfetti"
		for _, color in CONFETTI do
			local emitter = new("ParticleEmitter", {
				Texture = SPARK,
				Color = ColorSequence.new(color),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0.15) }),
				Lifetime = NumberRange.new(0.7, 1.2),
				Speed = NumberRange.new(14, 24),
				SpreadAngle = Vector2.new(38, 38),
				EmissionDirection = Enum.NormalId.Top,
				Acceleration = Vector3.new(0, -46, 0),
				Rotation = NumberRange.new(0, 360),
				RotSpeed = NumberRange.new(-260, 260),
				LightEmission = 0.4,
				Rate = 0,
				Parent = confetti,
			})
			burst(emitter, if isMine then 12 else 6)
		end
		if isMine then
			World.CoinBurst(Vector3.new(position.X, floorY + 1.2, position.Z), 6) -- (somem sozinhas em 0,9 s)
		end
		task.delay(1.6, function()
			ghost:Destroy()
			ring:Destroy()
			confetti:Destroy()
		end)
	end
end

-- ---------------------------------------------------------------------------
-- 2. TAPETES DE TRABALHO (tag VUOWork): "TRABALHE AQUI" e, com ciclo em andamento, uma barra grande.
-- A placa fica bem acima da cabeça (o jogador fica parado EM CIMA do tapete).
-- ---------------------------------------------------------------------------
local workPads, addWork, removeWork, stepWork
do
	local WORK_BLUE = Color3.fromRGB(70, 160, 255)
	local WORK_HI = Color3.fromRGB(170, 215, 255)
	workPads = {}

	function addWork(pad: Instance)
		if workPads[pad] or not pad:IsA("BasePart") or not pad.Parent then
			return
		end
		local index = pad:GetAttribute("Biz")
		local plot = plotOf(pad)
		if type(index) ~= "number" or not Config.Businesses[index] or not plot then
			return
		end
		local gui = billboard({
			Name = "Work",
			Size = UDim2.new(8, 0, 3, 0),
			StudsOffsetWorldSpace = liftOf(pad, 8.6),
			MaxDistance = 90,
			Enabled = false,
			Adornee = pad,
			Parent = pad,
		})
		plateBg(gui, 0.18, 0.2)
		local title = plateText(gui, { Name = "Title", Position = UDim2.fromScale(0.05, 0.07), Size = UDim2.fromScale(0.9, 0.38), Text = T("work.pad") })
		local bar = new("Frame", {
			Name = "Bar",
			Position = UDim2.fromScale(0.05, 0.52),
			Size = UDim2.fromScale(0.9, 0.36),
			BackgroundColor3 = Color3.fromRGB(58, 62, 80),
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = gui,
		}, { corner(0.5) })
		local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = GREEN, BorderSizePixel = 0, ZIndex = 3, Parent = bar }, { corner(0.5) })
		local left = plateText(bar, { Name = "Left", Position = UDim2.fromScale(0.3, 0.08), Size = UDim2.fromScale(0.4, 0.84), ZIndex = 4 })
		workPads[pad] = { Gui = gui, Title = title, Fill = fill, Left = left, Index = index, Plot = plot, At = pad.CFrame.Position, Busy = nil, Tenths = -1, Shown = false }
	end

	function removeWork(pad: Instance)
		workPads[pad] = nil
	end

	function stepWork(t: number, now: number)
		for pad, info in workPads do
			if not pad.Parent then
				workPads[pad] = nil
				continue
			end
			if (info.At - eye).Magnitude > 110 then
				continue
			end
			local s = snaps[info.Plot]
			local frac = if s then workFraction(s, info.Index, now) else nil
			local show = frac ~= nil or (s ~= nil and s.Mine) -- nos terrenos dos outros a placa só aparece com a barra andando
			if info.Shown ~= show then
				info.Shown = show
				info.Gui.Enabled = show
			end
			if frac then
				if info.Busy ~= true then
					info.Busy = true
					info.Title.Text = T("work.busy")
					info.Title.TextColor3 = TEXT_YELLOW
				end
				info.Fill.Size = UDim2.fromScale(math.clamp(frac, 0.03, 1), 1)
				-- o tempo que falta: só troca o texto quando muda o décimo de segundo
				local tenths = math.max(0, math.ceil((s.Work[info.Index] - now) * 10))
				if tenths ~= info.Tenths then
					info.Tenths = tenths
					info.Left.Text = string.format("%.1fs", tenths / 10)
				end
			elseif info.Busy ~= false then
				info.Busy = false
				info.Tenths = -1
				info.Title.Text = T("work.pad")
				info.Title.TextColor3 = C.White
				info.Fill.Size = UDim2.fromScale(0, 1)
				info.Left.Text = ""
			end
			-- o tapete pulsa (mais depressa enquanto trabalha)
			local wave = 0.5 + 0.5 * math.sin(t * (if frac then 9 else 3))
			pad.Transparency = 0.2 + 0.3 * wave
			pad.Color = WORK_BLUE:Lerp(WORK_HI, if frac then wave * 0.6 else wave * 0.25)
		end
	end

	-- Para a tela: (índice do negócio, fração 0..1) do ciclo na mão do negócio em cujo tapete EU estou; nil se nenhum.
	function World.WorkInfo(): (number?, number?)
		local s = mine
		local root = rootPart()
		if not s or not root or not HAS_V4 then
			return nil, nil
		end
		local at = s.Origin:PointToObjectSpace(root.CFrame.Position)
		local reach = (Config.WorkRadius or 5) + 0.5
		for i = 2, NUM_BIZ do
			if s.Biz[i] == 1 then
				local u = LBIZ[i].U
				local dx, dz = at.X - u[1], at.Z - u[2]
				if dx * dx + dz * dz <= reach * reach then
					-- lê direto do terreno (o retrato pode ter até 0,2 s de atraso)
					local ends = num(s.Plot:GetAttribute(ATTR.Work[i]))
					local length = num(s.Plot:GetAttribute(ATTR.WorkLen[i]))
					local left = ends - workspace:GetServerTimeNow()
					if ends > 0 and length > 0 and left > 0 then
						return i, math.clamp(1 - left / length, 0, 1)
					end
					return i, 0
				end
			end
		end
		return nil, nil
	end
end

-- ---------------------------------------------------------------------------
-- 3. PLACA DE CADA NEGÓCIO (tag VUOBiz): nome, renda (só o dono vê), barra do ciclo e estado.
-- Fica acima do prédio. De longe vira só nome + barra e cresce um pouco para continuar visível.
-- ---------------------------------------------------------------------------
local signs, bancaFlash, addBiz, removeBiz, refreshSigns, stepSigns, signText
do
	local SIGN_W, SIGN_H = 9, 3.7
	local SIGN_MINI_W, SIGN_MINI_H = 7, 1.9
	local SIGN_MAX = 150
	local SIGN_FULL, SIGN_FULL_OTHER = 80, 45
	-- altura da placa quando o prédio está vazio (granja, fábrica) ou ainda não chegou
	local SIGN_Y = { banca = 13.4, granja = 9.5, entrega = 11.6, fabrica = 12.6, deposito = 16.2, omeleteria = 13.6, lab = 15.6, foguete = 24.5 }
	local BARN_Y = { 16.2, 16.2, 28.6, 29.2, 33 } -- o celeiro cresce com as melhorias
	signs = {}
	bancaFlash = {} -- [terreno] = brilho da barra da banca a cada venda na mão

	local function signHeight(info: any): number
		local y = SIGN_Y[info.Id] or 12
		local model = info.Model
		-- prédio de verdade (com peças): a placa fica logo acima do ponto mais alto dele
		if model:FindFirstChildWhichIsA("BasePart", true) then
			local ok, cf, size = pcall(model.GetBoundingBox, model)
			if ok and cf and size then
				y = math.max(y, info.Origin:PointToObjectSpace(cf.Position).Y + size.Y / 2 + 2.4)
			end
		end
		if info.Id == "deposito" then
			local s = snaps[info.Plot]
			y = math.max(y, BARN_Y[math.clamp(if s then s.BarnStage else 1, 1, #BARN_Y)])
		end
		return math.min(y, 40)
	end

	local function signMode(info: any, mode: string, k: number)
		info.Mode = mode
		info.K = k
		local full = mode == "full"
		local income = full and info.HasIncome == true
		if income then
			-- o dono, de perto: nome, renda, barra, estado
			info.Gui.Size = UDim2.new(SIGN_W, 0, SIGN_H, 0)
			info.Name.Position = UDim2.fromScale(0.04, 0.05)
			info.Name.Size = UDim2.fromScale(0.92, 0.3)
			info.Bar.Position = UDim2.fromScale(0.06, 0.62)
			info.Bar.Size = UDim2.fromScale(0.88, 0.13)
			info.Status.Position = UDim2.fromScale(0.05, 0.78)
			info.Status.Size = UDim2.fromScale(0.9, 0.17)
		elseif full then
			-- visitante, de perto: nome, barra, estado (a renda é só do dono)
			info.Gui.Size = UDim2.new(SIGN_W - 1, 0, SIGN_H - 0.8, 0)
			info.Name.Position = UDim2.fromScale(0.04, 0.06)
			info.Name.Size = UDim2.fromScale(0.92, 0.38)
			info.Bar.Position = UDim2.fromScale(0.06, 0.5)
			info.Bar.Size = UDim2.fromScale(0.88, 0.16)
			info.Status.Position = UDim2.fromScale(0.05, 0.72)
			info.Status.Size = UDim2.fromScale(0.9, 0.22)
		else
			-- de longe: nome + barra
			info.Gui.Size = UDim2.new(SIGN_MINI_W * k, 0, SIGN_MINI_H * k, 0)
			info.Name.Position = UDim2.fromScale(0.05, 0.08)
			info.Name.Size = UDim2.fromScale(0.9, 0.5)
			info.Bar.Position = UDim2.fromScale(0.08, 0.68)
			info.Bar.Size = UDim2.fromScale(0.84, 0.2)
		end
		info.Income.Visible = income
		info.Status.Visible = full
	end

	function signText(info: any)
		local s = snaps[info.Plot]
		local index = info.Index
		info.Name.Text = T("biz." .. info.Id)
		local managed = s ~= nil and s.Biz[index] == 2
		local b = if s and s.Mine and state and type(state.Biz) == "table" then state.Biz[index] else nil
		if type(b) == "table" then
			if managed then
				info.Income.Text = T("biz.income", { n = short(num(b.Income)) })
			else
				-- na mão o ciclo vale mais (state.Hand): mostra o que cai no chão de verdade
				info.Income.Text = T("biz.percycle", { n = short(num(b.Payout) * math.max(num(state.Hand), 1)) })
			end
		else
			info.Income.Text = ""
		end
		local hasIncome = type(b) == "table"
		if hasIncome ~= info.HasIncome then
			info.HasIncome = hasIncome
			if info.Mode == "full" then
				signMode(info, "full", 1) -- a linha da renda entrou ou saiu: arruma as outras
			end
		end
		if managed then
			info.Status.Text = T("biz.managed")
			info.Status.TextColor3 = TEXT_GREEN
		elseif index == 1 and s ~= nil and s.Mine then
			info.Status.Text = T("biz.clickme")
			info.Status.TextColor3 = TEXT_YELLOW
		else
			info.Status.Text = T("biz.manual")
			info.Status.TextColor3 = C.Cream
		end
	end

	function addBiz(model: Instance)
		if signs[model] or not model:IsA("Model") or not model.Parent or not HAS_V4 then
			return
		end
		local index = model:GetAttribute("Biz")
		local plot = plotOf(model)
		local origin = plot and originOf(plot)
		local biz = if type(index) == "number" then Config.Businesses[index] else nil
		if not biz or not plot or not origin or not LBIZ[index] then
			return
		end
		local point = LBIZ[index].Model
		local info: any = { Model = model, Plot = plot, Origin = origin, Index = index, Id = biz.Id, Mode = "", K = 1, Flash = 0, Fill01 = -1, Pulse = false }
		info.Y = signHeight(info)
		local a = fxPart({ Name = "BizSign", Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(origin:PointToWorldSpace(Vector3.new(point[1], info.Y, point[2]))), Parent = fxFolder })
		local gui = billboard({ Name = "Sign", Size = UDim2.new(SIGN_W, 0, SIGN_H, 0), MaxDistance = SIGN_MAX, Adornee = a, Parent = a })
		plateBg(gui, 0.3, 0.18)
		info.Anchor = a
		info.Gui = gui
		info.Name = plateText(gui, { Name = "BizName", TextColor3 = biz.Color:Lerp(C.White, 0.45) })
		info.Income = plateText(gui, { Name = "Income", Position = UDim2.fromScale(0.05, 0.36), Size = UDim2.fromScale(0.9, 0.22), TextColor3 = TEXT_YELLOW })
		info.Bar = new("Frame", { Name = "Bar", BackgroundColor3 = Color3.fromRGB(58, 62, 80), BorderSizePixel = 0, ZIndex = 2, Parent = gui }, { corner(0.5) })
		info.Fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = biz.Color:Lerp(C.White, 0.2), BorderSizePixel = 0, ZIndex = 3, Parent = info.Bar }, { corner(0.5) })
		info.Status = plateText(gui, { Name = "Status", Position = UDim2.fromScale(0.05, 0.78), Size = UDim2.fromScale(0.9, 0.17), Font = UI.Font2, TextColor3 = C.Cream })
		signs[model] = info
		signMode(info, "mini", 1)
		signText(info)
	end

	function removeBiz(model: Instance)
		local info = signs[model]
		if info then
			info.Anchor:Destroy()
			signs[model] = nil
		end
	end

	-- algumas vezes por segundo: modo (perto/longe) e altura
	function refreshSigns(texts: boolean)
		for model, info in signs do
			if not model.Parent then
				removeBiz(model)
				continue
			end
			local d = (info.Anchor.CFrame.Position - eye).Magnitude
			info.Dist = d
			if d > SIGN_MAX + 20 then
				continue
			end
			local s = snaps[info.Plot]
			-- placa completa de perto (para o dono, de mais longe); depois disso: nome + barra
			local limit = if s and s.Mine then SIGN_FULL else SIGN_FULL_OTHER
			local wantFull = if info.Mode == "full" then d < limit + 6 else d < limit
			if wantFull then
				if info.Mode ~= "full" then
					signMode(info, "full", 1)
				end
			else
				local k = math.floor(math.clamp(d / 55, 1, 2.6) * 5 + 0.5) / 5
				if info.Mode ~= "mini" or info.K ~= k then
					signMode(info, "mini", k)
				end
			end
			if texts then
				signText(info)
			end
			-- a altura (o prédio pode ter chegado depois, ou o celeiro cresceu): só de vez em quando, que medir custa
			info.Tick = (info.Tick or 0) + 1
			if texts and info.Tick % 5 == 0 then
				local y = signHeight(info)
				if math.abs(y - info.Y) > 0.5 then
					info.Y = y
					local point = LBIZ[info.Index].Model
					info.Anchor.CFrame = CFrame.new(info.Origin:PointToWorldSpace(Vector3.new(point[1], y, point[2])))
				end
			end
		end
	end

	-- todo quadro (só de perto): a barra do ciclo
	function stepSigns(dt: number, t: number, now: number)
		for plot, value in bancaFlash do
			local left = value - dt * 3.5
			bancaFlash[plot] = if left > 0 then left else nil
		end
		for _, info in signs do
			local d = info.Dist
			if not d or d > 120 then
				continue
			end
			local s = snaps[info.Plot]
			if not s then
				continue
			end
			local index = info.Index
			local b = s.Biz[index]
			local frac, pulse = 0, false
			if b == 2 then
				local rate = s.Rate[index]
				if rate > 0 then
					local period = 1 / rate
					if period < 0.5 then
						frac, pulse = 1, true -- rápido demais para ver a barra andar: fica cheia, pulsando
					else
						frac = (now % period) / period
					end
				end
			elseif b == 1 then
				if index == 1 then
					frac = bancaFlash[info.Plot] or 0 -- a banca não tem ciclo: a barra acende a cada venda
				else
					frac = workFraction(s, index, now) or 0
				end
			end
			-- só mexe na interface quando muda de verdade (centésimos)
			local hundredths = math.floor(frac * 100 + 0.5)
			if hundredths ~= info.Fill01 then
				info.Fill01 = hundredths
				info.Fill.Size = UDim2.fromScale(hundredths / 100, 1)
			end
			if pulse then
				info.Pulse = true
				info.Fill.BackgroundTransparency = 0.2 + 0.25 * (0.5 + 0.5 * math.sin(t * 8))
			elseif info.Pulse then
				info.Pulse = false
				info.Fill.BackgroundTransparency = 0
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- 4. MOEDAS NO CHÃO: um monte dourado no ponto Cash de cada negócio com Ground<i> > 0, e as gorjetas
-- (Tips) espalhadas em volta do ponto da banca. O monte cresce uma moeda por ciclo (até 12): a 1ª fica em pé
-- girando, as outras deitam em volta. Quando o valor volta a 0, as moedas voam para quem pegou.
-- ---------------------------------------------------------------------------
local syncPile, syncTips, stepGround, clearGround
do
	local PILE_MAX = 12
	local PILE_SHOW, PILE_HIDE = 190, 230 -- distância da câmera para criar / apagar o monte
	-- { dx, dz, tipo }: 1 = em pé girando; 0 = deitada no chão; 2 = deitada em cima de outra
	local PILE_SLOTS = {
		{ 0, 0, 1 },
		{ 1.75, 0.4, 0 },
		{ -1.65, 0.9, 0 },
		{ 0.4, -1.85, 0 },
		{ 1.3, 2.0, 1 },
		{ -0.75, 2.1, 0 },
		{ 2.6, -1.35, 0 },
		{ -2.65, -0.85, 0 },
		{ -1.7, -1.6, 1 },
		{ 1.8, 0.45, 2 },
		{ -1.6, 0.85, 2 },
		{ 0.35, -1.8, 2 },
	}
	local TIP_SLOTS = { { -5.6, 1.2 }, { 5.3, 0.7 }, { -3.7, -2.7 }, { 4.0, -2.5 }, { -7.3, -1.2 }, { 7.1, -1.7 } }
	local TIP_COLOR = Color3.fromRGB(255, 228, 120)

	local function makeGroundCoin(at: Vector3, diameter: number, kind: number, color: Color3): any
		local thick = 0.16 * diameter
		local upright = kind == 1
		local base = if upright then at + Vector3.new(0, diameter * 0.5 + 0.55, 0) elseif kind == 2 then at + Vector3.new(0, thick * 1.5 + 0.06, 0) else at + Vector3.new(0, thick * 0.5 + 0.06, 0)
		local size = Vector3.new(thick, diameter, diameter)
		local part = fxPart({
			Name = "MoedaChao",
			Shape = Enum.PartType.Cylinder,
			Size = size * 0.05,
			Color = color,
			Material = if upright then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			Reflectance = if upright then 0 else 0.25,
			-- em pé: o eixo do cilindro fica na horizontal; deitada: na vertical (com um giro qualquer)
			CFrame = if upright then CFrame.new(base) else CFrame.new(base) * CFrame.Angles(0, math.random() * 6, math.rad(90)),
			Parent = fxFolder,
		})
		return { Part = part, Upright = upright, Base = base, Size = size, Phase = math.random() * 6, Pop = 0.28 }
	end

	local function clearPile(pile: any, collected: boolean)
		if collected then
			collectParts(pile.Coins, pile.At)
		else
			for _, coin in pile.Coins do
				coin.Part:Destroy()
			end
		end
		pile.Coins = {}
		if pile.Anchor then
			pile.Anchor:Destroy()
			pile.Anchor = nil
		end
	end

	-- Um monte (key = índice do negócio). value = moedas no chão agora.
	function syncPile(s: any, key: number, value: number, at: Vector3)
		local pile = s.Piles[key]
		local d = (at - eye).Magnitude
		if value <= 0 or s.Owner == 0 or d > PILE_HIDE then
			if pile then
				-- valor zerou com o monte à vista = alguém pegou; senão só saiu de perto
				clearPile(pile, value <= 0 and s.Owner ~= 0 and d < PILE_HIDE)
				s.Piles[key] = nil
			end
			return
		end
		if not pile then
			if d > PILE_SHOW then
				return
			end
			local a = fxPart({ Name = "Monte", Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(at + Vector3.new(0, 1.2, 0)), Parent = fxFolder })
			new("PointLight", { Color = GOLD, Range = 9, Brightness = 0.9, Parent = a })
			local sparks = new("ParticleEmitter", {
				Texture = SPARK,
				Color = ColorSequence.new(GOLD),
				Size = NumberSequence.new(0.5, 0),
				Lifetime = NumberRange.new(0.6, 1),
				Speed = NumberRange.new(1.5, 3.5),
				SpreadAngle = Vector2.new(180, 180),
				LightEmission = 1,
				Rate = 3,
				Parent = a,
			})
			pile = { At = at, Anchor = a, Sparks = sparks, Coins = {}, First = value, Last = 0, Label = nil, Text = "" }
			s.Piles[key] = pile
		end
		if value < pile.Last * 0.5 then
			-- pegaram e já caiu outra antes de a gente ver o zero: as antigas voam, o monte recomeça
			collectParts(pile.Coins, pile.At)
			pile.Coins = {}
			pile.First = value
		end
		pile.Last = value
		-- uma moeda por "ciclo" (o 1º valor visto é o tamanho de um ciclo), com teto
		local want = math.clamp(math.floor(value / math.max(pile.First, 1e-9) + 0.5), 1, PILE_MAX)
		local have = #pile.Coins
		if want < have then
			want = have -- o monte só diminui quando é pego inteiro
		end
		if have < want then
			-- no máximo 2 moedas novas por vez: o monte "enche" em vez de aparecer pronto
			local diameter = math.clamp(1.3 + 0.07 * math.log10(math.max(value, 1)), 1.3, 2.4)
			for k = have + 1, math.min(want, have + 2) do
				local slot = PILE_SLOTS[k]
				local spot = at + s.Origin:VectorToWorldSpace(Vector3.new(slot[1], 0, slot[2]))
				table.insert(pile.Coins, makeGroundCoin(spot, diameter, slot[3], GOLD))
			end
			pile.Sparks:Emit(6)
		end
		-- o valor, só para o dono
		if s.Mine then
			local label = pile.Label
			if not label then
				local gui = billboard({ Name = "Valor", Size = UDim2.new(5, 0, 1.5, 0), StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0), MaxDistance = 90, Adornee = pile.Anchor, Parent = pile.Anchor })
				plateBg(gui, 0.25, 0.4)
				label = plateText(gui, { Position = UDim2.fromScale(0.06, 0.12), Size = UDim2.fromScale(0.88, 0.76), TextColor3 = TEXT_YELLOW })
				pile.Label = label
			end
			local text = "💰 " .. short(value)
			if text ~= pile.Text then
				pile.Text = text
				label.Text = text
			end
		end
	end

	function syncTips(s: any)
		local tips = s.TipCoins
		local at = s.Cash[1]
		local d = if at then (at - eye).Magnitude else math.huge
		local want = if s.Owner ~= 0 and d < PILE_HIDE then math.clamp(s.Tips, 0, #TIP_SLOTS) else 0
		if not tips then
			if want <= 0 or d > PILE_SHOW then
				return
			end
			tips = {}
			s.TipCoins = tips
		end
		if #tips > want then
			-- pegaram: as que sobraram a mais voam (ou somem, se foi só a câmera que saiu de perto)
			local gone = {}
			while #tips > want do
				table.insert(gone, table.remove(tips))
			end
			if d < PILE_HIDE and s.Owner ~= 0 then
				collectParts(gone, at)
			else
				for _, coin in gone do
					coin.Part:Destroy()
				end
			end
		end
		while #tips < want do
			local slot = TIP_SLOTS[#tips + 1]
			local spot = at + s.Origin:VectorToWorldSpace(Vector3.new(slot[1], 0, slot[2]))
			table.insert(tips, makeGroundCoin(spot, 1.15, 1, TIP_COLOR))
		end
		if #tips == 0 then
			s.TipCoins = nil
		end
	end

	local function animateCoin(coin: any, dt: number, t: number, spin: boolean)
		if coin.Pop > 0 then
			coin.Pop = math.max(0, coin.Pop - dt)
			coin.Part.Size = coin.Size * math.max(0.05, backOut(1 - coin.Pop / 0.28))
		end
		if coin.Upright and spin then
			coin.Part.CFrame = CFrame.new(coin.Base + Vector3.new(0, 0.25 * math.sin(t * 2.2 + coin.Phase), 0)) * CFrame.Angles(0, t * 1.8 + coin.Phase, 0)
		end
	end

	function stepGround(dt: number, t: number)
		for _, s in snaps do
			for _, pile in s.Piles do
				local spin = (pile.At - eye).Magnitude < 120
				for _, coin in pile.Coins do
					if coin.Pop > 0 or (spin and coin.Upright) then
						animateCoin(coin, dt, t, spin)
					end
				end
			end
			local tips = s.TipCoins
			if tips then
				local spin = (s.Cash[1] - eye).Magnitude < 120
				for _, coin in tips do
					animateCoin(coin, dt, t, spin)
				end
			end
		end
	end

	function clearGround(s: any)
		for key, pile in s.Piles do
			clearPile(pile, false)
			s.Piles[key] = nil
		end
		if s.TipCoins then
			for _, coin in s.TipCoins do
				coin.Part:Destroy()
			end
			s.TipCoins = nil
		end
	end
end

-- ---------------------------------------------------------------------------
-- Bonecos que andam por um caminho (fregueses da banca e da omeleteria, fazendeiro).
-- O caminho é uma lista de pontos locais do terreno (Vector3 com y = 0).
-- ---------------------------------------------------------------------------
local makeWalker, freeWalker, walkTo, walkAdvance, walkPlace
do
	local WALK_Y = 0.06
	local totalWalkers = 0
	local MAX_WALKERS = 14 -- no jogo inteiro (cada boneco tem dezenas de peças para mover)

	function makeWalker(asset: string, name: string, path: { Vector3 }, speed: number): any?
		if totalWalkers >= MAX_WALKERS then
			return nil
		end
		local model = AssetLib.Get(asset)
		if not model then
			return nil
		end
		AssetLib.SetCollide(model, false)
		model.Name = name
		model.Parent = fxFolder
		totalWalkers += 1
		local dir = if path[2] and (path[2] - path[1]).Magnitude > 0.01 then (path[2] - path[1]).Unit else Vector3.new(0, 0, 1)
		return { Model = model, Path = path, Seg = 1, Along = 0, Speed = speed, Local = path[1], Dir = dir, Face = dir, Phase = math.random() * 6, Wait = 0, Hop = 0 }
	end

	function freeWalker(w: any)
		if w.Model then
			w.Model:Destroy()
			w.Model = nil
			totalWalkers = math.max(0, totalWalkers - 1)
		end
	end

	function walkTo(w: any, path: { Vector3 })
		w.Path = path
		w.Seg = 1
		w.Along = 0
	end

	-- anda; devolve true quando chegou ao fim do caminho
	function walkAdvance(w: any, dt: number): boolean
		local path = w.Path
		local a, b = path[w.Seg], path[w.Seg + 1]
		if not a or not b then
			return true
		end
		local length = (b - a).Magnitude
		w.Along += w.Speed * dt
		while w.Along >= length do
			w.Along -= length
			w.Seg += 1
			a, b = path[w.Seg], path[w.Seg + 1]
			if not b then
				w.Local = a
				return true
			end
			length = (b - a).Magnitude
		end
		w.Local = a:Lerp(b, if length > 0 then w.Along / length else 1)
		if length > 0.01 then
			w.Dir = (b - a) / length
		end
		return false
	end

	-- Põe o boneco no lugar. idle = está parado (esperando): depois que ele já virou para onde tinha que
	-- olhar, não precisa mover dezenas de peças de novo a cada quadro.
	function walkPlace(w: any, origin: CFrame, dt: number, lift: number, idle: boolean?)
		if idle and lift == 0 and w.Rest then
			return
		end
		-- vira aos poucos para onde está indo
		local face = w.Face:Lerp(w.Dir, 1 - math.exp(-10 * dt))
		-- meia-volta (o freguês saindo do balcão, o fazendeiro voltando pelo corredor): os dois vetores são
		-- opostos, a mistura cai em cima da mesma reta e o boneco seguia andando de costas. Um empurrão para o
		-- lado faz ele girar de verdade.
		if w.Face:Dot(w.Dir) < -0.9 then
			face += Vector3.new(-w.Dir.Z, 0, w.Dir.X) * 0.4
		end
		w.Face = if face.Magnitude > 0.05 then face.Unit else w.Dir
		local p = w.Local
		local at = origin:PointToWorldSpace(Vector3.new(p.X, WALK_Y + lift, p.Z))
		w.Model:PivotTo(CFrame.lookAt(at, at + origin:VectorToWorldSpace(w.Face)))
		w.Rest = idle == true and lift == 0 and w.Face:Dot(w.Dir) > 0.999
	end
end

-- ---------------------------------------------------------------------------
-- 5. FREGUESES NA BANCA: andam pela calçada, param na frente do balcão, compram (pulinho, o ovo sai do
-- balcão, a moeda voa) e vão embora. Com gerente o fluxo é constante; sem gerente eles esperam o dono
-- clicar em VENDER (World.BancaSale) e cada clique faz um deles comprar na hora.
-- ---------------------------------------------------------------------------
local SHOP_ASSETS, stepShop, clearShop, shopSale
do
	local STREET = Layout.Street
	local SHOP_DIST = 175
	SHOP_ASSETS = { "Fregues_1", "Fregues_2", "Fregues_3" }

	local function shopperLeave(s: any, shop: any, c: any)
		local stop = STREET.Stops[c.Stop] or 0
		local exit = if math.random() < 0.5 then STREET.X0 else STREET.X1
		shop.Stops[c.Stop] = nil
		c.State = "out"
		walkTo(c, { Vector3.new(stop, 0, STREET.StopZ), Vector3.new(stop, 0, STREET.Z + c.Lane), Vector3.new(exit, 0, STREET.Z + c.Lane) })
	end

	-- O freguês compra: pulinho, o ovo sai do balcão até ele, a moeda vai para o chão (na mão) ou para o caixa (gerente).
	local function shopperBuy(s: any, c: any)
		c.Hop = 0.35
		c.Need -= 1
		local stand = Layout.Stand or { 0, -98 }
		local stop = STREET.Stops[c.Stop] or 0
		local origin: CFrame = s.Origin
		local chest = origin:PointToWorldSpace(Vector3.new(c.Local.X, 2.7, c.Local.Z))
		local counter = origin:PointToWorldSpace(Vector3.new(stand[1] + stop * 0.8, 4.5, stand[2] - 1.5))
		throw("egg", counter, chest, 0.26, 1.6)
		if s.Biz[1] == 2 then
			throw("coin", chest, origin:PointToWorldSpace(Vector3.new(stand[1] - 3.3, 4.9, stand[2] - 1.4)), 0.3, 1.8)
		else
			throw("coin", chest, s.Cash[1] + Vector3.new(0, 0.7, 0), 0.34, 2.4)
		end
	end

	-- atCounter = já nasce parado no balcão (só o primeiro, quando a banca começa a ser desenhada: assim o
	-- primeiro clique do jogador já tem para quem vender)
	local function spawnShopper(s: any, shop: any, managed: boolean, busy: boolean, atCounter: boolean?)
		local free = {}
		for k in STREET.Stops do
			if not shop.Stops[k] then
				table.insert(free, k)
			end
		end
		if #free == 0 then
			return
		end
		local stopIndex = free[math.random(1, #free)]
		local stop = STREET.Stops[stopIndex]
		local from = if math.random() < 0.5 then STREET.X0 else STREET.X1
		local lane = (math.random() - 0.5) * 3
		local path = { Vector3.new(from, 0, STREET.Z + lane), Vector3.new(stop, 0, STREET.Z + lane), Vector3.new(stop, 0, STREET.StopZ) }
		if atCounter then
			path = { Vector3.new(stop, 0, STREET.StopZ) }
		end
		local c = makeWalker(SHOP_ASSETS[math.random(1, #SHOP_ASSETS)], "Fregues", path, if busy then 15 else 10.5)
		if not c then
			return
		end
		c.State = "in"
		c.Stop = stopIndex
		c.Lane = lane
		c.Need = if managed then 1 else math.random(2, 4) -- na mão: fica para alguns cliques
		shop.Stops[stopIndex] = c
		table.insert(shop.List, c)
	end

	function clearShop(s: any)
		local shop = s.Shop
		if shop then
			for _, c in shop.List do
				freeWalker(c)
			end
			s.Shop = nil
		end
	end

	function stepShop(s: any, dt: number, t: number)
		local shop = s.Shop
		local d = (s.StandAt - eye).Magnitude
		if not STREET or s.Owner == 0 or s.Biz[1] < 1 or d > SHOP_DIST then
			if shop then
				clearShop(s)
			end
			return
		end
		local managed = s.Biz[1] == 2
		if not shop then
			shop = { List = {}, Stops = {}, Timer = 0.6, Heat = 0, LastGround = s.Ground[1] }
			s.Shop = shop
			spawnShopper(s, shop, managed, false, true)
		end
		shop.Heat = math.max(0, shop.Heat - dt)
		local busy = managed or shop.Heat > 0

		-- chegada de fregueses: proporcional à atividade, com teto (5 por terreno de perto, 2 de longe)
		shop.Timer -= dt
		if shop.Timer <= 0 then
			local cap = if d < 110 then 5 else 2
			local atCounter = #STREET.Stops -- quantos podem estar chegando/esperando (o resto está indo embora)
			local interval
			if managed then
				interval = math.clamp(1.7 / math.sqrt(math.max(s.Rate[1], 0.05)), 0.7, 3)
			elseif shop.Heat > 0 then
				interval = 0.8
			else
				interval = 3.5 -- parado: um ou outro passa e espera o dono vender
				atCounter = 2
			end
			shop.Timer = interval * (0.7 + 0.6 * math.random())
			local active = 0
			for _ in shop.Stops do
				active += 1
			end
			if #shop.List < cap and active < atCounter then
				spawnShopper(s, shop, managed, busy)
			end
		end

		local origin: CFrame = s.Origin
		for i = #shop.List, 1, -1 do
			local c = shop.List[i]
			local lift = 0
			if c.State == "in" then
				if walkAdvance(c, dt) then
					c.State = "wait"
					c.Dir = Vector3.new(0, 0, 1) -- de frente para o balcão
					c.Wait = if managed then 0.4 + math.random() * 0.7 else 9 + math.random() * 5
				else
					lift = math.abs(math.sin(t * 11 + c.Phase)) * 0.25
				end
			elseif c.State == "wait" then
				c.Wait -= dt
				if c.Wait <= 0 then
					if managed then
						shopperBuy(s, c)
						c.State = "paid"
						c.Wait = 0.6
					else
						shopperLeave(s, shop, c) -- cansou de esperar
					end
				end
			elseif c.State == "paid" then
				c.Wait -= dt
				if c.Wait <= 0 then
					if c.Need > 0 and not managed then
						c.State = "wait"
						c.Wait = 6 + math.random() * 4
					else
						shopperLeave(s, shop, c)
					end
				end
			elseif walkAdvance(c, dt) then
				freeWalker(c)
				table.remove(shop.List, i)
				continue
			else
				lift = math.abs(math.sin(t * 11 + c.Phase)) * 0.25
			end
			if c.Hop > 0 then
				c.Hop = math.max(0, c.Hop - dt)
				lift = math.sin((1 - c.Hop / 0.35) * math.pi) * 0.9
			end
			walkPlace(c, origin, dt, lift, c.State == "wait" or c.State == "paid")
		end
	end

	-- Uma venda na mão neste terreno: o freguês que está no balcão compra na hora.
	function shopSale(s: any)
		local stand = Layout.Stand or { 0, -98 }
		bancaFlash[s.Plot] = 1
		local shop = s.Shop
		if not shop or not STREET then
			return
		end
		shop.Heat = 3
		local now = os.clock()
		if now - (shop.LastSale or 0) < 0.07 then
			return -- clique mais rápido que o olho: não precisa de um efeito por clique
		end
		shop.LastSale = now
		local pick: any = nil
		for _, c in shop.List do
			if c.State == "wait" or (c.State == "paid" and not pick) then
				pick = c
				if c.State == "wait" then
					break
				end
			end
		end
		if pick then
			shopperBuy(s, pick)
			pick.State = "paid"
			pick.Wait = if pick.Need > 0 then 0.25 else 0.5
		else
			-- ninguém no balcão ainda: o ovo pula do balcão e a moeda cai mesmo assim
			local counter = s.Origin:PointToWorldSpace(Vector3.new(stand[1], 4.5, stand[2] - 1.5))
			throw("egg", counter, counter + Vector3.new(0, 0.2, 0), 0.3, 1.8)
			throw("coin", counter, s.Cash[1] + Vector3.new(0, 0.7, 0), 0.36, 2.6)
		end
	end

	-- A tela chama a cada clique confirmado pelo servidor (Fx "click").
	function World.BancaSale()
		local s = mine
		if s then
			safe("BancaSale", shopSale, s)
		end
	end

	-- A tela usa para mostrar o botão VENDER: minha banca está aberta e eu estou perto dela?
	function World.NearBanca(): boolean
		local s = mine
		local root = rootPart()
		if not s or not root or s.Biz[1] < 1 then
			return false
		end
		local flat = (root.CFrame.Position - s.StandAt) * Vector3.new(1, 0, 1)
		-- meio stud de folga para dentro: o botão nunca aparece num lugar em que o servidor recusaria o clique
		return flat.Magnitude <= math.max(1, (Config.ClickRadius or 15) - 0.5)
	end
end

-- ---------------------------------------------------------------------------
-- 9. OMELETERIA: fregueses entram e saem pela porta (Layout.DinerPath) enquanto ela está funcionando.
-- ---------------------------------------------------------------------------
local stepDiner, clearDiner
do
	function clearDiner(s: any)
		local diner = s.Diner
		if diner then
			for _, w in diner.List do
				freeWalker(w)
			end
			s.Diner = nil
		end
	end

	function stepDiner(s: any, dt: number, t: number, now: number)
		local diner = s.Diner
		local route = Layout.DinerPath
		if not route or s.Owner == 0 or s.Biz[6] < 1 or (s.DinerAt - eye).Magnitude > 170 then
			if diner then
				clearDiner(s)
			end
			return
		end
		if not diner then
			diner = { List = {}, Timer = 1 }
			s.Diner = diner
		end
		diner.Timer -= dt
		if diner.Timer <= 0 then
			diner.Timer = 3.5 + math.random() * 3
			if running(s, 6, now) and #diner.List < 3 then
				local path = {}
				for i, point in route do
					path[i] = Vector3.new(point[1], 0, point[2])
				end
				local w = makeWalker(SHOP_ASSETS[math.random(1, #SHOP_ASSETS)], "Fregues", path, 10)
				if w then
					w.State = "in"
					table.insert(diner.List, w)
				end
			end
		end
		local origin: CFrame = s.Origin
		for i = #diner.List, 1, -1 do
			local w = diner.List[i]
			if w.State == "in" then
				if walkAdvance(w, dt) then
					-- entrou: some pela porta e volta daqui a pouco, de barriga cheia
					w.State = "inside"
					w.Wait = 1.5 + math.random() * 2.5
					w.Model.Parent = nil
					continue
				end
			elseif w.State == "inside" then
				w.Wait -= dt
				if w.Wait <= 0 then
					local back = {}
					for k = #w.Path, 1, -1 do
						table.insert(back, w.Path[k])
					end
					walkTo(w, back)
					w.Dir = if back[2] and (back[2] - back[1]).Magnitude > 0.01 then (back[2] - back[1]).Unit else w.Dir
					w.Face = w.Dir
					w.Local = back[1]
					w.State = "out"
					w.Model.Parent = fxFolder
				else
					continue
				end
			elseif walkAdvance(w, dt) then
				freeWalker(w)
				table.remove(diner.List, i)
				continue
			end
			walkPlace(w, origin, dt, math.abs(math.sin(t * 11 + w.Phase)) * 0.25)
		end
	end
end

-- ---------------------------------------------------------------------------
-- 6 e 8. ENTREGAS (vans) e DEPÓSITO (caminhão): saem, percorrem a rota até sumir na estrada e voltam.
-- A posição sai direto do relógio do servidor (não guarda estado): todos os jogadores veem a mesma viagem
-- e nada "acumula erro". Com gerente: uma viagem por ciclo (com duração mínima, para dar para ver);
-- sem gerente: uma viagem por ciclo na mão (Work<i>).
-- ---------------------------------------------------------------------------
local syncFleet, stepFleet, clearFleet
do
	local FLEET_DIST = 330

	local function makePath(points: { { number } }): any
		local pts, cum, total = {}, { 0 }, 0
		for i, p in points do
			pts[i] = Vector3.new(p[1], 0, p[2])
			if i > 1 then
				total += (pts[i] - pts[i - 1]).Magnitude
				cum[i] = total
			end
		end
		return { Pts = pts, Cum = cum, Len = total }
	end

	local function pathPoint(path: any, dist: number): Vector3
		local pts, cum = path.Pts, path.Cum
		if dist <= 0 then
			return pts[1]
		end
		for i = 2, #pts do
			if dist <= cum[i] then
				local seg = cum[i] - cum[i - 1]
				return pts[i - 1]:Lerp(pts[i], if seg > 0 then (dist - cum[i - 1]) / seg else 0)
			end
		end
		return pts[#pts]
	end

	-- fora do terreno (na estrada) o chão é um pouco mais baixo
	local function groundY(z: number): number
		return 0.05 - math.clamp((PLOT_Z0 - z) / 4, 0, 1) * math.max((Layout.Floor or 0.3) - 0.12, 0)
	end

	local function makeVehicle(asset: string, name: string, points: { { number } }, parkYaw: number): any?
		local model = AssetLib.Get(asset)
		if not model or #points < 2 then
			if model then
				model:Destroy()
			end
			return nil
		end
		-- sem colisão: uma peça ancorada andando empurraria (ou prenderia) o jogador
		AssetLib.SetCollide(model, false)
		model.Name = name
		model.Parent = fxFolder
		return { Model = model, Parts = partsOf(model), Path = makePath(points), ParkYaw = parkYaw, Alpha = 0, Parked = false, Seed = math.random() * 6 }
	end

	-- u = fração da viagem (0..1); nil = estacionado
	local function driveVehicle(v: any, origin: CFrame, u: number?, t: number)
		local path = v.Path
		local home = path.Pts[1]
		local park = origin * CFrame.new(home.X, groundY(home.Z), home.Z) * CFrame.Angles(0, math.rad(v.ParkYaw), 0)
		if not u or u <= 0 or u >= 1 then
			if not v.Parked then
				v.Parked = true
				setAlpha(v, 0)
				v.Model:PivotTo(park)
			end
			return
		end
		v.Parked = false
		local len = path.Len
		local dist, alpha, back = 0, 0, false
		if u < 0.46 then
			-- ida: arranca devagar e some nos últimos studs da estrada
			dist = len * (u / 0.46) ^ 1.4
			alpha = (dist - (len - 16)) / 14
		elseif u < 0.54 then
			setAlpha(v, 1) -- sumiu na estrada
			return
		elseif u < 0.95 then
			-- volta: reaparece lá longe e chega freando
			back = true
			dist = len * (1 - (u - 0.54) / 0.41) ^ 1.4
			alpha = (dist - (len - 16)) / 14
		else
			-- chegou: manobra para ficar de frente de novo
			local a = (u - 0.95) / 0.05
			local dir = origin:VectorToWorldSpace(pathPoint(path, 0) - pathPoint(path, 2.5))
			local at = park.Position
			local arrive = if dir.Magnitude > 0.01 then CFrame.lookAt(at, at + dir) else park
			setAlpha(v, 0)
			v.Model:PivotTo(arrive:Lerp(park, a * a * (3 - 2 * a)))
			return
		end
		setAlpha(v, alpha)
		if alpha >= 1 then
			return
		end
		local p = pathPoint(path, dist)
		-- a direção olha um pouco para a frente e para trás: as curvas ficam redondas
		local tangent = pathPoint(path, dist + 2.5) - pathPoint(path, dist - 2.5)
		if back then
			tangent = -tangent
		end
		local at = origin:PointToWorldSpace(Vector3.new(p.X, groundY(p.Z) + math.abs(math.sin(t * 13 + v.Seed)) * 0.07, p.Z))
		local dir = origin:VectorToWorldSpace(tangent)
		if dir.Magnitude > 0.01 then
			v.Model:PivotTo(CFrame.lookAt(at, at + dir))
		else
			v.Model:PivotTo(CFrame.new(at))
		end
	end

	-- Fração da viagem do veículo k (de n) do negócio index agora; nil = estacionado.
	local function tripPhase(s: any, index: number, k: number, n: number, now: number, minTrip: number, maxTrip: number): number?
		local b = s.Biz[index]
		if b == 2 then
			local rate = s.Rate[index]
			if rate <= 0 then
				return nil
			end
			local cycle = math.max(1 / rate, minTrip) -- ciclo rápido demais: a viagem dura o mínimo visual
			local trip = math.min(cycle, maxTrip) -- ciclo longo: viaja e descansa estacionado
			local phase = (now / cycle + (k - 1) / n) % 1 -- os veículos saem um depois do outro
			local u = phase * cycle / trip
			return if u < 1 then u else nil
		elseif b == 1 then
			local ends, length = s.Work[index], s.WorkLen[index]
			if ends <= 0 or length <= 0 or now >= ends then
				return nil
			end
			-- ciclo na mão: a viagem acompanha a barra (se o ciclo for muito curto, um laço de 3 s enquanto trabalha)
			local frac = if length >= 3 then 1 - (ends - now) / length else (now / 3) % 1
			local u = (frac - 0.07 * (k - 1)) / (1 - 0.07 * (n - 1)) -- em comboio
			return if u > 0 and u < 1 then u else nil
		end
		return nil
	end

	function clearFleet(s: any)
		local fleet = s.Fleet
		if fleet then
			for _, v in fleet.Vans do
				v.Model:Destroy()
			end
			if fleet.Truck then
				fleet.Truck.Model:Destroy()
			end
			s.Fleet = nil
		end
	end

	-- de vez em quando: cria/apaga os veículos conforme o que o terreno tem
	function syncFleet(s: any)
		if not HAS_V4 then
			return
		end
		local near = s.Owner ~= 0 and (s.GarageAt - eye).Magnitude < FLEET_DIST
		local wantVans = if near and s.Biz[3] >= 1 and Layout.VanRoute then math.clamp(math.max(s.Vans, 1), 1, 3) else 0
		local wantTruck = near and s.Biz[5] >= 1 and Layout.TruckRoute ~= nil
		local fleet = s.Fleet
		if wantVans == 0 and not wantTruck then
			if fleet then
				clearFleet(s)
			end
			return
		end
		if not fleet then
			fleet = { Vans = {}, Truck = nil }
			s.Fleet = fleet
		end
		while #fleet.Vans > wantVans do
			local v = table.remove(fleet.Vans) :: any
			v.Model:Destroy()
		end
		while #fleet.Vans < wantVans do
			local k = #fleet.Vans + 1
			local route = Layout.VanRoute
			local points, yaw = route, LBIZ[3].Model[3] or 0
			local extra = Layout.VanExtra and Layout.VanExtra[k - 1]
			if k > 1 then
				if not extra then
					break
				end
				-- 2ª e 3ª van: saem da vaga delas e entram na rota no segundo ponto
				points = { extra }
				for i = 2, #route do
					table.insert(points, route[i])
				end
				yaw = extra[3] or 0
			end
			local v = makeVehicle("Van_Entrega", "Van", points, yaw)
			if not v then
				break
			end
			table.insert(fleet.Vans, v)
		end
		if wantTruck and not fleet.Truck then
			fleet.Truck = makeVehicle("Caminhao", "Caminhao", Layout.TruckRoute, 0)
		elseif not wantTruck and fleet.Truck then
			fleet.Truck.Model:Destroy()
			fleet.Truck = nil
		end
	end

	function stepFleet(s: any, t: number, now: number)
		local fleet = s.Fleet
		if not fleet then
			return
		end
		local origin: CFrame = s.Origin
		local n = #fleet.Vans
		for k, v in fleet.Vans do
			driveVehicle(v, origin, tripPhase(s, 3, k, n, now, 5, 12), t)
		end
		if fleet.Truck then
			driveVehicle(fleet.Truck, origin, tripPhase(s, 5, 1, 1, now, 6, 14), t)
		end
	end
end

-- ---------------------------------------------------------------------------
-- 7. FÁBRICA: os ovos saem dos cercados das aves liberadas, seguem o tronco e passam pelas máquinas
-- (lavadora: bolhas; carimbo: faísca; pintora: fica dourado; embaladora: vira caixa). Só quando a fábrica
-- está rodando. No fim da esteira viram caixa e somem.
-- ---------------------------------------------------------------------------
local stepBelts
do
	local beltEggs: { any } = {}
	local BELT_SPEED = 13
	local MAX_BELT_EGGS = 40
	local BELT_Y = 2.3
	local BELT_DIST = 260
	local BOX_COLOR = Color3.fromRGB(205, 160, 104)
	local MACHINE_FX = {
		{ Color = Color3.fromRGB(190, 235, 255), Size = 0.7, Count = 5 }, -- lavadora: bolhas
		{ Color = Color3.fromRGB(235, 70, 60), Size = 0.5, Count = 4 }, -- carimbo
		{ Color = Color3.fromRGB(255, 215, 80), Size = 0.6, Count = 5 }, -- pintora
		{ Color = Color3.fromRGB(230, 200, 150), Size = 0.8, Count = 4 }, -- embaladora
	}

	-- um emissor de partículas por máquina de cada terreno (criado na primeira vez que um ovo passa)
	local function machineEmit(s: any, k: number)
		local fx = MACHINE_FX[k]
		local z = Layout.Machines and Layout.Machines[k]
		if not fx or not z then
			return
		end
		local set = s.MachineFx
		if not set then
			set = {}
			s.MachineFx = set
		end
		local emitter = set[k]
		if not emitter or not emitter.Parent then
			local a = anchor(s.Origin:PointToWorldSpace(Vector3.new(0, BELT_Y + 0.6, z)))
			a.Name = "FxMaquina"
			emitter = new("ParticleEmitter", {
				Texture = SPARK,
				Color = ColorSequence.new(fx.Color),
				Size = NumberSequence.new(fx.Size, 0),
				Lifetime = NumberRange.new(0.4, 0.8),
				Speed = NumberRange.new(4, 9),
				SpreadAngle = Vector2.new(180, 180),
				LightEmission = 0.6,
				Rate = 0,
				Parent = a,
			})
			set[k] = emitter
		end
		emitter:Emit(fx.Count)
	end

	local function makeBox(line: any, at: CFrame): Model
		local model = Instance.new("Model")
		model.Name = "Caixa"
		local box = fxPart({ Name = "Root", Size = Vector3.new(1.7, 1.4, 1.7), Color = BOX_COLOR, Material = Enum.Material.SmoothPlastic, CFrame = at, Parent = model })
		fxPart({ Name = "Fita", Size = Vector3.new(1.76, 0.36, 1.76), Color = if line then line.Color else C.Yellow, Material = Enum.Material.SmoothPlastic, CFrame = at, Parent = model })
		model.PrimaryPart = box
		return model
	end

	local function machinePass(egg: any, k: number)
		machineEmit(egg.S, k)
		if k == 3 then
			-- pinta de dourado todas as peças do ovo (sem depender do nome de nenhuma)
			for _, d in egg.Model:GetDescendants() do
				if d:IsA("BasePart") and d.Transparency < 1 then
					d.Color = d.Color:Lerp(Color3.fromRGB(255, 215, 80), 0.5)
				end
			end
		elseif k == 4 then
			local at = egg.Model:GetPivot()
			egg.Model:Destroy()
			egg.Model = makeBox(Config.Lines[egg.Line], CFrame.new(at.Position + Vector3.new(0, 0.7, 0)) * egg.S.Origin.Rotation)
			egg.Model.Parent = fxFolder
			egg.Boxed = true
		end
	end

	local function spawnBeltEgg(s: any, index: number)
		if #beltEggs >= MAX_BELT_EGGS then
			return
		end
		local line = Config.Lines[index]
		local layout = Layout.Lines[index]
		if not line or not layout or not layout.BeltZ then
			return
		end
		local model = AssetLib.Get(line.EggAsset)
		if not model then
			return
		end
		AssetLib.SetCollide(model, false)
		model.Name = "OvoEsteira"
		local origin: CFrame = s.Origin
		local nest = layout.Nests[math.random(1, #layout.Nests)]
		local path = {
			origin:PointToWorldSpace(Vector3.new(nest[1], BELT_Y, layout.BeltZ)),
			origin:PointToWorldSpace(Vector3.new(0, BELT_Y, layout.BeltZ)),
			origin:PointToWorldSpace(Vector3.new(0, BELT_Y, Layout.TrunkEndZ or -71)),
		}
		model:PivotTo(CFrame.new(path[1]))
		model.Parent = fxFolder
		table.insert(beltEggs, { Model = model, Path = path, Segment = 1, Along = 0, S = s, Line = index, Stage = 0, Machines = math.clamp(s.Machines, 0, 4), Boxed = false })
	end

	-- fim da esteira: vira caixa (se ainda não era), dá um pulinho e some
	local function finishBeltEgg(egg: any, position: Vector3)
		egg.Model:Destroy()
		if #coins < MAX_COINS then
			local line = Config.Lines[egg.Line]
			local box = fxPart({ Name = "Caixa", Size = Vector3.new(1.7, 1.4, 1.7), Color = if egg.Boxed and line then BOX_COLOR:Lerp(line.Color, 0.25) else BOX_COLOR, Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(position + Vector3.new(0, 0.7, 0)) * egg.S.Origin.Rotation, Parent = fxFolder })
			table.insert(coins, { Part = box, Velocity = egg.S.Origin:VectorToWorldSpace(Vector3.new(0, 11, -5)), Life = 0.45 })
		end
	end

	function stepBelts(dt: number, now: number)
		if not HAS_V4 then
			return
		end
		for _, s in snaps do
			local on = s.Owner ~= 0 and s.Biz[4] >= 1 and s.Birds >= 1 and (s.TrunkAt - eye).Magnitude < BELT_DIST
			s.BeltOn = on
			if not on and s.MachineFx then
				-- fábrica fechada ou longe: os emissores das máquinas vão embora junto
				for _, emitter in s.MachineFx do
					if emitter.Parent then
						emitter.Parent:Destroy()
					end
				end
				s.MachineFx = nil
			end
			if on and running(s, 4, now) then
				-- ovos por segundo no terreno inteiro: cresce com a velocidade da fábrica, com teto
				local perSecond = math.clamp(0.8 + s.Rate[4] * 2, 0.8, 3)
				local timer = (s.BeltTimer or math.random()) + dt * perSecond
				if timer >= 1 then
					timer = math.min(timer - 1, 1)
					local birds = math.min(s.Birds, #Config.Lines)
					s.BeltNext = (s.BeltNext or math.random(0, birds - 1)) % birds + 1
					spawnBeltEgg(s, s.BeltNext)
				end
				s.BeltTimer = timer
			end
		end
		for i = #beltEggs, 1, -1 do
			local egg = beltEggs[i]
			if not egg.S.BeltOn then
				-- a fábrica fechou, o terreno ficou sem dono ou saiu de perto: o ovo some
				egg.Model:Destroy()
				table.remove(beltEggs, i)
				continue
			end
			local a, b = egg.Path[egg.Segment], egg.Path[egg.Segment + 1]
			local length = (b - a).Magnitude
			egg.Along += BELT_SPEED * dt
			if egg.Along >= length then
				egg.Along -= length
				egg.Segment += 1
				if egg.Segment >= #egg.Path then
					finishBeltEgg(egg, b)
					table.remove(beltEggs, i)
					continue
				end
				a, b = egg.Path[egg.Segment], egg.Path[egg.Segment + 1]
				length = (b - a).Magnitude
			end
			local position = a:Lerp(b, if length > 0 then math.clamp(egg.Along / length, 0, 1) else 1)
			-- no tronco: confere se passou por alguma máquina
			if egg.Segment == 2 and egg.Stage < egg.Machines then
				local z = egg.S.Origin:PointToObjectSpace(position).Z
				local nextZ = Layout.Machines and Layout.Machines[egg.Stage + 1]
				if nextZ and z <= nextZ then
					egg.Stage += 1
					machinePass(egg, egg.Stage)
				end
			end
			egg.Model:PivotTo(if egg.Boxed then CFrame.new(position + Vector3.new(0, 0.7, 0)) * egg.S.Origin.Rotation else CFrame.new(position))
		end
	end
end

-- ---------------------------------------------------------------------------
-- 9 e 10. Fumaça da chaminé da OMELETERIA e bolhas verdes no tanque do LABORATÓRIO.
-- Usa a peça nomeada (Chamine / Tanque) se o prédio tiver; se virou malha, um ponto fixo do prédio.
-- ---------------------------------------------------------------------------
local syncAmbient, clearAmbient
do
	local function bizPart(s: any, id: string, name: string): BasePart?
		local visuals = s.Plot:FindFirstChild("Visuals")
		local model = visuals and visuals:FindFirstChild("Biz_" .. id)
		local part = model and model:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then
			return part
		end
		return nil
	end

	-- ponto fixo de um prédio: (x, y, z) no espaço do modelo -> mundo
	local function bizPoint(s: any, index: number, x: number, y: number, z: number): Vector3
		local m = LBIZ[index].Model
		local cf = s.Origin * CFrame.new(m[1], 0, m[2]) * CFrame.Angles(0, math.rad(m[3] or 0), 0)
		return cf:PointToWorldSpace(Vector3.new(x, y, z) * (m[4] or 1))
	end

	function syncAmbient(s: any, now: number)
		if not HAS_V4 then
			return
		end
		-- chaminé
		local smoke = s.Smoke
		if s.Owner ~= 0 and s.Biz[6] >= 1 and (s.DinerAt - eye).Magnitude < 260 then
			if not smoke then
				local a = anchor(bizPoint(s, 6, -4.3, 10.3, 3.6))
				a.Name = "Fumaca"
				local emitter = new("ParticleEmitter", {
					Texture = SMOKE,
					Color = ColorSequence.new(Color3.fromRGB(235, 235, 235)),
					Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 3.6) }),
					Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
					Lifetime = NumberRange.new(2.2, 3.4),
					Speed = NumberRange.new(2.5, 4),
					SpreadAngle = Vector2.new(14, 14),
					Acceleration = Vector3.new(0.6, 1.2, 0),
					Rotation = NumberRange.new(0, 360),
					RotSpeed = NumberRange.new(-25, 25),
					EmissionDirection = Enum.NormalId.Top,
					LightEmission = 0.1,
					Rate = 5,
					Enabled = false,
					Parent = a,
				})
				smoke = { Part = a, Emitter = emitter, Found = false }
				s.Smoke = smoke
			end
			if not smoke.Found then
				local chimney = bizPart(s, "omeleteria", "Chamine")
				if chimney then
					smoke.Found = true
					smoke.Part.CFrame = CFrame.new(chimney.CFrame.Position + Vector3.new(0, 1.5, 0))
				end
			end
			local on = running(s, 6, now)
			if smoke.Emitter.Enabled ~= on then
				smoke.Emitter.Enabled = on
			end
		elseif smoke then
			smoke.Part:Destroy()
			s.Smoke = nil
		end
		-- tanque
		local lab = s.Lab
		if s.Owner ~= 0 and s.Biz[7] >= 1 and (s.LabAt - eye).Magnitude < 260 then
			if not lab then
				local green = Color3.fromRGB(150, 255, 90)
				local a = anchor(bizPoint(s, 7, 9.5, 7.9, -1.2))
				a.Name = "Bolhas"
				local emitter = new("ParticleEmitter", {
					Texture = SPARK,
					Color = ColorSequence.new(green),
					Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.7, 0.75), NumberSequenceKeypoint.new(1, 0) }),
					Lifetime = NumberRange.new(1, 1.8),
					Speed = NumberRange.new(1.5, 3.5),
					SpreadAngle = Vector2.new(25, 25),
					EmissionDirection = Enum.NormalId.Top,
					LightEmission = 0.9,
					Rate = 3,
					Parent = a,
				})
				local light = new("PointLight", { Color = green, Range = 14, Brightness = 0.6, Parent = a })
				lab = { Part = a, Emitter = emitter, Light = light, Found = false, On = false }
				s.Lab = lab
			end
			if not lab.Found then
				local tank = bizPart(s, "lab", "Tanque")
				if tank then
					lab.Found = true
					local size = tank.Size
					lab.Part.CFrame = CFrame.new(tank.CFrame.Position + Vector3.new(0, math.max(size.X, size.Y, size.Z) / 2 + 0.3, 0))
				end
			end
			local on = running(s, 7, now)
			if lab.On ~= on then
				lab.On = on
				lab.Emitter.Rate = if on then 14 else 3 -- parado: uma bolha ou outra; trabalhando: borbulha e brilha
				lab.Light.Brightness = if on then 1.8 else 0.6
			end
		elseif lab then
			lab.Part:Destroy()
			s.Lab = nil
		end
	end

	function clearAmbient(s: any)
		if s.Smoke then
			s.Smoke.Part:Destroy()
			s.Smoke = nil
		end
		if s.Lab then
			s.Lab.Part:Destroy()
			s.Lab = nil
		end
		if s.MachineFx then
			for _, emitter in s.MachineFx do
				if emitter.Parent then
					emitter.Parent:Destroy()
				end
			end
			s.MachineFx = nil
		end
	end
end

-- ---------------------------------------------------------------------------
-- 11. FOGUETE: fica em cima da plataforma; a cada ciclo decola (treme, sobe acelerando com fogo e fumaça,
-- some no céu) e um novo aparece com um "pop". Com gerente: um lançamento por ciclo, no mínimo a cada 8 s;
-- sem gerente: no fim de cada ciclo feito na mão.
-- ---------------------------------------------------------------------------
local syncRocket, stepRocket, clearRocket
do
	local ROCKET_DIST = 380
	local R_SHAKE, R_RISE, R_GONE, R_POP = 1.0, 2.6, 0.7, 0.4
	local R_ACC = 56 -- aceleração da subida (studs/s²)

	function clearRocket(s: any)
		local r = s.Rocket
		if r then
			r.Model:Destroy()
			r.Fire:Destroy()
			r.Smoke:Destroy()
			s.Rocket = nil
		end
	end

	function syncRocket(s: any)
		if not HAS_V4 then
			return
		end
		local want = s.Owner ~= 0 and s.Biz[8] >= 1 and (s.RocketAt - eye).Magnitude < ROCKET_DIST
		if not want then
			if s.Rocket then
				clearRocket(s)
			end
			return
		end
		if s.Rocket then
			return
		end
		local model = AssetLib.Get("Foguete")
		if not model then
			return
		end
		AssetLib.SetCollide(model, false)
		model.Name = "Foguete"
		local m = LBIZ[8].Model
		local base = s.Origin * CFrame.new(m[1], Layout.RocketY or 2, m[2]) * CFrame.Angles(0, math.rad(m[3] or 0), 0)
		model:PivotTo(base)
		model.Parent = fxFolder
		local orange = Color3.fromRGB(255, 150, 40)
		local fire = anchor(base.Position)
		fire.Name = "FogoFoguete"
		local flame = new("ParticleEmitter", {
			Texture = FIRE,
			Color = ColorSequence.new(Color3.fromRGB(255, 235, 140), Color3.fromRGB(255, 90, 20)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.6), NumberSequenceKeypoint.new(1, 0.4) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.35, 0.7),
			Speed = NumberRange.new(16, 26),
			SpreadAngle = Vector2.new(12, 12),
			EmissionDirection = Enum.NormalId.Bottom,
			LightEmission = 1,
			Rate = 70,
			Enabled = false,
			Parent = fire,
		})
		local light = new("PointLight", { Color = orange, Range = 30, Brightness = 3, Enabled = false, Parent = fire })
		local ground = anchor(base.Position + Vector3.new(0, 0.5, 0))
		ground.Name = "FumacaFoguete"
		local puff = new("ParticleEmitter", {
			Texture = SMOKE,
			Color = ColorSequence.new(Color3.fromRGB(240, 240, 240)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 7) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(1.6, 2.6),
			Speed = NumberRange.new(7, 13),
			SpreadAngle = Vector2.new(85, 85),
			EmissionDirection = Enum.NormalId.Top,
			Rotation = NumberRange.new(0, 360),
			Rate = 26,
			Enabled = false,
			Parent = ground,
		})
		s.Rocket = {
			Model = model,
			Parts = partsOf(model),
			Base = base,
			Fire = fire,
			Flame = flame,
			Light = light,
			Smoke = ground,
			Puff = puff,
			Alpha = 0,
			Launch = nil, -- segundos desde o começo do lançamento (nil = parado na plataforma)
			Next = os.clock() + 1.5 + math.random() * 3,
			Track = { End = 0, Fired = true },
			Scaled = false,
		}
	end

	function stepRocket(s: any, dt: number, now: number)
		local r = s.Rocket
		if not r then
			return
		end
		-- começa um lançamento?
		local b = s.Biz[8]
		local done = cycleDone(r.Track, s.Work[8], now)
		if not r.Launch then
			local go = false
			if b == 2 then
				if os.clock() >= r.Next then
					go = true
					local rate = s.Rate[8]
					r.Next = os.clock() + math.max(if rate > 0 then 1 / rate else 8, 8)
				end
			elseif b == 1 and done then
				go = true
			end
			if not go then
				return
			end
			r.Launch = 0
		end
		r.Launch += dt
		local e: number = r.Launch
		local base: CFrame = r.Base
		if e < R_SHAKE then
			-- treme na plataforma, motor ligando
			r.Flame.Enabled = true
			r.Flame.Rate = 25
			r.Light.Enabled = true
			r.Puff.Enabled = true
			local power = 0.05 + 0.12 * e / R_SHAKE
			r.Model:PivotTo(base + Vector3.new((math.random() - 0.5) * power, 0, (math.random() - 0.5) * power))
		elseif e < R_SHAKE + R_RISE then
			local a = e - R_SHAKE
			local y = 0.5 * R_ACC * a * a
			r.Flame.Rate = 80
			r.Puff.Enabled = a < 0.9 -- a fumaça fica no chão, só na saída
			setAlpha(r, (a - (R_RISE - 0.5)) / 0.5) -- some no céu
			local at = base + Vector3.new(math.sin(a * 23) * 0.06, y, math.cos(a * 19) * 0.06)
			r.Model:PivotTo(at)
			r.Fire.CFrame = CFrame.new(at.Position + Vector3.new(0, 1, 0))
		elseif e < R_SHAKE + R_RISE + R_GONE then
			if r.Flame.Enabled then
				r.Flame.Enabled = false
				r.Light.Enabled = false
				r.Puff.Enabled = false
				setAlpha(r, 1)
				r.Fire.CFrame = CFrame.new(base.Position)
			end
		elseif e < R_SHAKE + R_RISE + R_GONE + R_POP then
			-- um foguete novo aparece na plataforma com um "pop"
			local a = (e - R_SHAKE - R_RISE - R_GONE) / R_POP
			setAlpha(r, 0)
			r.Scaled = true
			pcall(function()
				r.Model:ScaleTo(math.clamp(backOut(a), 0.15, 1.15))
			end)
			r.Model:PivotTo(base)
		else
			if r.Scaled then
				r.Scaled = false
				pcall(function()
					r.Model:ScaleTo(1)
				end)
			end
			setAlpha(r, 0)
			r.Model:PivotTo(base)
			r.Flame.Enabled = false
			r.Light.Enabled = false
			r.Puff.Enabled = false
			r.Launch = nil
		end
	end
end

-- ---------------------------------------------------------------------------
-- 12. FAZENDEIRO da Granja (o gerente dela): com Biz2 = 2, anda entre os cercados das aves liberadas,
-- para um pouco em cada um e segue para o próximo. Pula a esteira do meio quando atravessa.
-- ---------------------------------------------------------------------------
local stepFarmer, clearFarmer
do
	local FARM_LANE = 42.5 -- x do corredor entre o cercado e os botões
	local FARM_CROSS = -16.2 -- z onde ele atravessa de um lado para o outro (na frente dos cercados)

	local function planFarmer(f: any, s: any)
		local birds = math.clamp(s.Birds, 1, #Layout.Lines)
		local index = math.random(1, birds)
		if birds > 1 and index == f.Last then
			index = index % birds + 1
		end
		f.Last = index
		local line = Layout.Lines[index]
		local side: number = line.Side or (if line.Center[1] < 0 then -1 else 1)
		local lane = line.Center[2] - 3.6 -- entre a esteira do cercado e os ninhos
		local p: Vector3 = f.Local
		local here = if p.X >= 0 then 1 else -1
		local path = { p, Vector3.new(here * FARM_LANE, 0, p.Z) }
		if here ~= side then
			table.insert(path, Vector3.new(here * FARM_LANE, 0, FARM_CROSS))
			table.insert(path, Vector3.new(side * FARM_LANE, 0, FARM_CROSS))
		end
		table.insert(path, Vector3.new(side * FARM_LANE, 0, lane))
		table.insert(path, Vector3.new(side * 33, 0, lane))
		table.insert(path, Vector3.new(side * 13, 0, lane))
		walkTo(f, path)
	end

	function clearFarmer(s: any)
		if s.Farmer then
			freeWalker(s.Farmer)
			s.Farmer = nil
		end
	end

	function stepFarmer(s: any, dt: number, t: number)
		local f = s.Farmer
		local want = HAS_V4 and s.Owner ~= 0 and s.Biz[2] == 2 and s.Birds >= 1 and (s.PensAt - eye).Magnitude < 250
		if not want then
			if f then
				clearFarmer(s)
			end
			return
		end
		if not f then
			local npc = LBIZ[2].Npc
			local start = Vector3.new(npc[1], 0, npc[2])
			f = makeWalker("Fazendeiro", "Fazendeiro", { start, start }, 12)
			if not f then
				return
			end
			f.Last = 0
			f.Wait = 1
			s.Farmer = f
		end
		local lift = 0
		local idle = false
		if f.Wait > 0 then
			-- parado no cercado, "cuidando das aves"
			idle = true
			f.Wait -= dt
			if f.Wait <= 0 then
				planFarmer(f, s)
			end
		elseif walkAdvance(f, dt) then
			f.Wait = 1.4 + math.random()
		else
			lift = math.abs(math.sin(t * 10 + f.Phase)) * 0.3
			-- atravessando o meio com a fábrica aberta: pula por cima da esteira
			local x = math.abs(f.Local.X)
			if x < 3.2 and s.Biz[4] >= 1 then
				lift = 2.9 * (1 - (x / 3.2) ^ 2)
			end
		end
		walkPlace(f, s.Origin, dt, lift, idle)
	end
end

-- ---------------------------------------------------------------------------
-- 13. OVOS RAROS nos ninhos (tag VUORare): faíscas na cor da raridade, plaquinha com o nome e,
-- para o dono, um facho de luz fino para achar de longe.
-- ---------------------------------------------------------------------------
local rares, addRare, removeRare
do
	rares = {}

	function addRare(model: Instance)
		if rares[model] or not model:IsA("Model") or not model.Parent then
			return
		end
		local mutation = Config.MutationById[model:GetAttribute("Mut")]
		local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
		if not mutation or not root then
			return
		end
		local plot = plotOf(model)
		local isMine = plot ~= nil and plot:GetAttribute("OwnerId") == player.UserId
		local strength = mutation.Index or 1 -- 1 brilhante, 2 gigante, 3 mítico
		new("ParticleEmitter", {
			Name = "RareSpark",
			Texture = SPARK,
			Color = ColorSequence.new(mutation.Color),
			Size = NumberSequence.new(0.6, 0),
			Lifetime = NumberRange.new(0.7, 1.2),
			Speed = NumberRange.new(2, 4.5),
			SpreadAngle = Vector2.new(180, 180),
			LightEmission = 1,
			Rate = 3 + 4 * strength,
			Parent = root,
		})
		local gui = billboard({ Name = "Rare", Size = UDim2.new(4.6, 0, 1.2, 0), StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0), MaxDistance = 70, Adornee = root, Parent = model })
		plateBg(gui, 0.25, 0.4)
		local label = plateText(gui, { Position = UDim2.fromScale(0.06, 0.12), Size = UDim2.fromScale(0.88, 0.76), Text = T("mut." .. mutation.Key), TextColor3 = mutation.Color:Lerp(C.White, 0.25) })
		if isMine then
			fxPart({
				Name = "Facho",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(44, 0.3 + 0.12 * strength, 0.3 + 0.12 * strength),
				Color = mutation.Color,
				Material = Enum.Material.Neon,
				Transparency = 0.55,
				CFrame = CFrame.new(root.CFrame.Position + Vector3.new(0, 23, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Parent = model,
			})
		end
		rares[model] = { Label = label, Key = mutation.Key, Plot = plot, At = root.CFrame.Position, Mine = isMine }
	end

	function removeRare(model: Instance)
		rares[model] = nil
	end
end

-- ---------------------------------------------------------------------------
-- 13b. LOTES TRANCADOS (tag VUOLot): o servidor desenha um canteiro de obras no lugar de cada negócio que o
-- dono ainda não abriu. Aqui, a plaquinha em cima da placa de madeira:
--   🔒 nome do negócio  /  o que ele faz  /  preço (verde = já dá para pagar, vermelho = ainda não)
-- O PRÓXIMO a abrir (o 1º trancado) ganha a faixa "PRÓXIMO!", placa maior e um balanço; o 2º é menor; do 3º
-- em diante o preço vira "???" (mistério: dá vontade de descobrir). No terreno dos outros, só o nome.
-- LEGÍVEL DE LONGE (o dono reclamou de plaquinha que não dava para ler): de perto a placa é completa; de
-- longe some a frase (a linha de letra menor) e a placa CRESCE com a distância, para a letra do nome e do
-- preço nunca ficar menor que LOT_TITLE_PX na tela. A conta usa pxStud (pixels por stud desta tela): num
-- celular a placa completa aparece de mais perto e a plaquinha some antes de virar borrão.
-- A plaquinha mora DENTRO do lote: quando o servidor apaga o lote (o negócio abriu), ela some junto.
-- ---------------------------------------------------------------------------
local lots, addLot, removeLot, refreshLots, stepLots, lotText, lotPaint
do
	local LOT_W, LOT_W_OTHER = 9.5, 7.5 -- largura da plaquinha (studs), antes da escala
	local LOT_BASE = 2.3 -- da metade da placa de madeira até a base da plaquinha (a tábua tem 3,4 de altura)
	local LOT_PADX = 0.04
	local LOT_MAX, LOT_MAX_OTHER = 130, 70 -- até onde aparece (teto; em tela pequena some antes: ver lotLimits)
	local TAG_H, TITLE_H, DESC_H, PRICE_H = 1.0, 1.35, 0.85, 1.3 -- altura de cada linha (studs, antes da escala)
	local LOT_TITLE_PX = 15 -- de longe a placa cresce para a caixa do nome ter pelo menos isto na tela
	local LOT_DESC_PX = 10 -- a frase só aparece enquanto a caixa dela tiver pelo menos isto (senão é borrão)
	local LOT_MIN_PX = 9 -- e a plaquinha inteira some quando nem crescendo o nome chega a isto
	local K_NEXT, K_MINE, K_OTHER = 2.6, 2.2, 1.8 -- até quanto cresce (os lotes ficam a 40+ studs um do outro: não encosta)
	local TAG_HI = Color3.fromRGB(255, 150, 40)
	local MYSTERY = Color3.fromRGB(205, 210, 225)
	lots = {}
	local nextLot: any = nil -- o lote "PRÓXIMO!" do MEU terreno (o único que balança)
	local queueDirty = true -- entrou ou saiu um lote: a fila de cada terreno precisa ser refeita

	-- destaque: o próximo é o maior; os de depois, menores (mas nunca miúdos)
	local function lotScale(info: any): number
		return if not info.Mine then 0.9 elseif info.Rank == 1 then 1.2 elseif info.Rank == 2 then 1 else 0.9
	end

	local function lotKMax(info: any): number
		return if not info.Mine then K_OTHER elseif info.Rank == 1 then K_NEXT else K_MINE
	end

	-- (até onde vale a placa completa, até onde aparece alguma placa), para o tamanho desta tela.
	-- Tela grande, próximo lote: ~52 e 130 studs; celular: ~29 e 130. Os outros lotes: ~44/130 e ~24/94.
	local function lotLimits(info: any): (number, number)
		local scale = info.Scale
		local full = if info.Mine then DESC_H * scale * pxStud / LOT_DESC_PX else 0
		local max = math.clamp(TITLE_H * scale * info.KMax * pxStud / LOT_MIN_PX, 40, if info.Mine then LOT_MAX else LOT_MAX_OTHER)
		return full, max
	end

	-- Qual placa a esta distância da câmera: (modo, quanto cresce). Com folga de 4 studs para não ficar
	-- trocando de modo no limite.
	local function lotWant(info: any, d: number): (string, number)
		if info.Mine and d < (if info.Mode == "full" then info.FullDist + 4 else info.FullDist) then
			return "full", 1
		end
		local k = d * LOT_TITLE_PX / (pxStud * TITLE_H * info.Scale)
		return "mini", math.floor(math.clamp(k, 1, info.KMax) * 5 + 0.5) / 5
	end

	local function lotSize(info: any)
		local k = info.Scale * info.K
		info.Gui.Size = UDim2.new((if info.Mine then LOT_W else LOT_W_OTHER) * k, 0, info.H * k, 0)
		info.Lift = LOT_BASE + info.H * k / 2
		-- (StudsOffsetWorldSpace é medido nos eixos da peça: a tábua está girada para onde o jogador vem)
		info.Gui.StudsOffsetWorldSpace = liftOf(info.Board, info.Lift)
	end

	-- Arruma as linhas conforme a posição na fila (rank 1 = próximo), de quem é o terreno e o modo:
	--   completa = [PRÓXIMO!] nome, frase, preço;   de longe = [PRÓXIMO!] nome, preço;   visitante = nome.
	local function lotArrange(info: any)
		local mine = info.Mine
		local showTag = mine and info.Rank == 1
		local showDesc = mine and info.Mode == "full"
		local h = 0.16 + (if showTag then TAG_H + 0.08 else 0) + TITLE_H + (if showDesc then 0.05 + DESC_H else 0) + (if mine then 0.07 + PRICE_H else 0) + 0.14
		info.H = h
		local wide = 1 - 2 * LOT_PADX
		local y = 0.16
		info.Tag.Visible = showTag
		if showTag then
			info.Tag.Position = UDim2.fromScale(0.2, y / h)
			info.Tag.Size = UDim2.fromScale(0.6, TAG_H / h)
			y += TAG_H + 0.08
		end
		info.Title.Position = UDim2.fromScale(LOT_PADX, y / h)
		info.Title.Size = UDim2.fromScale(wide, TITLE_H / h)
		y += TITLE_H
		info.Desc.Visible = showDesc
		if showDesc then
			y += 0.05
			info.Desc.Position = UDim2.fromScale(LOT_PADX, y / h)
			info.Desc.Size = UDim2.fromScale(wide, DESC_H / h)
			y += DESC_H
		end
		info.Price.Visible = mine
		if mine then
			y += 0.07
			info.Price.Position = UDim2.fromScale(LOT_PADX, y / h)
			info.Price.Size = UDim2.fromScale(wide, PRICE_H / h)
		end
		-- o próximo é mais sólido; os de depois, mais apagados
		info.Bg.BackgroundTransparency = if mine and info.Rank == 1 then 0.06 elseif mine and info.Rank == 2 then 0.22 else 0.34
		info.Title.TextColor3 = if mine and info.Rank == 1 then C.White else C.Cream
		lotSize(info)
	end

	function lotText(info: any)
		local id = info.Id
		info.Title.Text = "🔒 " .. T("biz." .. id)
		info.Desc.Text = T("biz." .. id .. ".d")
		info.TagText.Text = T("lot.next")
		-- do 3º trancado em diante o preço é segredo
		local mystery = info.Rank >= 3
		info.Price.Text = if mystery then T("lot.mystery") elseif info.Cost <= 0 then T("btn.free") else "💰 " .. short(info.Cost)
	end

	-- Cor do preço: verde quando o dono já pode pagar, vermelho quando não (só mexe quando muda)
	function lotPaint(info: any)
		local paint = 0
		if info.Mine then
			paint = if info.Rank >= 3 then 3 elseif state ~= nil and num(state.Coins) >= info.Cost then 2 else 1
		end
		if paint ~= info.Paint then
			info.Paint = paint
			info.Price.TextColor3 = if paint == 2 then TEXT_GREEN elseif paint == 1 then TEXT_RED elseif paint == 3 then MYSTERY else C.White
		end
	end

	function addLot(model: Instance)
		if lots[model] or not model:IsA("Model") or not model.Parent then
			return
		end
		local index = model:GetAttribute("Biz")
		local biz = if type(index) == "number" then Config.Businesses[index] else nil
		local board = model:FindFirstChild("Placa")
		local plot = plotOf(model)
		if not biz or not plot or not board or not board:IsA("BasePart") then
			return -- o atributo ou a placa ainda não chegaram: a varredura tenta de novo daqui a pouco
		end
		local ownerId = model:GetAttribute("OwnerId")
		if ownerId == nil then
			ownerId = plot:GetAttribute("OwnerId")
		end
		local isMine = ownerId ~= nil and ownerId == player.UserId
		local unlock = Config.ButtonById[biz.Id .. "_unlock"]
		local gui = billboard({
			Name = "Lot",
			Size = UDim2.new(LOT_W, 0, 4, 0),
			StudsOffsetWorldSpace = liftOf(board, LOT_BASE + 2),
			MaxDistance = if isMine then LOT_MAX else LOT_MAX_OTHER,
			Adornee = board,
			Parent = board,
		})
		local bg = plateBg(gui, 0.2, 0.16)
		local tag = new("Frame", { Name = "Tag", BackgroundColor3 = GOLD, BorderSizePixel = 0, ZIndex = 2, Visible = false, Parent = gui }, { corner(0.4) })
		local tagText = plateText(tag, { Name = "Text", Position = UDim2.fromScale(0.06, 0.08), Size = UDim2.fromScale(0.88, 0.84), TextColor3 = Color3.fromRGB(60, 34, 10), TextStrokeTransparency = 1, ZIndex = 3 })
		local title = plateText(gui, { Name = "Title" })
		local desc = plateText(gui, { Name = "Desc", Font = UI.Font2, TextColor3 = TEXT_YELLOW })
		local price = plateText(gui, { Name = "Price" })
		local info: any = {
			Model = model,
			Board = board,
			Gui = gui,
			Bg = bg,
			Tag = tag,
			TagText = tagText,
			Title = title,
			Desc = desc,
			Price = price,
			Index = index,
			Id = biz.Id,
			Cost = num(unlock and unlock.Cost),
			Plot = plot,
			Mine = isMine,
			At = board.CFrame.Position,
			Rank = -1, -- (-1 = ainda não arrumada: o refreshLots abaixo monta as linhas)
			Queue = 1, -- posição na fila do terreno (1 = próximo a abrir); refeita quando entra ou sai um lote
			Mode = "",
			Scale = 1,
			KMax = 1,
			K = 1,
			H = 4,
			Lift = LOT_BASE + 2,
			FullDist = 0,
			MaxDist = if isMine then LOT_MAX else LOT_MAX_OTHER,
			Dist = 0,
			Paint = -1,
		}
		lots[model] = info
		queueDirty = true
		refreshLots()
	end

	function removeLot(model: Instance)
		if nextLot and nextLot.Model == model then
			nextLot = nil
		end
		if lots[model] then
			lots[model] = nil
			queueDirty = true
		end
	end

	-- algumas vezes por segundo: a posição de cada lote na fila do terreno dele (1 = próximo a abrir), a
	-- placa certa para a distância (completa / de longe) e o tamanho (cresce de longe, para dar para ler)
	function refreshLots()
		for model in lots do
			if not model.Parent then
				removeLot(model)
			end
		end
		-- a fila de cada terreno: quantos lotes de negócios ANTERIORES ainda existem + 1 (só refaz quando
		-- entrou ou saiu um lote: negócio aberto, renascer, dono novo)
		if queueDirty then
			queueDirty = false
			local open: { [Instance]: { [number]: boolean } } = {}
			for _, info in lots do
				local list = open[info.Plot]
				if not list then
					list = {}
					open[info.Plot] = list
				end
				list[info.Index] = true
			end
			for _, info in lots do
				local rank = 1
				local list = open[info.Plot]
				for j = 1, info.Index - 1 do
					if list[j] then
						rank += 1
					end
				end
				info.Queue = rank
			end
		end
		local found: any = nil
		for _, info in lots do
			local rank = info.Queue
			local changed = rank ~= info.Rank
			if changed then
				info.Rank = rank
				info.Scale = lotScale(info)
				info.KMax = lotKMax(info)
			end
			if info.Mine and rank == 1 then
				found = info
			end
			-- a tela mudou de tamanho (ou girou): as distâncias acompanham
			local fullDist, maxDist = lotLimits(info)
			info.FullDist = fullDist
			if math.abs(maxDist - info.MaxDist) > 1 then
				info.MaxDist = maxDist
				info.Gui.MaxDistance = maxDist
			end
			local d = (info.At - eye).Magnitude
			info.Dist = d
			local mode, k = lotWant(info, d)
			if changed or mode ~= info.Mode then
				info.Mode = mode
				info.K = k
				lotArrange(info)
				if changed then
					lotText(info)
					info.Paint = -1
				end
			elseif k ~= info.K and d < info.MaxDist + 12 then -- (mais longe que isso o Roblox já escondeu a placa)
				info.K = k
				lotSize(info)
			end
			lotPaint(info)
		end
		nextLot = found
	end

	-- todo quadro, só para o PRÓXIMO do meu terreno e só enquanto a placa aparece: balança e a faixa pisca
	function stepLots(t: number)
		local info = nextLot
		if not info or not info.Model.Parent or info.Dist > info.MaxDist then
			return
		end
		local wave = 0.5 + 0.5 * math.sin(t * 5)
		info.Gui.StudsOffsetWorldSpace = liftOf(info.Board, info.Lift + 0.3 * math.sin(t * 2.6))
		info.Tag.BackgroundColor3 = GOLD:Lerp(TAG_HI, wave)
	end

	-- O negócio "index" do MEU terreno acabou de abrir: poeira de obra onde estava o lote (chamado pela tela)
	function World.LotOpened(index: number)
		local s = mine
		local lot = Layout.Lots and Layout.Lots[index]
		if not s or not lot then
			return
		end
		World.Poof(s.Origin:PointToWorldSpace(Vector3.new(lot.Center[1], 3, lot.Center[2])), Color3.fromRGB(200, 170, 130))
	end
end

-- ---------------------------------------------------------------------------
-- 13c. SACO DE DINHEIRO (tag VUOBag): o servidor põe o saco num canto do terreno; aqui ele CAI do céu, gira
-- devagar, ganha faíscas, um facho de luz dourado bem alto (para o dono achar de longe) e uma plaquinha com
-- o tempo que falta, que CRESCE com a distância (dá para ler o relógio lá do outro lado do terreno). Nos
-- últimos segundos ele pisca. Para os visitantes: facho curto e sem relógio.
-- Tudo fica DENTRO do Model do saco: quando o servidor apaga o saco, some junto (nada órfão).
-- ---------------------------------------------------------------------------
local bags, addBag, removeBag, refreshBags, stepBags, bagTarget
do
	local BAG_FALL = 0.7 -- segundos da queda
	local BAG_BLINK = 12 -- pisca quando falta menos que isto
	local BAG_GAP = 1.4 -- do topo do saco até a base da plaquinha
	local BAG_TEXT_PX = 16 -- de longe a plaquinha cresce para a caixa do texto ter pelo menos isto na tela
	local BAG_KMAX, BAG_KMAX_OTHER = 4.5, 2 -- (o saco cai longe de tudo: a plaquinha pode crescer bastante)
	local BAG_MAX, BAG_MAX_OTHER = 220, 90 -- até onde a plaquinha aparece
	bags = {}

	-- tamanho da plaquinha para a distância da câmera (cresce para CIMA: a base fica logo acima do saco)
	local function bagPlate(info: any, k: number)
		info.K = k
		info.Gui.Size = UDim2.new(info.W * k, 0, info.H * k, 0)
		info.Top = info.Height + BAG_GAP + info.H * k -- topo da plaquinha, medido do chão (a seta fica acima)
		-- (a peça de apoio não tem rotação: aqui o "para cima" dela é o do mundo)
		info.Gui.StudsOffsetWorldSpace = Vector3.new(0, info.Height * 0.5 + BAG_GAP + info.H * k / 2, 0)
	end

	-- onde o saco está AGORA: cai do céu, depois gira devagar e sobe-desce
	local function bagPose(info: any, t: number, now: number)
		local age = now - info.Born
		local lift = 0.35 + 0.3 * math.sin(t * 2.4 + info.Phase)
		if age < BAG_FALL then
			local k = 1 - math.clamp(age / BAG_FALL, 0, 1)
			lift += 48 * k * k
		elseif not info.Landed then
			info.Landed = true
			if age < BAG_FALL + 1.5 then
				World.Poof(info.At + Vector3.new(0, 1, 0), Color3.fromRGB(210, 185, 140)) -- poeira da queda
			end
		end
		info.Model:PivotTo(info.Rest * CFrame.new(0, lift, 0) * CFrame.Angles(0, t * 0.9 + info.Phase, 0))
		-- o facho e a peça de apoio são do saco, mas ficam parados (o PivotTo levou os dois junto)
		info.Beam.CFrame = info.BeamAt
		info.Anchor.CFrame = info.AnchorAt
	end

	function addBag(model: Instance)
		if bags[model] or not model:IsA("Model") or not model.Parent then
			return
		end
		local untilAt = model:GetAttribute("Until")
		local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
		if type(untilAt) ~= "number" or not root then
			return -- os atributos ainda não chegaram: a varredura tenta de novo
		end
		local plot = plotOf(model)
		local ownerId = model:GetAttribute("OwnerId")
		if ownerId == nil and plot then
			ownerId = plot:GetAttribute("OwnerId")
		end
		local isMine = ownerId ~= nil and ownerId == player.UserId
		local golden = model:GetAttribute("Golden") == true
		local settings = Config.MoneyBag or {}
		local scale = if golden then num(settings.GoldenScale) else num(settings.Scale)
		-- altura do saco: a do modelo que chegou (pode ser trocado por outra arte); sem ela, a do modelo de hoje
		local height = 3.2 * (if scale > 0 then scale else 1.5)
		local okSize, size = pcall(model.GetExtentsSize, model)
		if okSize and typeof(size) == "Vector3" and size.Y > 0.5 and size.Y < 40 then
			height = size.Y
		end
		local rest = model:GetPivot() -- onde o servidor pôs (o saco anima em volta deste ponto)
		local at = rest.Position
		local parts = partsOf(model) -- (antes de criar as peças de efeito: só o saco pisca)
		local glow: Color3 = if typeof(settings.Color) == "Color3" then settings.Color else GOLD -- a cor da luz vem do Config
		-- peça de apoio SEM rotação: a plaquinha, a luz e as faíscas ficam nela (o saco gira; elas não)
		local a = fxPart({ Name = "BagFx", Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(at + Vector3.new(0, height * 0.5, 0)), Parent = model })
		new("PointLight", { Color = glow, Range = if golden then 18 else 12, Brightness = if golden then 1.6 else 1, Parent = a })
		new("ParticleEmitter", {
			Name = "BagSpark",
			Texture = SPARK,
			Color = ColorSequence.new(glow),
			Size = NumberSequence.new(if golden then 0.9 else 0.6, 0),
			Lifetime = NumberRange.new(0.7, 1.2),
			Speed = NumberRange.new(2, 5),
			SpreadAngle = Vector2.new(180, 180),
			LightEmission = 1,
			Rate = if golden then 14 else 6,
			Parent = a,
		})
		-- facho de luz: alto e forte para o dono; curto e fraco para quem está de visita
		local beamH = if isMine then 150 else 34
		local beamW = (if golden then 3.4 else 2.2) * (if isMine then 1 else 0.6)
		-- (o cilindro do Roblox tem o eixo em X: o giro põe o facho de pé)
		local beamAt = CFrame.new(at + Vector3.new(0, beamH / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		local beam = fxPart({
			Name = "BagBeam",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(beamH, beamW, beamW),
			Color = glow:Lerp(Color3.new(1, 1, 1), 0.3), -- (um pouco mais claro que a luz: de longe o facho parece aceso)
			Material = Enum.Material.Neon,
			Transparency = if isMine then 0.5 else 0.78,
			CFrame = beamAt,
			Parent = model,
		})
		local plateW, plateH = if golden then 7.4 else 6, if golden then 2.3 else 1.9
		local gui = billboard({
			Name = "Bag",
			Size = UDim2.new(plateW, 0, plateH, 0),
			StudsOffsetWorldSpace = Vector3.new(0, height * 0.5 + BAG_GAP + plateH / 2, 0),
			MaxDistance = if isMine then BAG_MAX else BAG_MAX_OTHER,
			Adornee = a,
			Parent = a,
		})
		plateBg(gui, 0.2, 0.4)
		local label = plateText(gui, { Name = "Text", Position = UDim2.fromScale(0.06, 0.1), Size = UDim2.fromScale(0.88, 0.8), TextColor3 = TEXT_YELLOW })
		local life = num(settings.Life)
		local info = {
			Model = model,
			Plot = plot,
			Mine = isMine,
			Golden = golden,
			At = at,
			Rest = rest,
			Height = height,
			Until = untilAt,
			Born = untilAt - (if life > 0 then life else 75),
			Anchor = a,
			AnchorAt = a.CFrame,
			Beam = beam,
			BeamAt = beamAt,
			Gui = gui,
			W = plateW,
			H = plateH,
			K = 1,
			Top = height + BAG_GAP + plateH,
			Label = label,
			Parts = parts,
			Alpha = 0,
			Left = -1,
			Landed = false,
			Phase = math.random() * 6,
		}
		bags[model] = info
		-- acabou de cair e está perto: já nasce lá em cima (senão aparecia um quadro no chão antes de cair)
		if (at - eye).Magnitude <= 170 and workspace:GetServerTimeNow() - info.Born < BAG_FALL then
			bagPose(info, os.clock(), workspace:GetServerTimeNow())
		end
		refreshBags()
	end

	function removeBag(model: Instance)
		bags[model] = nil
	end

	-- algumas vezes por segundo: o relógio da plaquinha (só o dono vê o tempo), o tamanho dela para a
	-- distância e o pisca-pisca do fim
	function refreshBags()
		local now = workspace:GetServerTimeNow()
		for model, info in bags do
			if not model.Parent then
				bags[model] = nil
				continue
			end
			local left = math.max(0, math.ceil(info.Until - now))
			if left ~= info.Left then
				info.Left = left
				local icon = if info.Golden then "✨💰" else "💰"
				info.Label.Text = if info.Mine then ("%s %ds"):format(icon, left) else icon
				info.Label.TextColor3 = if info.Mine and left <= BAG_BLINK then TEXT_RED else TEXT_YELLOW
			end
			local d = (info.At - eye).Magnitude
			if d < (if info.Mine then BAG_MAX else BAG_MAX_OTHER) + 12 then
				-- a caixa do texto tem 80% da altura da plaquinha
				local k = d * BAG_TEXT_PX / (pxStud * info.H * 0.8)
				k = math.floor(math.clamp(k, 1, if info.Mine then BAG_KMAX else BAG_KMAX_OTHER) * 4 + 0.5) / 4
				if k ~= info.K then
					bagPlate(info, k)
				end
			end
			local blink = info.Until - now < BAG_BLINK and math.floor(now * 2.5) % 2 == 0
			setAlpha(info, if blink then 0.5 else 0)
		end
	end

	-- todo quadro (só de perto): cai do céu, depois gira devagar e sobe-desce
	function stepBags(t: number, now: number)
		for model, info in bags do
			if not model.Parent or (info.At - eye).Magnitude > 170 then
				continue
			end
			bagPose(info, t, now)
		end
	end

	-- Para a seta de ajuda: (onde está o saco do MEU terreno, distância mínima, altura da setinha acima do
	-- alvo: logo acima da plaquinha do saco) ou nil
	function bagTarget(s: any): (Vector3?, number, number)
		for model, info in bags do
			if info.Mine and info.Plot == s.Plot and model.Parent then
				return info.At + Vector3.new(0, 2, 0), math.max(3, num((Config.MoneyBag or {}).Radius) - 1.5), info.Top - 2 + 1.6
			end
		end
		return nil, 0, 0
	end
end

-- ---------------------------------------------------------------------------
-- 13d. CHAVES SECRETAS (tag VUOKey) e BAÚ SECRETO (tag VUOChest DENTRO de um terreno). Versão 5.
-- A chave é para PROCURAR: gira devagar, sobe e desce, com um brilho pequeno (sem facho de luz, sem
-- plaquinha). Passados Config.Keys.Hint segundos do nascimento (atributo Born, hora do servidor) ela passa
-- a brilhar forte e a soltar faíscas altas (ninguém fica travado); a tela avisa uma vez (World.OnKeyHint).
-- O baú tem uma plaquinha: nome + "🗝️ n/m"; com as chaves todas vira "ABRIR!", o baú pula e a seta de ajuda
-- aponta para ele (só no MEU terreno; no dos outros, só o nome).
-- A tag VUOChest também é a do baú do obby (na praça): quem separa os dois é estar dentro de um terreno.
-- As peças são animadas uma a uma em volta do ponto onde o servidor pôs o modelo (não usa PivotTo: assim
-- não depende de o modelo ter PrimaryPart). Tudo que é criado aqui fica DENTRO do modelo e some com ele.
-- ---------------------------------------------------------------------------
-- (O arquivo está no limite de 200 variáveis locais do Luau: o que é da versão 5 fica dentro de funções, que
-- têm a conta delas, e o resto do arquivo chama pela tabela V5.)
local V5: any = {}
function V5.BuildKeys()
	local keys, addKey, removeKey, refreshKeys, stepKeys
	local secrets, addSecret, removeSecret, refreshSecrets, stepSecrets, secretTarget
	local KEY: any = Config.Keys or {}
	local KEY_COLOR: Color3 = if typeof(KEY.Color) == "Color3" then KEY.Color else GOLD
	local KEY_HINT = num(KEY.Hint) -- 0 = a chave nunca passa a brilhar forte
	local KEY_NEAR = 170 -- mais longe que isto a chave não é animada
	keys = {}
	World.OnKeyHint = nil :: ((keyId: any) -> ())? -- a tela liga aqui: a MINHA chave começou a brilhar forte

	-- as peças do modelo e onde cada uma fica em relação ao ponto de descanso
	local function relParts(model: Instance, rest: CFrame): { any }
		local list = {}
		for _, part in partsOf(model) do
			table.insert(list, { Part = part, Rel = rest:ToObjectSpace(part.CFrame) })
		end
		return list
	end

	local function ownerOf(model: Instance, plot: Instance?): any
		local ownerId = model:GetAttribute("OwnerId")
		if ownerId == nil and plot then
			ownerId = plot:GetAttribute("OwnerId")
		end
		return ownerId
	end

	function addKey(model: Instance)
		if keys[model] or not model:IsA("Model") or not model.Parent then
			return
		end
		local born = model:GetAttribute("Born")
		if type(born) ~= "number" or not model:FindFirstChildWhichIsA("BasePart", true) then
			return -- o atributo ou as peças ainda não chegaram: a varredura tenta de novo
		end
		local plot = plotOf(model)
		local ownerId = ownerOf(model, plot)
		local rest = model:GetPivot() -- onde o servidor pôs (a chave anima em volta deste ponto)
		local parts = relParts(model, rest) -- (antes de criar a peça de apoio: só a chave gira)
		local at = rest.Position
		-- peça de apoio SEM rotação: a luz e as faíscas ficam nela (a chave gira; elas não)
		local a = fxPart({ Name = "KeyFx", Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(at + Vector3.new(0, 0.6, 0)), Parent = model })
		local light = new("PointLight", { Name = "KeyLight", Color = KEY_COLOR, Range = 5, Brightness = 0.35, Parent = a })
		-- brilho discreto: uma faísca pequena de vez em quando
		local glint = new("ParticleEmitter", {
			Name = "KeyGlint",
			Texture = SPARK,
			Color = ColorSequence.new(KEY_COLOR:Lerp(Color3.new(1, 1, 1), 0.3)),
			Size = NumberSequence.new(0.4, 0),
			Lifetime = NumberRange.new(0.6, 1),
			Speed = NumberRange.new(0.5, 1.5),
			SpreadAngle = Vector2.new(180, 180),
			LightEmission = 1,
			Rate = 1.5,
			Parent = a,
		})
		-- dica (só depois de KEY_HINT segundos): um chafariz de faíscas que passa por cima das cercas
		local sparks = new("ParticleEmitter", {
			Name = "KeySpark",
			Texture = SPARK,
			Color = ColorSequence.new(KEY_COLOR),
			Size = NumberSequence.new(1, 0),
			Lifetime = NumberRange.new(1.2, 1.8),
			Speed = NumberRange.new(14, 20),
			SpreadAngle = Vector2.new(10, 10),
			EmissionDirection = Enum.NormalId.Top,
			LightEmission = 1,
			Rate = 12,
			Enabled = false,
			Parent = a,
		})
		keys[model] = {
			Model = model,
			Plot = plot,
			Mine = ownerId ~= nil and ownerId == player.UserId,
			KeyId = model:GetAttribute("KeyId"),
			Born = born,
			At = at,
			Turn = rest.Rotation,
			Parts = parts,
			Light = light,
			Glint = glint,
			Sparks = sparks,
			Hint = false,
			Angle = math.random() * 6,
			Phase = math.random() * 6,
		}
		refreshKeys()
	end

	function removeKey(model: Instance)
		keys[model] = nil
	end

	-- algumas vezes por segundo: já passou o tempo da dica? (brilho forte + faíscas altas + aviso na tela)
	function refreshKeys()
		local now = workspace:GetServerTimeNow()
		for model, info in keys do
			if not model.Parent then
				keys[model] = nil
				continue
			end
			local hint = KEY_HINT > 0 and now - info.Born >= KEY_HINT
			if hint ~= info.Hint then
				info.Hint = hint
				info.Light.Range = if hint then 16 else 5
				info.Light.Brightness = if hint then 2.2 else 0.35
				info.Glint.Rate = if hint then 7 else 1.5
				info.Sparks.Enabled = hint
				if hint and info.Mine and World.OnKeyHint then
					task.spawn(safe, "keyHint", World.OnKeyHint, info.KeyId)
				end
			end
		end
	end

	-- todo quadro (só de perto): gira devagar (mais rápido com a dica) e sobe-desce
	function stepKeys(dt: number, t: number)
		for model, info in keys do
			if not model.Parent or (info.At - eye).Magnitude > KEY_NEAR then
				continue
			end
			info.Angle += dt * (if info.Hint then 2.4 else 0.9)
			local pose = CFrame.new(info.At + Vector3.new(0, 0.45 + 0.3 * math.sin(t * 2 + info.Phase), 0)) * CFrame.Angles(0, info.Angle, 0) * info.Turn
			for _, item in info.Parts do
				item.Part.CFrame = pose * item.Rel
			end
		end
	end

	-- ----- Baú Secreto -----
	local CHEST_W, CHEST_H = 7.6, 2.9 -- plaquinha do dono (nome + chaves), em studs, antes da escala
	local CHEST_W_OTHER, CHEST_H_OTHER = 6.4, 1.5 -- visitante: só o nome
	local CHEST_GAP = 0.9 -- do topo do baú até a base da plaquinha
	local CHEST_MAX, CHEST_MAX_OTHER = 110, 60 -- até onde aparece (teto; em tela pequena some antes de virar borrão)
	local CHEST_TEXT_PX = 15 -- de longe a plaquinha cresce para a linha do nome ter pelo menos isto na tela
	local CHEST_MIN_PX = 9 -- e some quando nem crescendo o nome chega a isto
	local CHEST_KMAX, CHEST_KMAX_OTHER = 2.4, 1.8 -- (o baú fica ao lado do portão: a plaquinha não pode crescer a ponto de tampar a entrada)
	secrets = {}

	local function secretPlate(info: any, k: number)
		info.K = k
		info.Gui.Size = UDim2.new(info.W * k, 0, info.H * k, 0)
		info.Top = info.Height + CHEST_GAP + info.H * k -- topo da plaquinha, medido do chão (a seta fica acima)
		info.Gui.StudsOffsetWorldSpace = liftOf(info.Anchor, CHEST_GAP + info.H * k / 2)
	end

	function addSecret(model: Instance)
		if secrets[model] or not model:IsA("Model") or not model.Parent then
			return
		end
		local plot = plotOf(model)
		if not plot or not model:FindFirstChildWhichIsA("BasePart", true) then
			return
		end
		local ownerId = ownerOf(model, plot)
		local isMine = ownerId ~= nil and ownerId == player.UserId
		local rest = model:GetPivot()
		local parts = relParts(model, rest)
		local at = rest.Position
		-- topo e meio do baú: os do modelo que chegou (a arte pode mudar); sem eles, os do baú de hoje
		local center, height = at, 4.2
		local okBox, boxCF, boxSize = pcall(model.GetBoundingBox, model)
		if okBox and typeof(boxCF) == "CFrame" and typeof(boxSize) == "Vector3" and boxSize.Y > 0.5 and boxSize.Y < 40 then
			center = boxCF.Position
			height = math.max(1, boxCF.Position.Y + boxSize.Y / 2 - at.Y)
		end
		-- peça de apoio SEM rotação, no topo do baú: a plaquinha e as faíscas ficam nela (o baú pula; elas não)
		local a = fxPart({ Name = "ChestFx", Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(center.X, at.Y + height, center.Z), Parent = model })
		local sparks = new("ParticleEmitter", {
			Name = "ChestSpark",
			Texture = SPARK,
			Color = ColorSequence.new(KEY_COLOR),
			Size = NumberSequence.new(0.7, 0),
			Lifetime = NumberRange.new(0.7, 1.2),
			Speed = NumberRange.new(3, 6),
			SpreadAngle = Vector2.new(180, 180),
			LightEmission = 1,
			Rate = 8,
			Enabled = false,
			Parent = a,
		})
		local w, h = if isMine then CHEST_W else CHEST_W_OTHER, if isMine then CHEST_H else CHEST_H_OTHER
		local gui = billboard({
			Name = "ChestTag",
			Size = UDim2.new(w, 0, h, 0),
			StudsOffsetWorldSpace = liftOf(a, CHEST_GAP + h / 2),
			MaxDistance = if isMine then CHEST_MAX else CHEST_MAX_OTHER,
			Adornee = a,
			Parent = a,
		})
		plateBg(gui, 0.2, 0.22)
		local title = plateText(gui, { Name = "Title", Position = UDim2.fromScale(0.05, if isMine then 0.07 else 0.12), Size = UDim2.fromScale(0.9, if isMine then 0.4 else 0.76), TextColor3 = KEY_COLOR:Lerp(C.White, 0.25) })
		local sub = plateText(gui, { Name = "Sub", Position = UDim2.fromScale(0.05, 0.5), Size = UDim2.fromScale(0.9, 0.43), Visible = isMine })
		secrets[model] = {
			Model = model,
			Plot = plot,
			Mine = isMine,
			At = at,
			Rest = rest,
			Parts = parts,
			Height = height,
			Anchor = a,
			Sparks = sparks,
			Gui = gui,
			Title = title,
			Sub = sub,
			W = w,
			H = h,
			K = 1,
			MaxDist = if isMine then CHEST_MAX else CHEST_MAX_OTHER,
			Top = height + CHEST_GAP + h,
			Keys = -1,
			Need = -1,
			Ready = false,
			Moved = false,
			Pop = -100,
			Phase = math.random() * 6,
		}
		refreshSecrets()
	end

	function removeSecret(model: Instance)
		secrets[model] = nil
	end

	local function secretText(info: any)
		info.Title.Text = T("chest.name")
		if info.Mine then
			info.Sub.Text = if info.Ready then T("chest.keysReady") else T("chest.need", { n = math.max(info.Keys, 0), m = math.max(info.Need, 0) })
			info.Sub.TextColor3 = if info.Ready then TEXT_GREEN else C.White
		end
	end

	-- algumas vezes por segundo: quantas chaves o dono tem (atributos Keys e Need), o texto e o tamanho da
	-- plaquinha para a distância
	function refreshSecrets(relabel: boolean?)
		for model, info in secrets do
			if not model.Parent then
				secrets[model] = nil
				continue
			end
			local have, need = num(model:GetAttribute("Keys")), num(model:GetAttribute("Need"))
			if have ~= info.Keys or need ~= info.Need or relabel then
				info.Keys = have
				info.Need = need
				info.Ready = info.Mine and need > 0 and have >= need
				info.Sparks.Enabled = info.Ready
				secretText(info)
			end
			-- a linha do nome tem 40% da altura da plaquinha do dono (76% na do visitante); as distâncias saem do
			-- tamanho desta tela (pxStud): num celular a plaquinha cresce mais cedo e some mais cedo
			local line = info.H * (if info.Mine then 0.4 else 0.76)
			local kMax = if info.Mine then CHEST_KMAX else CHEST_KMAX_OTHER
			local maxDist = math.clamp(line * kMax * pxStud / CHEST_MIN_PX, 30, if info.Mine then CHEST_MAX else CHEST_MAX_OTHER)
			if math.abs(maxDist - info.MaxDist) > 1 then
				info.MaxDist = maxDist
				info.Gui.MaxDistance = maxDist
			end
			local d = (info.At - eye).Magnitude
			if d < maxDist + 12 then
				local k = math.floor(math.clamp(d * CHEST_TEXT_PX / (pxStud * line), 1, kMax) * 4 + 0.5) / 4
				if k ~= info.K then
					secretPlate(info, k)
				end
			end
		end
	end

	-- todo quadro (só de perto): com as chaves todas o baú pula de leve; ao abrir dá um pulo grande
	function stepSecrets(t: number)
		local clock = os.clock()
		for model, info in secrets do
			if not model.Parent then
				continue
			end
			local pop = clock - info.Pop
			local hopping = (info.Ready or pop < 0.7) and (info.At - eye).Magnitude < KEY_NEAR
			if hopping then
				local lift = if info.Ready then math.abs(math.sin(t * 4.5 + info.Phase)) * 0.55 else 0
				local tilt = if info.Ready then math.sin(t * 9 + info.Phase) * 0.04 else 0
				if pop < 0.7 then
					lift += math.sin(math.clamp(pop / 0.7, 0, 1) * math.pi) * 2.2
				end
				local pose = info.Rest * CFrame.new(0, lift, 0) * CFrame.Angles(0, 0, tilt)
				for _, item in info.Parts do
					item.Part.CFrame = pose * item.Rel
				end
				info.Moved = true
			elseif info.Moved then
				-- parou de pular: volta exatamente para onde o servidor pôs
				info.Moved = false
				for _, item in info.Parts do
					item.Part.CFrame = info.Rest * item.Rel
				end
			end
		end
	end

	-- Para a seta de ajuda: (onde está o baú do MEU terreno quando já dá para abrir, distância mínima, altura
	-- da setinha acima do alvo: logo acima da plaquinha) ou nil
	function secretTarget(s: any): (Vector3?, number, number)
		for model, info in secrets do
			if info.Mine and info.Ready and info.Plot == s.Plot and model.Parent then
				return info.At + Vector3.new(0, 2, 0), math.max(3, num(KEY.ChestRadius) - 1.5), info.Top - 2 + 1.6
			end
		end
		return nil, 0, 0
	end

	-- Fx "chestOpen" (todos veem): o baú dá um pulo, clarão dourado, moedas e brilho. A posição que o servidor
	-- manda pode vir em qualquer altura: se o baú ainda está lá, vale o lugar dele.
	function World.ChestOpen(position: Vector3?, golden: boolean?)
		local at: Vector3? = nil
		local top = 4.2
		for model, info in secrets do
			if model.Parent and (position == nil or ((info.At - position) * Vector3.new(1, 0, 1)).Magnitude < 14) and (position ~= nil or info.Mine) then
				at = info.At
				top = info.Height
				info.Pop = os.clock()
				break
			end
		end
		at = at or position
		if not at or (at - eye).Magnitude > 450 then
			return -- (longe demais para ver: o pulo do baú já ficou marcado, o resto nem é criado)
		end
		local mouth = at + Vector3.new(0, top, 0)
		World.Puff(mouth)
		World.Ping(at + Vector3.new(0, 4.4, 0), KEY_COLOR) -- (o Ping desenha o anel 4 studs abaixo do ponto: rente ao chão)
		World.CoinBurst(mouth, if golden then 16 else 12)
		local a = anchor(mouth + Vector3.new(0, 1.5, 0))
		local flash = new("PointLight", { Color = KEY_COLOR, Range = if golden then 36 else 26, Brightness = 4, Parent = a })
		TweenService:Create(flash, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
		task.delay(1, function()
			a:Destroy()
		end)
	end

	V5.addKey, V5.removeKey, V5.refreshKeys, V5.stepKeys = addKey, removeKey, refreshKeys, stepKeys
	V5.addSecret, V5.removeSecret, V5.refreshSecrets, V5.stepSecrets, V5.secretTarget = addSecret, removeSecret, refreshSecrets, stepSecrets, secretTarget
end
V5.BuildKeys()

-- ---------------------------------------------------------------------------
-- Placas: "Em breve: Pata" e textos fixos que mudam com o idioma
-- ---------------------------------------------------------------------------
local refreshPreview, refreshText
do
	local function surfaceLabel(part: Instance): TextLabel?
		local gui = part:FindFirstChildWhichIsA("SurfaceGui")
		if not gui then
			gui = new("SurfaceGui", { Name = "Gui", Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 30, LightInfluence = 0, AutoLocalize = false, Parent = part })
		end
		local label = gui:FindFirstChildWhichIsA("TextLabel")
		if not label then
			-- SurfaceGui tem tela própria (pixels por stud): aqui o contorno do texto acompanha a letra
			label = new("TextLabel", {
				Name = "Text",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Font = UI.Font,
				TextScaled = true,
				TextColor3 = C.White,
				TextStrokeColor3 = C.DarkBrown,
				TextStrokeTransparency = 0,
				Text = "",
				Parent = gui,
			})
		end
		return label
	end

	function refreshPreview(model: Instance)
		local line = Config.Lines[model:GetAttribute("Line")]
		if not line then
			return
		end
		local text = T("preview", { bird = T("bird." .. line.Id) })
		local face = model:FindFirstChild("Letreiro", true)
		if face and face:IsA("BasePart") then
			local label = surfaceLabel(face)
			if label then
				label.Text = text
			end
			return
		end
		-- a placa virou malha (sem a peça "Letreiro"): o texto vai numa plaquinha em cima dela
		local root = if model:IsA("Model") then model.PrimaryPart else nil
		if not root then
			return
		end
		local gui = model:FindFirstChild("PreviewTag")
		if not gui then
			gui = billboard({ Name = "PreviewTag", Size = UDim2.new(7, 0, 2.2, 0), StudsOffsetWorldSpace = Vector3.new(0, 7, 0), MaxDistance = 70, Adornee = root, Parent = model })
			plateBg(gui, 0.25, 0.25)
			plateText(gui, { Name = "Text", Position = UDim2.fromScale(0.05, 0.08), Size = UDim2.fromScale(0.9, 0.84) })
		end
		local label = gui:FindFirstChild("Text")
		if label and label:IsA("TextLabel") then
			label.Text = text
		end
	end

	function refreshText(part: Instance)
		local key = part:GetAttribute("TextKey")
		if type(key) == "string" then
			local label = surfaceLabel(part)
			if label then
				label.Text = T(key)
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Macieira, caça aos ovos, curtir
-- ---------------------------------------------------------------------------
local addTree, refreshTrees, refreshHunt, refreshLikes
do
	local treeGuis: { [Instance]: any } = {}

	function addTree(tree: Instance)
		if treeGuis[tree] or not tree:IsA("Model") or not tree.PrimaryPart then
			return
		end
		local gui = billboard({ Name = "Apples", Size = UDim2.new(5, 0, 1.9, 0), StudsOffsetWorldSpace = Vector3.new(0, 13, 0), MaxDistance = 120, Enabled = false, Adornee = tree.PrimaryPart, Parent = tree })
		plateBg(gui, 0.3, 0.4)
		local label = plateText(gui, { Position = UDim2.fromScale(0.08, 0.1), Size = UDim2.fromScale(0.84, 0.8) })
		treeGuis[tree] = { Gui = gui, Label = label, Count = -1 }
	end

	function refreshTrees()
		for tree, info in treeGuis do
			if not tree.Parent then
				treeGuis[tree] = nil
			else
				local plot = plotOf(tree)
				local apples = num(plot and plot:GetAttribute("Apples"))
				if apples ~= info.Count then
					info.Count = apples
					info.Label.Text = if apples > 0 then ("🍎 x%d"):format(apples) else ""
					info.Gui.Enabled = apples > 0
				end
			end
		end
	end

	function refreshHunt()
		for _, egg in CollectionService:GetTagged("VUOHunt") do
			local index = egg:GetAttribute("Index")
			local found = state ~= nil and state.HuntFound ~= nil and state.HuntFound[tostring(index)] == true
			if egg:GetAttribute("FoundShown") ~= found then
				egg:SetAttribute("FoundShown", found) -- só mexe nas peças quando muda (isto roda a cada estado novo)
				for _, d in egg:GetDescendants() do
					if d:IsA("BasePart") and d.Name ~= "Root" then
						d.LocalTransparencyModifier = if found then 1 else 0
					elseif d:IsA("PointLight") or d:IsA("ParticleEmitter") then
						d.Enabled = not found
					end
				end
			end
		end
	end

	function refreshLikes()
		for _, prompt in CollectionService:GetTagged("VUOLike") do
			if prompt:IsA("ProximityPrompt") then
				local plot = plotOf(prompt)
				local owner = plot and plot:GetAttribute("OwnerId") or 0
				local enabled = owner ~= 0 and owner ~= player.UserId
				if prompt.Enabled ~= enabled then
					prompt.Enabled = enabled
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Aves pulando e moinhos girando
-- ---------------------------------------------------------------------------
local addHen, removeHen, stepHens, addMill, stepMills
do
	local hens: { [Instance]: CFrame } = {}
	local mills: { [Instance]: { Hub: CFrame, Parts: { { Part: BasePart, Rel: CFrame } }, Angle: number } } = {}

	function addHen(hen: Instance)
		if hen:IsA("Model") and hen.Parent and not hens[hen] then
			hens[hen] = hen:GetPivot()
		end
	end

	function removeHen(hen: Instance)
		hens[hen] = nil
	end

	-- v6: no celular, mexer dezenas de aves por frame pesava. Agora só as perto (90 studs) e metade por
	-- frame (cada ave pula a 30 quadros por segundo, que o olho não percebe).
	local henFrame = 0
	function stepHens(t: number)
		if World.Light then
			return
		end
		henFrame += 1
		local half = henFrame % 2
		local i = 0
		for hen, base in hens do
			i += 1
			if not hen.Parent then
				hens[hen] = nil
			elseif i % 2 == half and (base.Position - eye).Magnitude < 90 then
				local model: any = hen
				local phase = num(model:GetAttribute("Phase"))
				local hop = math.max(0, math.sin(t * 3 + phase)) * 0.28
				local tilt = math.sin(t * 1.5 + phase) * 0.1
				model:PivotTo(base * CFrame.new(0, hop, 0) * CFrame.Angles(0, tilt, 0))
			end
		end
	end

	function addMill(mill: Instance)
		if mills[mill] or not mill:IsA("Model") or not mill.PrimaryPart then
			return
		end
		local hub = mill:FindFirstChild("Eixo", true)
		if not hub or not hub:IsA("BasePart") then
			return -- moinho em malha (sem as pás soltas): fica parado
		end
		local hubCF = CFrame.new(hub.CFrame.Position) * (mill.PrimaryPart.CFrame - mill.PrimaryPart.CFrame.Position)
		local parts = {}
		for _, d in mill:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "Pa" then
				table.insert(parts, { Part = d, Rel = hubCF:ToObjectSpace(d.CFrame) })
			end
		end
		mills[mill] = { Hub = hubCF, Parts = parts, Angle = math.random() * 6 }
	end

	function stepMills(dt: number)
		for mill, info in mills do
			if not mill.Parent then
				mills[mill] = nil
			elseif (info.Hub.Position - eye).Magnitude < 420 then
				info.Angle += dt * 0.7
				local spin = info.Hub * CFrame.Angles(0, 0, info.Angle)
				for _, item in info.Parts do
					item.Part.CFrame = spin * item.Rel
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Máquinas e laboratório: peças "Gira" rodam, "Pistao" sobe e desce (tags VUOMachine e VUOSpin)
-- ---------------------------------------------------------------------------
local addSpinner, stepSpinners
do
	local spinners: { [Instance]: any } = {}

	function addSpinner(model: Instance)
		if spinners[model] or not model:IsA("Model") or not model.Parent then
			return
		end
		local info = { At = model:GetPivot().Position, Spin = {}, Bob = {}, Speed = if CollectionService:HasTag(model, "VUOMachine") then 3 else 0.8 }
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				if d.Name == "Gira" then
					table.insert(info.Spin, { Part = d, Base = d.CFrame })
				elseif d.Name == "Pistao" then
					table.insert(info.Bob, { Part = d, Base = d.CFrame })
				end
			end
		end
		if #info.Spin == 0 and #info.Bob == 0 then
			return -- modelo em malha (ou as peças ainda não chegaram): a varredura tenta de novo
		end
		spinners[model] = info
	end

	function stepSpinners(t: number)
		for model, info in spinners do
			if not model.Parent then
				spinners[model] = nil
			elseif (info.At - eye).Magnitude < 260 then
				local turn = CFrame.Angles(0, t * info.Speed, 0)
				for _, item in info.Spin do
					item.Part.CFrame = CFrame.new(item.Base.Position) * turn * item.Base.Rotation
				end
				-- o pistão bate rápido e sobe devagar
				local phase = (t * 1.6) % 1
				local down = if phase < 0.15 then phase / 0.15 else 1 - (phase - 0.15) / 0.85
				for _, item in info.Bob do
					item.Part.CFrame = item.Base + Vector3.new(0, 0.4 - down * 0.9, 0)
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Pets: seguem cada jogador (o servidor só diz QUAIS são, no atributo "Pets" do jogador)
-- ---------------------------------------------------------------------------
local petSets, clearPets, stepPets
do
	petSets = {}

	-- own = pet do próprio jogador (com luz e mais brilho); pets dos outros vêm mais leves (v6)
	local function makePet(key: string, level: number, own: boolean): Model?
		local lineId, mut = Sim.ParseKey(key)
		local special = Config.SpecialPets[lineId]
		local model: Model?
		local color = C.Yellow
		if special then
			model = AssetLib.Get(special.Asset, 1 + 0.04 * (level - 1))
			color = Config.Giant.VariantColor[mut] or C.Yellow
			if model then
				for _, d in model:GetDescendants() do
					if d:IsA("BasePart") then
						if d.Name == "Corpo" or d.Name == "Tampinha" then
							d.Color = color
						elseif d.Name == "Asa" then
							d.Color = color:Lerp(Color3.new(1, 1, 1), 0.35)
						end
					end
				end
			end
		else
			local line = Config.LineById[lineId]
			local mutation = Config.MutationById[mut]
			if not line or not mutation then
				return nil
			end
			color = mutation.Color
			model = AssetLib.Get(line.Asset, Config.Pets.Scale * mutation.Scale * (1 + 0.03 * (level - 1)))
		end
		if not model or not model.PrimaryPart then
			return nil
		end
		AssetLib.SetCollide(model, false)
		model.Name = "Pet"
		local root = model.PrimaryPart
		new("ParticleEmitter", {
			Texture = SPARK,
			Color = ColorSequence.new(color),
			Size = NumberSequence.new(0.45, 0),
			Lifetime = NumberRange.new(0.5, 0.9),
			Speed = NumberRange.new(1, 2.5),
			SpreadAngle = Vector2.new(180, 180),
			LightEmission = 0.8,
			Rate = if not own then 2 elseif mut == "s" then 3 else 7,
			Parent = root,
		})
		if own and (special or mut ~= "s") then
			new("PointLight", { Color = color, Range = 9, Brightness = 1.4, Parent = root })
		end
		local gui = billboard({ Name = "Tag", Size = UDim2.new(5.6, 0, 1.15, 0), StudsOffsetWorldSpace = Vector3.new(0, model:GetExtentsSize().Y + 1, 0), MaxDistance = 42, Adornee = root, Parent = root })
		plateBg(gui, 0.35, 0.4)
		plateText(gui, { Position = UDim2.fromScale(0.05, 0.12), Size = UDim2.fromScale(0.9, 0.76), Text = ("%s  Nv %d"):format(Lang.Pet(Config, key), level), TextColor3 = color:Lerp(C.White, 0.2) })
		model.Parent = fxFolder
		return model
	end

	function clearPets(owner: Player)
		local set = petSets[owner]
		if set then
			for _, pet in set.Pets do
				pet.Model:Destroy()
			end
			petSets[owner] = nil
		end
	end

	-- Modo leve ligou/desligou: refaz os pets na próxima volta (com ou sem os dos outros)
	function World.ResetPets()
		for owner in petSets do
			clearPets(owner)
		end
	end

	function stepPets(dt: number, t: number)
		for _, owner in Players:GetPlayers() do
			local text = owner:GetAttribute("Pets")
			if type(text) ~= "string" then
				text = ""
			end
			local character = owner.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local set = petSets[owner]
			-- v6: aparece a 200 studs e só some depois de 240 (antes sumia e voltava sem parar na borda)
			local near = root ~= nil and root:IsA("BasePart") and (root.CFrame.Position - eye).Magnitude < (if set then 240 else 200)
			if not near or text == "" then
				if set then
					clearPets(owner)
				end
				continue
			end
			if not set or set.Text ~= text then
				clearPets(owner)
				set = { Text = text, Pets = {} }
				petSets[owner] = set
				for entry in string.gmatch(text, "[^,]+") do
					local key, level = string.match(entry, "^(.-)=(%d+)$")
					local isOwn = owner == Players.LocalPlayer
					if key and #set.Pets < (if isOwn then 8 elseif World.Light then 0 else 3) then -- dos outros, só os 3 primeiros (leve no celular)
						local model = makePet(key, tonumber(level) or 1, isOwn)
						if model then
							table.insert(set.Pets, { Model = model, Position = nil, Look = Vector3.new(0, 0, -1) })
						end
					end
				end
			end
			local rootPart = root :: BasePart
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local ground = rootPart.CFrame.Position.Y - rootPart.Size.Y / 2 - (if humanoid then humanoid.HipHeight else 2)
			local look = rootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
			look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
			local right = Vector3.new(-look.Z, 0, look.X)
			local n = #set.Pets
			for i, pet in set.Pets do
				local lateral = (i - (n + 1) / 2) * 3.4
				local flat = rootPart.CFrame.Position - look * (4.5 + math.abs(lateral) * 0.35) + right * lateral
				local target = Vector3.new(flat.X, ground, flat.Z)
				local position = pet.Position
				if not position or (position - target).Magnitude > 70 then
					position = target
				else
					position = position:Lerp(target, 1 - math.exp(-5 * dt))
				end
				local moving = (target - position).Magnitude
				local step = (target - position) * Vector3.new(1, 0, 1)
				if step.Magnitude > 0.6 then
					pet.Look = pet.Look:Lerp(step.Unit, 1 - math.exp(-8 * dt))
				elseif moving < 0.3 then
					pet.Look = pet.Look:Lerp(look, 1 - math.exp(-3 * dt))
				end
				pet.Position = position
				local hop = if moving > 0.5 then math.abs(math.sin(t * 9 + i * 1.3)) * 0.7 else math.max(0, math.sin(t * 2.4 + i * 2)) * 0.2
				local facing = if pet.Look.Magnitude > 0.01 then pet.Look.Unit else look
				pet.Model:PivotTo(CFrame.lookAt(position + Vector3.new(0, hop, 0), position + Vector3.new(0, hop, 0) + facing))
			end
		end
		for owner in petSets do
			if not owner.Parent then
				clearPets(owner)
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Chocadeiras: relógio em cima e o ovo balançando quando está para nascer
-- ---------------------------------------------------------------------------
local incubators, addIncubator, refreshIncubators, stepIncubators
do
	incubators = {}

	function addIncubator(model: Instance)
		if incubators[model] or not model:IsA("Model") or not model.PrimaryPart then
			return
		end
		local gui = billboard({ Name = "Clock", Size = UDim2.new(7.6, 0, 1.8, 0), StudsOffsetWorldSpace = Vector3.new(0, 9, 0), MaxDistance = 90, Adornee = model.PrimaryPart, Parent = model })
		-- o texto é filho direto da placa (o teste do jogo procura o primeiro TextLabel dela); o fundo fica atrás
		local label = plateText(gui, { Position = UDim2.fromScale(0.05, 0.12), Size = UDim2.fromScale(0.9, 0.76) })
		local bg = plateBg(gui, 0.25, 0.4)
		incubators[model] = { Gui = gui, Label = label, Bg = bg, Slot = model:GetAttribute("Slot") or 1, Egg = nil, Base = nil, Left = 0, Busy = false, Text = "" }
	end

	function refreshIncubators()
		local now = workspace:GetServerTimeNow()
		for model, info in incubators do
			if not model.Parent then
				incubators[model] = nil
				continue
			end
			local plot = plotOf(model)
			local value = plot and plot:GetAttribute("Hatch" .. info.Slot)
			local key, ready = nil, nil
			if type(value) == "string" and value ~= "" then
				key, ready = string.match(value, "^(.-)|(%-?%d+)$")
			end
			local isMine = plot ~= nil and plot:GetAttribute("OwnerId") == player.UserId
			local text, color
			if key and ready then
				local left = (tonumber(ready) or 0) - now
				info.Busy = true
				info.Left = left
				if left <= 0 then
					text = if isMine then T("inc.ready") else "🐣"
					color = TEXT_GREEN
				else
					text = "🥚 " .. Format.Time(left)
					color = C.White
				end
				local egg = info.Egg
				if not egg or not egg.Parent then
					local found = plot and plot:FindFirstChild("HatchEgg" .. info.Slot, true)
					if found and found:IsA("Model") then
						info.Egg = found
						info.Base = found:GetPivot()
					else
						info.Egg = nil
					end
				end
			else
				info.Busy = false
				info.Egg = nil
				text = if isMine then T("inc.empty") else ""
				color = C.Cream
			end
			if text ~= info.Text then
				info.Text = text
				info.Label.Text = text
				info.Label.TextColor3 = color
				info.Bg.Visible = text ~= ""
			end
		end
	end

	function stepIncubators(t: number)
		for _, info in incubators do
			local egg, base = info.Egg, info.Base
			if info.Busy and egg and base and egg.Parent and info.Left < 12 then
				local power = if info.Left <= 0 then 0.22 else 0.1
				egg:PivotTo(base * CFrame.Angles(math.sin(t * 13) * power, 0, math.cos(t * 11) * power) * CFrame.new(0, math.abs(math.sin(t * 6)) * (if info.Left <= 0 then 0.35 else 0), 0))
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Mega Ovo da praça
-- ---------------------------------------------------------------------------
local addGiant, stepGiant, refreshGiant
do
	local giantEgg: any = nil

	function addGiant(model: Instance)
		if not model:IsA("Model") or not model.PrimaryPart then
			return
		end
		local color = Config.Giant.VariantColor[model:GetAttribute("Variant")] or C.Yellow
		local height = model:GetExtentsSize().Y * Layout.Giant[5] / Layout.Giant[4]
		local gui = billboard({ Name = "Info", Size = UDim2.new(26, 0, 7, 0), StudsOffsetWorldSpace = Vector3.new(0, height + 4, 0), MaxDistance = 420, Adornee = model.PrimaryPart, Parent = model })
		-- os textos são filhos diretos da placa (o primeiro TextLabel é o da porcentagem); o fundo fica atrás
		local label = plateText(gui, { Name = "Title", Position = UDim2.fromScale(0.04, 0.06), Size = UDim2.fromScale(0.92, 0.52), TextColor3 = color:Lerp(C.White, 0.15) })
		local sub = plateText(gui, { Name = "Sub", Position = UDim2.fromScale(0.04, 0.62), Size = UDim2.fromScale(0.92, 0.3) })
		plateBg(gui, 0.4, 0.2)
		local glow: Highlight? = nil
		pcall(function()
			glow = new("Highlight", { FillColor = color, OutlineColor = Color3.new(1, 1, 1), FillTransparency = 1, OutlineTransparency = 1, DepthMode = Enum.HighlightDepthMode.Occluded, Parent = model })
		end)
		local sparks = new("ParticleEmitter", {
			Texture = SPARK,
			Color = ColorSequence.new(color),
			Size = NumberSequence.new(1.6, 0),
			Lifetime = NumberRange.new(1, 1.8),
			Speed = NumberRange.new(5, 11),
			SpreadAngle = Vector2.new(180, 180),
			LightEmission = 1,
			Rate = 0,
			Parent = model.PrimaryPart,
		})
		new("PointLight", { Color = color, Range = 40, Brightness = 1.2, Parent = model.PrimaryPart })
		giantEgg = { Model = model, Base = model:GetPivot(), Label = label, Sub = sub, Glow = glow, Sparks = sparks, Rate = -1 }
	end

	-- Para a tela: (progresso 0..1, estado, hora em que racha) ou nil se o ovo não está lá
	function World.GiantInfo(): (number?, string?, number?)
		local egg = giantEgg
		if not egg or not egg.Model.Parent then
			return nil, nil, nil
		end
		return egg.Model:GetAttribute("Progress") or 0, egg.Model:GetAttribute("State") or "fill", egg.Model:GetAttribute("CrackAt") or 0
	end

	function stepGiant(t: number)
		local egg = giantEgg
		if not egg then
			return
		end
		if not egg.Model.Parent then
			giantEgg = nil
			return
		end
		if (egg.Base.Position - eye).Magnitude > 450 then
			return
		end
		local progress = num(egg.Model:GetAttribute("Progress"))
		local cracking = egg.Model:GetAttribute("State") == "crack"
		local power = if cracking then 0.09 else 0.006 + 0.03 * progress * progress
		local speed = if cracking then 17 else 2 + 5 * progress
		egg.Model:PivotTo(egg.Base * CFrame.Angles(math.sin(t * speed) * power, 0, math.cos(t * speed * 0.83) * power))
		local glow = egg.Glow
		if glow then
			glow.FillTransparency = if cracking then 0.35 + math.sin(t * 12) * 0.2 else 1 - 0.45 * progress
			glow.OutlineTransparency = if cracking then 0 else 1 - progress
		end
		local rate = if cracking then 60 else math.floor(progress * 14)
		if rate ~= egg.Rate then
			egg.Rate = rate
			egg.Sparks.Rate = rate
		end
	end

	function refreshGiant()
		local egg = giantEgg
		if not egg or not egg.Model.Parent then
			return
		end
		local progress = num(egg.Model:GetAttribute("Progress"))
		-- o ovo cresce conforme enche (só visual)
		local scale = Layout.Giant[4] + (Layout.Giant[5] - Layout.Giant[4]) * math.clamp(progress, 0, 1)
		if math.abs(egg.Model:GetScale() - scale) > 0.03 then
			egg.Model:PivotTo(egg.Base)
			egg.Model:ScaleTo(scale)
		end
		if egg.Model:GetAttribute("State") == "crack" then
			local left = math.max(0, num(egg.Model:GetAttribute("CrackAt")) - workspace:GetServerTimeNow())
			egg.Label.Text = T("giant.cracking", { t = math.ceil(left) })
			egg.Sub.Text = T("giant.near")
		else
			egg.Label.Text = T("giant.sign", { n = math.floor(progress * 100) })
			egg.Sub.Text = T("giant.help")
		end
	end

	-- Rachou: cascas voando, moedas e um clarão
	function World.GiantCrack(position: Vector3?)
		local at = position or Vector3.new(Layout.Giant[1], Layout.Giant[2] + 6, Layout.Giant[3])
		for _ = 1, 26 do
			if #coins >= MAX_COINS + 30 then
				break
			end
			local shard = fxPart({
				Size = Vector3.new(2 + math.random() * 3, 0.5, 2 + math.random() * 3),
				Color = Color3.fromRGB(255, 250, 235),
				Material = Enum.Material.SmoothPlastic,
				CFrame = CFrame.new(at + Vector3.new((math.random() - 0.5) * 8, math.random() * 8, (math.random() - 0.5) * 8)) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
				Parent = fxFolder,
			})
			table.insert(coins, { Part = shard, Velocity = Vector3.new((math.random() - 0.5) * 70, 30 + math.random() * 40, (math.random() - 0.5) * 70), Life = 1.8 })
		end
		for k = 1, 3 do
			World.CoinBurst(at + Vector3.new((k - 2) * 6, 2, 0), 16)
		end
		World.Puff(at)
		World.Ping(at, C.Yellow)
		local flash = new("ColorCorrectionEffect", { Name = "GiantFlash", Brightness = 0.45, Parent = Lighting })
		TweenService:Create(flash, TweenInfo.new(0.9), { Brightness = 0 }):Play()
		task.delay(1, function()
			flash:Destroy()
		end)
	end
end

-- ---------------------------------------------------------------------------
-- Roleta da praça (o disco gira devagar; a tela da roleta abre pelo botão de perto) e baú do obby
-- ---------------------------------------------------------------------------
local chests, addWheel, stepWheels, addWheelPrompt, addChest, refreshChests
do
	local wheels: { [Instance]: { Hub: CFrame, Parts: { { Part: BasePart, Rel: CFrame } }, Angle: number } } = {}
	local wheelFast = 0
	chests = {}

	function addWheel(wheel: Instance)
		if wheels[wheel] or not wheel:IsA("Model") or not wheel.PrimaryPart then
			return
		end
		local disk = wheel:FindFirstChild("Disco", true)
		if not disk or not disk:IsA("BasePart") then
			return
		end
		local hubCF = CFrame.new(disk.CFrame.Position) * wheel.PrimaryPart.CFrame.Rotation
		local parts = {}
		for _, d in wheel:GetDescendants() do
			if d:IsA("BasePart") and (d.Name == "Disco" or d.Name == "DiscoPeca") then
				table.insert(parts, { Part = d, Rel = hubCF:ToObjectSpace(d.CFrame) })
			end
		end
		wheels[wheel] = { Hub = hubCF, Parts = parts, Angle = 0 }
	end

	-- A roleta da praça gira rápido por alguns segundos (quando o jogador gira na tela)
	function World.WheelSpin()
		wheelFast = os.clock() + 4
	end

	function stepWheels(dt: number)
		local speed = if os.clock() < wheelFast then 7 else 0.35
		for wheel, info in wheels do
			if not wheel.Parent then
				wheels[wheel] = nil
			elseif (info.Hub.Position - eye).Magnitude < 260 then
				info.Angle += dt * speed
				local spin = info.Hub * CFrame.Angles(0, 0, info.Angle)
				for _, item in info.Parts do
					item.Part.CFrame = spin * item.Rel
				end
			end
		end
	end

	function addWheelPrompt(prompt: Instance)
		if not prompt:IsA("ProximityPrompt") or prompt:GetAttribute("Hooked") then
			return
		end
		prompt:SetAttribute("Hooked", true)
		prompt.ActionText = T("wheel.prompt")
		prompt.Triggered:Connect(function(who)
			if who == player and World.OnWheel then
				World.OnWheel()
			end
		end)
	end

	function addChest(chest: Instance)
		-- a mesma tag serve para o Baú Secreto de cada terreno (versão 5): esse tem outro desenho (bloco 13d)
		if plotOf(chest) then
			V5.addSecret(chest)
			return
		end
		if chests[chest] or not chest:IsA("Model") or not chest.PrimaryPart then
			return
		end
		local gui = billboard({ Name = "Info", Size = UDim2.new(11, 0, 2.4, 0), StudsOffsetWorldSpace = Vector3.new(0, 8, 0), MaxDistance = 220, Adornee = chest.PrimaryPart, Parent = chest })
		local label = plateText(gui, { Position = UDim2.fromScale(0.04, 0.12), Size = UDim2.fromScale(0.92, 0.76), TextColor3 = TEXT_YELLOW })
		plateBg(gui, 0.3, 0.4)
		chests[chest] = { Label = label, Text = "" }
	end

	function refreshChests()
		local left = if state and state.ObbyAt then state.ObbyAt - workspace:GetServerTimeNow() else 0
		for chest, info in chests do
			if not chest.Parent then
				chests[chest] = nil
			else
				local text = if left > 0 then T("chest.wait", { t = Format.Time(left) }) else T("chest.ready")
				if text ~= info.Text then
					info.Text = text
					info.Label.Text = text
					info.Label.TextColor3 = if left > 0 then C.Cream else TEXT_YELLOW
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Eventos: chuva de milho, presente, corrida
-- ---------------------------------------------------------------------------
local addGift, stepRain
do
	local rainPart: Part? = nil
	local rainTint: ColorCorrectionEffect? = nil

	function World.EventStart(id: string, position: Vector3?, duration: number)
		if id == "rain" then
			World.EventEnd("rain")
			local part = fxPart({ Name = "CornRain", Transparency = 1, Size = Vector3.new(110, 1, 110), Parent = fxFolder })
			new("ParticleEmitter", {
				Texture = SPARK,
				Color = ColorSequence.new(Color3.fromRGB(255, 215, 60)),
				Size = NumberSequence.new(0.55),
				Lifetime = NumberRange.new(1.6, 2.2),
				Speed = NumberRange.new(34, 46),
				EmissionDirection = Enum.NormalId.Bottom,
				Rate = 160,
				LightEmission = 0.4,
				Rotation = NumberRange.new(0, 360),
				Parent = part,
			})
			rainPart = part
			rainTint = new("ColorCorrectionEffect", { Name = "CornRainTint", TintColor = Color3.fromRGB(255, 244, 205), Saturation = 0.15, Parent = Lighting })
			task.delay((tonumber(duration) or 30) + 2, function()
				if rainPart == part then
					World.EventEnd("rain")
				end
			end)
		end
	end

	function World.EventEnd(id: string)
		if id == "rain" then
			if rainPart then
				rainPart:Destroy()
				rainPart = nil
			end
			if rainTint then
				rainTint:Destroy()
				rainTint = nil
			end
		end
	end

	-- a chuva de milho segue a câmera
	function stepRain()
		if rainPart then
			rainPart.CFrame = CFrame.new(eye + Vector3.new(0, 45, 0))
		end
	end

	function addGift(model: Instance)
		if not model:IsA("Model") or not model.PrimaryPart or model:FindFirstChild("GiftBeam") then
			return
		end
		local base = model.PrimaryPart.CFrame.Position
		fxPart({
			Name = "GiftBeam",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(160, 5, 5),
			Color = Color3.fromRGB(255, 230, 120),
			Material = Enum.Material.Neon,
			Transparency = 0.65,
			CFrame = CFrame.new(base + Vector3.new(0, 80, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Parent = model,
		})
		local gui = billboard({ Size = UDim2.new(0, 64, 0, 64), StudsOffsetWorldSpace = Vector3.new(0, 12, 0), AlwaysOnTop = true, MaxDistance = 600, Adornee = model.PrimaryPart, Parent = model })
		plateText(gui, { Size = UDim2.fromScale(1, 1), Font = UI.Font2, Text = "🎁" })
	end

	-- Corrida: cada galinha vai da largada à chegada no tempo sorteado pelo servidor
	function World.RaceGo(times: any)
		local race = Layout.Race
		if not race then
			return
		end
		local base = CFrame.new(race.X, 0, race.Z) * CFrame.Angles(0, math.rad(race.Yaw), 0)
		for _, racer in CollectionService:GetTagged("VUORacer") do
			local lane = racer:GetAttribute("Lane")
			local total = type(times) == "table" and tonumber(times[lane])
			if racer:IsA("Model") and total and total > 0 and race.Lanes[lane] then
				-- um laço por corredora, só durante a corrida (termina sozinho na chegada ou se ela sumir)
				task.spawn(function()
					local started = os.clock()
					while racer.Parent do
						local alpha = math.clamp((os.clock() - started) / total, 0, 1)
						-- arranca devagar, acelera no fim (dá emoção)
						local eased = alpha * alpha * (3 - 2 * alpha)
						local x = race.StartX + (race.FinishX - race.StartX) * eased
						local hop = math.abs(math.sin((os.clock() - started) * 12 + lane)) * 0.8
						racer:PivotTo(base * CFrame.new(x, 0.2 + hop, race.Lanes[lane]) * CFrame.Angles(0, math.rad(-90), 0))
						if alpha >= 1 then
							break
						end
						RunService.Heartbeat:Wait()
					end
				end)
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- 14. SETA DE AJUDA (tutorial): aponta o próximo passo, nesta ordem:
--   saco de dinheiro no meu terreno (some em pouco tempo: vale até para quem já passou do tutorial);
--   Baú Secreto do meu terreno quando já tenho as chaves todas (também vale para quem passou do tutorial);
--   pet pronto na chocadeira; ovo raro na cesta com chocadeira livre (só no começo); ovo raro esperando no
--   ninho; moedas no chão do meu terreno; botão que já dá para comprar; tapete de trabalho do melhor negócio
--   sem gerente. Senão some. O tutorial desliga quando o jogador já tem uns 45 botões (a seta do saco continua);
--   desligada nas configurações, não aponta nada.
-- ---------------------------------------------------------------------------
local stepArrow, startArrow
do
	local arrowPart: Part
	local arrowBeam: Beam
	local arrowTip: BillboardGui
	local arrowAttachA: Attachment? = nil
	local arrowDots: { Part } = {}
	local ARROW_DOTS = 10
	local ARROW_BUTTONS = 45

	-- Trilha de bolinhas correndo do jogador até o alvo (no lugar da faixa amarela lisa, que parecia defeito
	-- do chão): some perto das pontas e anda no sentido do alvo.
	local function stepDots(from: Vector3?, to: Vector3?, t: number)
		if not from or not to then
			for _, dot in arrowDots do
				dot.Transparency = 1
			end
			return
		end
		local a = Vector3.new(from.X, from.Y - 2.4, from.Z)
		local b = Vector3.new(to.X, to.Y - 1.5, to.Z)
		local length = (b - a).Magnitude
		local shown = math.clamp(math.floor(length / 3.2), 2, ARROW_DOTS)
		for i, dot in arrowDots do
			if i > shown then
				dot.Transparency = 1
			else
				local f = ((i - 1) / shown + t * 0.45) % 1
				dot.Position = a:Lerp(b, f)
				dot.Transparency = 0.15 + 0.85 * math.abs(f - 0.5) * 2 * math.abs(f - 0.5) * 2
			end
		end
	end

	-- onde está o botão (a peça de verdade, se já chegou; senão o ponto do Layout) e, se ele já tem plaquinha,
	-- a altura em que a setinha tem de ficar para não cair em cima dela (a placa do botão da vez cresce de longe)
	local function buttonSpot(s: any, button: any): (Vector3?, number?)
		local visuals = s.Plot:FindFirstChild("Visuals")
		local pad = visuals and visuals:FindFirstChild("B_" .. button.Id)
		if pad and pad:IsA("BasePart") then
			-- (a setinha tem 64 px de altura, sempre: de longe isso são vários studs; metade deles fica para baixo)
			local info = pads[pad]
			local at = pad.CFrame.Position
			return at + Vector3.new(0, 2, 0), if info then info.Top - 2 + 0.6 + 34 * (at - eye).Magnitude / pxStud else nil
		end
		local point: any = nil
		local kind = button.Kind
		if button.Biz and LBIZ[button.Biz] then
			local def = LBIZ[button.Biz]
			if kind == "unlock" then
				point = def.U
			elseif kind == "manager" then
				point = def.M
			elseif kind == "cash" then
				point = def.C and def.C[button.Step]
			elseif kind == "speed" then
				point = def.S and def.S[button.Step]
			end
		elseif kind == "bird" then
			local line = Layout.Lines[button.Line]
			point = line and line.Pad
		elseif button.Spot and Layout.Global[button.Spot] then
			point = Layout.Global[button.Spot].Button
		end
		if point then
			return s.Origin:PointToWorldSpace(Vector3.new(point[1], 2, point[2])), nil
		end
		return nil, nil
	end

	-- devolve (alvo, distância mínima para a seta aparecer, altura da setinha quando o alvo tem plaquinha alta)
	local function arrowTarget(s: any, root: BasePart): (Vector3?, number, number?)
		local origin: CFrame = s.Origin
		local here = root.CFrame.Position
		local function at(x: number, z: number): Vector3
			return origin:PointToWorldSpace(Vector3.new(x, 2, z))
		end
		local now = workspace:GetServerTimeNow()
		-- 1) pet pronto na chocadeira
		if type(state.Hatch) == "table" and Layout.Incubators then
			for slot, hatch in state.Hatch do
				local spot = Layout.Incubators[tonumber(slot) or 0]
				if spot and type(hatch) == "table" and num(hatch.ReadyAt) <= now then
					return at(spot[1], spot[2] + 4), 7
				end
			end
			-- 2) ovo raro na cesta e chocadeira livre (só no começo, para ensinar)
			if num(state.Hatched) < 4 and state.Mutant and state.HatchFree then
				for slot = 1, num(state.HatchSlots) do
					local spot = Layout.Incubators[slot]
					if spot and not state.Hatch[tostring(slot)] then
						return at(spot[1], spot[2] + 4), 7
					end
				end
			end
		end
		-- 3) ovo raro esperando no ninho (se a cesta está cheia: vender atrás do balcão)
		local best: Vector3? = nil
		local bestDist = math.huge
		for model, info in rares do
			if info.Plot == s.Plot and model.Parent then
				local d = (info.At - here).Magnitude
				if d < bestDist then
					best, bestDist = info.At + Vector3.new(0, 1.5, 0), d
				end
			end
		end
		if best then
			if num(state.BasketCount) >= math.max(num(state.BasketCap), 1) and Layout.Sell then
				return at(Layout.Sell[1], Layout.Sell[2]), 5
			end
			return best, 6
		end
		-- 4) moedas no chão (a pilha mais perto)
		best, bestDist = nil, math.huge
		for i = 1, NUM_BIZ do
			if s.Ground[i] > 0 and s.Cash[i] then
				local d = (s.Cash[i] - here).Magnitude
				if d < bestDist then
					best, bestDist = s.Cash[i] + Vector3.new(0, 2, 0), d
				end
			end
		end
		if not best and s.Tips > 0 and s.Cash[1] then
			best = s.Cash[1] + Vector3.new(0, 2, 0)
		end
		if best then
			return best, 6
		end
		-- 5) botão que já dá para comprar
		local nextButton = state.Next and Config.ButtonById[state.Next]
		if nextButton and num(state.Coins) >= num(nextButton.Cost) then
			local spot, lift = buttonSpot(s, nextButton)
			if spot then
				return spot, 6, lift
			end
		end
		-- 6) trabalhar no melhor negócio que ainda não tem gerente
		if HAS_V4 then
			for i = NUM_BIZ, 1, -1 do
				if s.Biz[i] == 1 then
					if i == 1 then
						-- banca: é ir para trás do balcão (de perto o botão VENDER aparece na tela)
						local spot = Layout.Sell or Layout.Stand or LBIZ[1].U
						return at(spot[1], spot[2]), 7
					end
					return at(LBIZ[i].U[1], LBIZ[i].U[2]), (Config.WorkRadius or 5) - 1
				end
			end
		end
		return nil, 0
	end

	function stepArrow(t: number)
		local root = rootPart()
		local s = mine
		if not root or not state or not s or not World.ArrowOn then
			arrowBeam.Enabled = false
			arrowTip.Enabled = false
			stepDots(nil, nil, t)
			return
		end
		if not arrowAttachA or arrowAttachA.Parent ~= root then
			arrowAttachA = new("Attachment", { Parent = root })
			arrowBeam.Attachment0 = arrowAttachA
		end
		-- o saco de dinheiro primeiro (tem hora para sumir); depois o Baú Secreto quando já dá para abrir (as
		-- chaves estão na mão: é só ir até lá); o tutorial só para quem ainda está no começo
		local target, minDist, tipLift = bagTarget(s)
		if not target then
			target, minDist, tipLift = V5.secretTarget(s)
		end
		if not target and num(state.Buttons) < ARROW_BUTTONS then
			target, minDist, tipLift = arrowTarget(s, root)
			tipLift = tipLift or 0
		end
		if target and (target - root.CFrame.Position).Magnitude > minDist then
			arrowPart.CFrame = CFrame.new(target)
			arrowBeam.Enabled = false
			arrowTip.Enabled = true
			-- acima da plaquinha do botão (ou da do saco, que cresce com a distância)
			arrowTip.StudsOffsetWorldSpace = liftOf(arrowTip.Adornee, math.max(9.5, tipLift) + math.abs(math.sin(t * 4)) * 1.2)
			stepDots(root.CFrame.Position, target, t)
		else
			arrowBeam.Enabled = false
			arrowTip.Enabled = false
			stepDots(nil, nil, t)
		end
	end

	-- cria as peças da seta (uma vez, na partida)
	function startArrow()
		arrowPart = fxPart({ Name = "Arrow", Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), Parent = fxFolder })
		local attachB = new("Attachment", { Parent = arrowPart })
		arrowBeam = new("Beam", {
			Attachment1 = attachB,
			Width0 = 1.4,
			Width1 = 1.4,
			FaceCamera = true,
			Color = ColorSequence.new(C.Yellow),
			LightEmission = 0.6,
			Transparency = NumberSequence.new(0.15),
			Enabled = false,
			Parent = arrowPart,
		})
		for _ = 1, ARROW_DOTS do
			table.insert(arrowDots, fxPart({ Name = "ArrowDot", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), Color = C.Yellow, Material = Enum.Material.Neon, Transparency = 1, Parent = fxFolder }))
		end
		-- uma setinha quicando em cima do alvo (tamanho em pixels: é um ícone de interface, sempre do mesmo tamanho)
		arrowTip = billboard({ Name = "Tip", Size = UDim2.new(0, 64, 0, 64), AlwaysOnTop = true, MaxDistance = 400, Enabled = false, Adornee = arrowPart, Parent = arrowPart })
		plateText(arrowTip, { Size = UDim2.fromScale(1, 1), Font = UI.Font2, Text = "▼", TextColor3 = C.Yellow, TextStrokeTransparency = 0.2, TextStrokeColor3 = C.DarkBrown })
	end
end

-- ---------------------------------------------------------------------------
-- 15. CLIMA (versão 5). O servidor inteiro tem um clima de cada vez. Ele publica no workspace os atributos
-- Weather (id), WeatherUntil (hora do servidor em que acaba) e WeatherNext (id do próximo): valem para quem
-- entra no meio. A cada troca manda também o Fx "weather" (a tela repassa para World.SetWeather).
--   luz e céu   troca suave (FADE segundos, TweenService). Os valores NORMAIS são guardados na 1ª vez que o
--               clima mexe em cada coisa e devolvidos, exatos, no "limpo" (que não mexe em nada). A cor da
--               tela é um ColorCorrectionEffect só do clima ("WeatherTint"): o do jogo, o da Chuva de Milho
--               e o clarão do Mega Ovo são outros. Se outro código mexer numa propriedade no meio de um
--               clima, o clima larga essa propriedade (não briga) até o próximo "limpo".
--   partículas  poucas, em peças invisíveis que seguem a câmera (como a Chuva de Milho): gotas e respingos,
--               folhas e poeira de lado, estrelas piscando, brilhos do arco-íris.
--   arco-íris   7 faixas de peças neon em arco atrás do MEU terreno (sem terreno: por cima da praça).
--   selo        em cima da placa de cada negócio ajudado no MEU terreno: "☀️ +50%" (some quando o clima muda).
-- Nada aqui fica na frente das plaquinhas (que não dependem da luz: LightInfluence 0) nem tem colisão.
-- ---------------------------------------------------------------------------
function V5.BuildWeather()
	local refreshWeather, stepWeather, refreshSeals, relabelSeals
	local BY_ID: { [string]: any } = Config.WeatherById or {}
	local FADE = 4 -- segundos da troca de luz
	local rgb = Color3.fromRGB
	local current: any = { Id = nil, Until = 0, Next = nil }
	local attrSeen: { any } = {} -- última trinca lida dos atributos (só uma MUDANÇA neles vale: ver refreshWeather)
	local generation = 0 -- sobe a cada troca (o que ficou agendado para o clima anterior desiste)
	World.OnWeather = nil :: ((id: string, first: boolean) -> ())? -- a tela liga aqui: o clima mudou

	local function valid(id: any): boolean
		return type(id) == "string" and BY_ID[id] ~= nil
	end

	-- ----- luz e céu -----
	local tint: ColorCorrectionEffect? = nil

	-- onde mora cada coisa: L = Lighting, A = Atmosphere, S = SunRays, C = Clouds (no Terrain), W = workspace
	-- (vento das nuvens), T = o filtro de cor do clima. O que não existir neste jogo é pulado.
	local function holder(letter: string): Instance?
		if letter == "L" then
			return Lighting
		elseif letter == "A" then
			return Lighting:FindFirstChildOfClass("Atmosphere")
		elseif letter == "S" then
			return Lighting:FindFirstChildOfClass("SunRaysEffect")
		elseif letter == "C" then
			local terrain = workspace:FindFirstChildOfClass("Terrain")
			return terrain and terrain:FindFirstChildOfClass("Clouds")
		elseif letter == "W" then
			return workspace
		elseif letter == "T" then
			return tint
		end
		return nil
	end

	-- O "normal" (build.py): dia claro às 14h20, Brightness 2.6, Ambient 110/100/95, OutdoorAmbient 165/155/150,
	-- Atmosphere 0.2 de densidade e 0.9 de névoa, nuvens cobrindo 58%. Cada clima diz só o que MUDA.
	local LOOK: { [string]: { { any } } } = {
		limpo = {},
		-- mais claro e quente: sol alto, menos névoa, menos nuvem, raios de sol mais fortes
		-- Farmar Aura: "Hora Dourada" (o id continua "sol"): pôr do sol laranja, sombras compridas, tudo quente
		sol = {
			{ "L", "Brightness", 2.6 },
			{ "L", "ClockTime", 17.6 },
			{ "L", "Ambient", rgb(150, 110, 80) },
			{ "L", "OutdoorAmbient", rgb(205, 150, 110) },
			{ "A", "Density", 0.28 },
			{ "A", "Haze", 1.2 },
			{ "A", "Glare", 1.1 },
			{ "A", "Color", rgb(255, 200, 150) },
			{ "A", "Decay", rgb(255, 140, 90) },
			{ "C", "Cover", 0.45 },
			{ "C", "Color", rgb(255, 196, 160) },
			{ "S", "Intensity", 0.28 },
			{ "T", "TintColor", rgb(255, 228, 196) },
			{ "T", "Saturation", 0.18 },
			{ "T", "Brightness", 0.03 },
		},
		-- céu fechado e luz fria (o Ambient sobe para compensar o sol fraco: as sombras não escurecem o chão)
		chuva = {
			{ "L", "Brightness", 1.7 },
			{ "L", "Ambient", rgb(120, 126, 140) },
			{ "L", "OutdoorAmbient", rgb(150, 158, 174) },
			{ "A", "Density", 0.32 },
			{ "A", "Haze", 1.7 },
			{ "A", "Glare", 0 },
			{ "A", "Color", rgb(188, 198, 214) },
			{ "A", "Decay", rgb(128, 142, 164) },
			{ "C", "Cover", 0.93 },
			{ "C", "Density", 0.78 },
			{ "C", "Color", rgb(168, 174, 188) },
			{ "S", "Intensity", 0 },
			{ "T", "TintColor", rgb(224, 233, 250) },
			{ "T", "Saturation", -0.1 },
		},
		-- quase o dia normal: um pouco de poeira no ar e as nuvens correndo (GlobalWind)
		vento = {
			{ "L", "Brightness", 2.5 },
			{ "A", "Haze", 1.4 },
			{ "A", "Color", rgb(214, 222, 226) },
			{ "C", "Cover", 0.5 },
			{ "C", "Density", 0.22 },
			{ "W", "GlobalWind", Vector3.new(34, 0, 9) },
			{ "T", "TintColor", rgb(250, 248, 236) },
		},
		-- Farmar Aura: "Lua de Sangue" (o id continua "noite"): noite vermelha, mas clara o bastante para jogar
		noite = {
			{ "L", "ClockTime", 22.2 },
			{ "L", "Brightness", 1.4 },
			{ "L", "Ambient", rgb(140, 80, 86) },
			{ "L", "OutdoorAmbient", rgb(160, 90, 96) },
			{ "L", "ExposureCompensation", 0.3 },
			{ "A", "Density", 0.3 },
			{ "A", "Haze", 0.6 },
			{ "A", "Glare", 0 },
			{ "A", "Color", rgb(200, 90, 90) },
			{ "A", "Decay", rgb(110, 30, 40) },
			{ "C", "Cover", 0.35 },
			{ "C", "Color", rgb(170, 90, 95) },
			{ "S", "Intensity", 0 },
			{ "T", "TintColor", rgb(255, 205, 205) },
			{ "T", "Saturation", 0.05 },
		},
		-- Farmar Aura: "Fenda do Vazio" (o id continua "arcoiris"): céu roxo-escuro, tudo puxado para o violeta
		arcoiris = {
			{ "L", "ClockTime", 0.5 },
			{ "L", "Brightness", 1.6 },
			{ "L", "Ambient", rgb(120, 80, 170) },
			{ "L", "OutdoorAmbient", rgb(140, 95, 200) },
			{ "L", "ExposureCompensation", 0.35 },
			{ "A", "Density", 0.35 },
			{ "A", "Haze", 1.4 },
			{ "A", "Glare", 0.4 },
			{ "A", "Color", rgb(150, 90, 230) },
			{ "A", "Decay", rgb(60, 20, 110) },
			{ "C", "Cover", 0.6 },
			{ "C", "Color", rgb(110, 60, 170) },
			{ "S", "Intensity", 0 },
			{ "T", "TintColor", rgb(225, 200, 255) },
			{ "T", "Saturation", 0.25 },
			{ "T", "Contrast", 0.1 },
		},
	}

	local base: { [string]: any } = {} -- ["L.Brightness"] = valor NORMAL (guardado na 1ª vez; devolvido no "limpo")
	local put: { [string]: any } = {} -- último valor que o clima pôs em cada coisa
	local released: { [string]: boolean } = {} -- outro código mexeu nisto no meio do clima: é dele até o próximo "limpo"
	local tweens: { any } = {}
	local busyUntil = 0 -- os.clock() em que a troca em andamento termina

	local function read(inst: Instance, prop: string): any
		return (inst :: any)[prop]
	end

	local function same(a: any, b: any): boolean
		local kind = typeof(a)
		if kind ~= typeof(b) then
			return false
		elseif kind == "number" then
			return math.abs(a - b) < 0.02
		elseif kind == "Color3" then
			return math.abs(a.R - b.R) < 0.02 and math.abs(a.G - b.G) < 0.02 and math.abs(a.B - b.B) < 0.02
		elseif kind == "Vector3" then
			return (a - b).Magnitude < 0.05
		end
		return a == b
	end

	local function setLook(id: string)
		local look = LOOK[id] or LOOK.limpo
		local clock = os.clock()
		for _, tween in tweens do
			tween:Cancel()
		end
		table.clear(tweens)
		-- Alguém mexeu no que o clima tinha posto? (só dá para saber com a troca anterior terminada: no meio
		-- dela os valores ainda estão a caminho.) Se mexeu, a propriedade fica com quem mexeu.
		if clock >= busyUntil then
			for key, value in put do
				local letter = string.sub(key, 1, 1)
				local inst = if letter ~= "T" then holder(letter) else nil
				if inst then
					local ok, now = pcall(read, inst, string.sub(key, 3))
					if ok and not same(now, value) then
						released[key] = true
					end
				end
			end
		end
		if id ~= "limpo" and not (tint and tint.Parent) then
			tint = new("ColorCorrectionEffect", { Name = "WeatherTint", Parent = Lighting })
		end
		local goals: { [string]: { [string]: any } } = {}
		local function want(letter: string, prop: string, value: any)
			local list = goals[letter]
			if not list then
				list = {}
				goals[letter] = list
			end
			list[prop] = value
			put[letter .. "." .. prop] = value
		end
		-- 1) o que este clima muda (guardando o normal na 1ª vez)
		for _, item in look do
			local letter, prop = item[1], item[2]
			local key = letter .. "." .. prop
			local inst = holder(letter)
			if inst and not released[key] then
				local ok, normal = true, base[key]
				if normal == nil then
					ok, normal = pcall(read, inst, prop)
				end
				if ok and typeof(normal) == typeof(item[3]) then
					base[key] = normal
					want(letter, prop, item[3])
				end
			end
		end
		-- 2) o que um clima anterior mudou e este não muda: volta ao normal
		for key, normal in base do
			local letter, prop = string.sub(key, 1, 1), string.sub(key, 3)
			if not released[key] and not (goals[letter] and goals[letter][prop] ~= nil) then
				want(letter, prop, normal)
			end
		end
		for letter, props in goals do
			local inst = holder(letter)
			if inst then
				-- (protegido, com aviso uma vez: se uma propriedade não puder ser animada, o resto do céu troca assim mesmo)
				safe("weatherTween " .. letter, function()
					local tween = TweenService:Create(inst, TweenInfo.new(FADE, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), props)
					tween:Play()
					table.insert(tweens, tween)
				end)
			end
		end
		busyUntil = clock + FADE + 0.1
		if id == "limpo" then
			-- de volta ao normal: no fim da troca põe os valores EXATOS e esquece tudo (o próximo clima guarda de novo)
			local mark = generation
			task.delay(FADE + 0.3, function()
				if generation ~= mark then
					return
				end
				for key, normal in base do
					local inst = holder(string.sub(key, 1, 1))
					if inst and not released[key] and string.sub(key, 1, 1) ~= "T" then
						pcall(function()
							(inst :: any)[string.sub(key, 3)] = normal
						end)
					end
				end
				table.clear(base)
				table.clear(put)
				table.clear(released)
				table.clear(tweens)
				if tint then
					tint:Destroy()
					tint = nil
				end
			end)
		end
	end

	-- ----- luzes do mapa mais fortes à noite (lampiões, janelas, torre do foguete) -----
	local boosted: { [Instance]: { number } } = {} -- [luz] = { brilho normal, alcance normal, brilho posto, alcance posto }

	local function lightsNormal()
		for light, was in boosted do
			if light.Parent then
				local l: any = light
				-- (só devolve o que ainda está como o clima deixou)
				if same(l.Brightness, was[3]) then
					l.Brightness = was[1]
				end
				if same(l.Range, was[4]) then
					l.Range = was[2]
				end
			end
		end
		table.clear(boosted)
	end

	local function lightsNight(mark: number)
		task.spawn(function()
			local seen, count = 0, 0
			for _, name in { "Map", "Plots" } do
				local folder = workspace:FindFirstChild(name)
				for _, d in if folder then folder:GetDescendants() else {} do
					seen += 1
					if seen % 3000 == 0 then
						task.wait() -- mapa grande: um pedaço por quadro, sem tranco
						if generation ~= mark then
							return
						end
					end
					-- (a luz da chave escondida fica como está: ela é discreta de propósito)
					if d:IsA("Light") and d.Parent and d.Name ~= "KeyLight" and not boosted[d] and count < 120 then
						count += 1
						local l: any = d
						local was = { l.Brightness, l.Range, l.Brightness * 1.6, math.min(l.Range * 1.25, 60) }
						boosted[d] = was
						l.Brightness = was[3]
						l.Range = was[4]
					end
				end
			end
		end)
	end

	-- ----- partículas em volta da câmera -----
	-- Cada item é uma peça invisível que segue a câmera (sem girar com ela) com um ou dois ParticleEmitter.
	local rigs: { any } = {}

	local function rig(name: string, size: Vector3, offset: CFrame, ground: boolean?): Part
		local part = fxPart({ Name = name, Transparency = 1, Size = size, CFrame = CFrame.new(eye) * offset, Parent = fxFolder })
		table.insert(rigs, { Part = part, Offset = offset, Ground = ground == true, Until = nil })
		return part
	end

	local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
		local all: { [string]: any } = { Texture = SPARK, LightEmission = 0.5, LightInfluence = 0, Rate = 1, Parent = parent }
		for key, value in props do
			all[key] = value
		end
		return new("ParticleEmitter", all)
	end

	-- o clima mudou: as peças param de soltar e somem quando as partículas que já estão no ar acabarem
	local function dropRigs()
		local clock = os.clock()
		for _, item in rigs do
			if not item.Until then
				item.Until = clock + 6.5
				for _, child in item.Part:GetChildren() do
					if child:IsA("ParticleEmitter") then
						child.Enabled = false
					end
				end
			end
		end
	end

	local function twinkle(peak: number): NumberSequence
		return NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, peak), NumberSequenceKeypoint.new(1, 0) })
	end

	local RAINBOW = { rgb(255, 255, 255), rgb(200, 140, 255), rgb(150, 80, 240), rgb(90, 40, 200), rgb(40, 10, 90), rgb(170, 100, 255), rgb(240, 220, 255) } -- Farmar Aura: brilhos do Vazio

	local function buildRigs(id: string)
		if id == "chuva" then
			-- gotas: riscos finos caindo de cima da câmera até o chão (umas 50 no ar)
			local sky = rig("WeatherRain", Vector3.new(90, 1, 90), CFrame.new(0, 36, 0))
			emitter(sky, {
				Name = "Chuva",
				Color = ColorSequence.new(rgb(205, 228, 255)),
				Size = NumberSequence.new(0.38),
				Squash = NumberSequence.new(1.6), -- comprida e fina, no sentido da queda
				Transparency = NumberSequence.new(0.35),
				Orientation = Enum.ParticleOrientation.VelocityParallel,
				Lifetime = NumberRange.new(0.75, 0.95),
				Speed = NumberRange.new(58, 70),
				EmissionDirection = Enum.NormalId.Bottom,
				SpreadAngle = Vector2.new(2, 2),
				LightEmission = 0.35,
				Rate = 55,
			})
			-- respingos no chão em volta do jogador (uns 5 no ar)
			local floor = rig("WeatherSplash", Vector3.new(56, 0.4, 56), CFrame.new(0, 0.4, 0), true)
			emitter(floor, {
				Name = "Respingo",
				Color = ColorSequence.new(rgb(225, 240, 255)),
				Size = NumberSequence.new(0.32, 0),
				Transparency = NumberSequence.new(0.3, 1),
				Lifetime = NumberRange.new(0.25, 0.4),
				Speed = NumberRange.new(3, 6),
				EmissionDirection = Enum.NormalId.Top,
				SpreadAngle = Vector2.new(55, 55),
				Rate = 14,
			})
		elseif id == "vento" then
			-- uma "parede" invisível do lado de onde o vento vem: folhas e poeira saem dela e cruzam a tela
			-- (da altura do chão do jogador até um pouco acima da câmera, que olha de cima)
			local dir = Vector3.new(1, 0, 0.26).Unit
			local side = rig("WeatherWind", Vector3.new(1, 30, 96), CFrame.fromMatrix(dir * -58 + Vector3.new(0, -6, 0), dir, Vector3.new(0, 1, 0)))
			emitter(side, {
				Name = "Folha",
				Color = ColorSequence.new(rgb(120, 190, 70), rgb(232, 170, 60)),
				Size = NumberSequence.new(0.7),
				Squash = NumberSequence.new(-0.7), -- achatada: parece folha, não estrela
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.85, 0.1), NumberSequenceKeypoint.new(1, 1) }),
				Lifetime = NumberRange.new(2.6, 3.4),
				Speed = NumberRange.new(34, 46),
				EmissionDirection = Enum.NormalId.Right,
				SpreadAngle = Vector2.new(5, 9),
				Rotation = NumberRange.new(0, 360),
				RotSpeed = NumberRange.new(-240, 240),
				Acceleration = Vector3.new(0, -1.2, 0),
				LightEmission = 0,
				Rate = 9,
			})
			emitter(side, {
				Name = "Poeira",
				Texture = SMOKE,
				Color = ColorSequence.new(rgb(226, 212, 178)),
				Size = NumberSequence.new(1.6, 3.2),
				Transparency = NumberSequence.new(0.8, 1),
				Lifetime = NumberRange.new(2.2, 3),
				Speed = NumberRange.new(30, 40),
				EmissionDirection = Enum.NormalId.Right,
				SpreadAngle = Vector2.new(4, 6),
				LightEmission = 0,
				Rate = 4,
			})
		elseif id == "noite" then
			-- estrelas piscando lá no alto (presas à peça: acompanham a câmera, como céu de verdade)
			local sky = rig("WeatherStars", Vector3.new(420, 1, 420), CFrame.new(0, 95, 0))
			emitter(sky, {
				Name = "Estrela",
				Color = ColorSequence.new(rgb(236, 241, 255)),
				Size = twinkle(1.7),
				Lifetime = NumberRange.new(3.5, 6),
				Speed = NumberRange.new(0),
				LockedToPart = true,
				LightEmission = 1,
				Rate = 11,
			})
		elseif id == "arcoiris" then
			-- brilhos coloridos descendo devagar
			local keypoints = {}
			for i, color in RAINBOW do
				keypoints[i] = ColorSequenceKeypoint.new((i - 1) / (#RAINBOW - 1), color)
			end
			local sky = rig("WeatherGlitter", Vector3.new(80, 1, 80), CFrame.new(0, 24, 0))
			emitter(sky, {
				Name = "Brilho",
				Color = ColorSequence.new(keypoints),
				Size = NumberSequence.new(0.55, 0),
				Lifetime = NumberRange.new(2.4, 3.4),
				Speed = NumberRange.new(3, 6),
				EmissionDirection = Enum.NormalId.Bottom,
				SpreadAngle = Vector2.new(20, 20),
				LightEmission = 0.8,
				Rate = 7,
			})
		end
	end

	-- todo quadro: as peças acompanham a câmera (a dos respingos, na altura do chão do jogador)
	function stepWeather()
		if #rigs == 0 then
			return
		end
		local clock = os.clock()
		local floorY: number? = nil
		for i = #rigs, 1, -1 do
			local item = rigs[i]
			if item.Until and clock >= item.Until then
				item.Part:Destroy()
				table.remove(rigs, i)
			elseif item.Ground then
				if floorY == nil then
					local root = rootPart()
					floorY = if root then root.CFrame.Position.Y - 3 else eye.Y - 22
				end
				item.Part.CFrame = CFrame.new(eye.X, floorY :: number, eye.Z) * item.Offset
			else
				item.Part.CFrame = CFrame.new(eye) * item.Offset
			end
		end
	end

	-- ----- arco-íris -----
	-- Um arco baixo e largo atrás do terreno (o centro do círculo fica debaixo do chão: só aparece a parte de
	-- cima). 7 faixas x RAINBOW_SEG peças neon finas, paradas, sem sombra e sem colisão.
	local RAINBOW_R, RAINBOW_BAND, RAINBOW_SEG, RAINBOW_DEEP = 210, 3, 12, 110
	local rainbow: Model? = nil
	local rainbowPlot: Instance? = nil

	local function rainbowOff()
		local model = rainbow
		rainbow = nil
		rainbowPlot = nil
		if model then
			for _, part in model:GetChildren() do
				TweenService:Create(part, TweenInfo.new(2.5), { Transparency = 1 }):Play()
			end
			task.delay(2.7, function()
				model:Destroy()
			end)
		end
	end

	local function rainbowOn()
		rainbowOff()
		-- o plano do arco: X para os lados, Y para cima; fica 46 studs atrás da cerca do fundo do meu terreno
		local s = mine
		local floor = num(Layout.Floor)
		local frame = CFrame.new(0, floor - RAINBOW_DEEP, 0)
		if s then
			frame = s.Origin * CFrame.new(0, floor - RAINBOW_DEEP, (if Layout.Size then Layout.Size[3] else 152) + 46)
		end
		local model = new("Model", { Name = "Rainbow" })
		local low = math.asin(RAINBOW_DEEP / RAINBOW_R) -- o arco nasce no chão
		local step = (math.pi - 2 * low) / RAINBOW_SEG
		for band, color in RAINBOW do
			local r = RAINBOW_R - (band - 0.5) * RAINBOW_BAND
			local length = 2 * r * math.sin(step / 2) * 1.04 -- (um tico a mais: as emendas não abrem)
			local mid = r * math.cos(step / 2)
			for i = 1, RAINBOW_SEG do
				local angle = low + (i - 0.5) * step
				local part = fxPart({
					Name = "Arco",
					Size = Vector3.new(length, RAINBOW_BAND, 0.8),
					Color = color,
					Material = Enum.Material.Neon,
					Transparency = 1,
					CFrame = frame * CFrame.new(mid * math.cos(angle), mid * math.sin(angle), 0) * CFrame.Angles(0, 0, angle + math.pi / 2),
					Parent = model,
				})
				TweenService:Create(part, TweenInfo.new(3), { Transparency = 0.45 }):Play()
			end
		end
		model.Parent = fxFolder
		rainbow = model
		rainbowPlot = if s then s.Plot else nil
	end

	-- ----- selo em cima dos prédios ajudados (só no MEU terreno) -----
	local SEAL_W, SEAL_H = 4.6, 1.5
	local SEAL_BG = rgb(26, 92, 46)

	local function helps(def: any, index: number): boolean
		if num(def.Mult) <= 1 then
			return false
		end
		return def.All == true or (type(def.Biz) == "table" and table.find(def.Biz, index) ~= nil)
	end

	function refreshSeals()
		local def = BY_ID[current.Id]
		local text = ""
		if def and num(def.Mult) > 1 then
			text = T("weather.boost", { e = def.Emoji or "", p = math.floor((def.Mult - 1) * 100 + 0.5) })
		end
		for model, info in signs do
			local s = snaps[info.Plot]
			local seal = info.Seal
			if text ~= "" and s and s.Mine and model.Parent and helps(def, info.Index) then
				if not seal then
					local gui = billboard({ Name = "Boost", Size = UDim2.new(SEAL_W, 0, SEAL_H, 0), MaxDistance = 150, Adornee = info.Anchor, Parent = info.Anchor })
					plateBg(gui, 0.1, 0.45).BackgroundColor3 = SEAL_BG
					seal = { Gui = gui, Label = plateText(gui, { Name = "Text", Position = UDim2.fromScale(0.06, 0.1), Size = UDim2.fromScale(0.88, 0.8), TextColor3 = TEXT_YELLOW }), Text = "", Half = -1, K = -1 }
					info.Seal = seal
				end
				if seal.Text ~= text then
					seal.Text = text
					seal.Label.Text = text
				end
				-- logo acima da placa do negócio, que muda de tamanho com a distância (o selo cresce junto)
				local half = info.Gui.Size.Y.Scale / 2
				local k = math.max(num(info.K), 1)
				if half ~= seal.Half or k ~= seal.K then
					seal.Half = half
					seal.K = k
					seal.Gui.Size = UDim2.new(SEAL_W * k, 0, SEAL_H * k, 0)
					seal.Gui.StudsOffsetWorldSpace = liftOf(info.Anchor, half + 0.3 + SEAL_H * k / 2)
				end
			elseif seal then
				seal.Gui:Destroy()
				info.Seal = nil
			end
		end
	end

	-- idioma mudou: os selos são escritos de novo
	function relabelSeals()
		for _, info in signs do
			if info.Seal then
				info.Seal.Text = ""
			end
		end
	end

	-- ----- qual é o clima -----
	local function adopt(id: string, untilAt: number, nextId: any)
		local first = current.Id == nil
		local changed = id ~= current.Id
		local now = workspace:GetServerTimeNow()
		-- (os 3 atributos podem chegar um de cada vez: uma hora já vencida ou um "próximo" igual ao de agora são
		-- restos do clima anterior e não entram)
		if changed or untilAt > now or current.Until <= now then
			current.Until = untilAt
		end
		if changed or (valid(nextId) and nextId ~= id) then
			current.Next = if valid(nextId) and nextId ~= id then nextId else nil
		end
		if not changed then
			return
		end
		current.Id = id
		generation += 1
		safe("weatherLook", setLook, id)
		dropRigs()
		safe("weatherRigs", buildRigs, id)
		-- Farmar Aura: a Fenda do Vazio não tem o arco-íris do Venda um Ovo (só céu roxo e brilhos violeta)
		rainbowOff()
		lightsNormal()
		if id == "noite" then
			lightsNight(generation)
		end
		safe("seals", refreshSeals)
		if World.OnWeather then
			task.spawn(safe, "onWeather", World.OnWeather, id, first)
		end
	end

	-- Para a tela: (id do clima, hora do servidor em que acaba, id do próximo) ou nil se o servidor não tem clima
	function World.Weather(): (string?, number, string?)
		return current.Id, current.Until, current.Next
	end

	-- Fx "weather" (id, segundos): troca na hora, sem esperar os atributos chegarem
	function World.SetWeather(id: any, seconds: any)
		if valid(id) and id ~= current.Id then
			adopt(id, workspace:GetServerTimeNow() + math.max(num(seconds), 0), nil)
		end
	end

	-- state.Weather = { Id, Until, Next }: só vale se o workspace não tiver os atributos (reserva)
	function World.WeatherState(info: any)
		if attrSeen[1] == nil and type(info) == "table" and valid(info.Id) then
			adopt(info.Id, num(info.Until), info.Next)
		end
	end

	-- algumas vezes por segundo: os atributos do workspace. Só uma MUDANÇA neles troca o clima: se o Fx chegou
	-- antes, os atributos antigos (ainda iguais aos da última leitura) não desfazem a troca. Mas quem manda são
	-- os atributos: se eles continuam dizendo outro clima 3 s depois do Fx, vale o que eles dizem (um Fx fora
	-- de hora não deixa o céu errado para sempre).
	local staleSince: number? = nil
	function refreshWeather()
		local id, untilAt, nextId = workspace:GetAttribute("Weather"), workspace:GetAttribute("WeatherUntil"), workspace:GetAttribute("WeatherNext")
		if id ~= attrSeen[1] or untilAt ~= attrSeen[2] or nextId ~= attrSeen[3] then
			attrSeen[1], attrSeen[2], attrSeen[3] = id, untilAt, nextId
			if valid(id) then
				adopt(id, num(untilAt), nextId)
			end
		end
		if valid(id) and id ~= current.Id then
			local clock = os.clock()
			staleSince = staleSince or clock
			if clock - staleSince > 3 then
				staleSince = nil
				adopt(id, num(untilAt), nextId)
			end
		else
			staleSince = nil
		end
		-- ganhei (ou troquei de) terreno no meio do arco-íris: ele vai para trás do terreno novo
		if rainbow and rainbowPlot ~= (if mine then mine.Plot else nil) then
			safe("rainbow", rainbowOn)
		end
		refreshSeals()
	end

	V5.refreshWeather, V5.stepWeather, V5.relabelSeals = refreshWeather, stepWeather, relabelSeals
end
V5.BuildWeather()

-- ---------------------------------------------------------------------------
-- 16. PODERES (versão 5): o que TODOS veem quando alguém usa um poder (Fx "power"; a posição é a banca do
-- dono). galo = uma onda da cor do poder abre a partir da banca e riscos de velocidade varrem o terreno da
-- frente para o fundo; moedas = moedas caem do céu em volta do dono (ou da banca); sorte = faísca verde.
-- Tudo some sozinho em menos de 2 segundos.
-- ---------------------------------------------------------------------------
do
	local function snapOfUser(userId: any): any
		if type(userId) == "number" and userId ~= 0 then
			for _, s in snaps do
				if s.Owner == userId then
					return s
				end
			end
		end
		return nil
	end

	local function wave(at: Vector3, color: Color3, size: number)
		local ring = fxPart({
			Name = "PowerWave",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, 4, 4),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.5,
			CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)),
			Parent = fxFolder,
		})
		TweenService:Create(ring, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.4, size, size), Transparency = 1 }):Play()
		task.delay(1.4, function()
			ring:Destroy()
		end)
	end

	-- line e slot (opcionais): a ave e o ninho do ovo que o poder da sorte fez aparecer. Devolve true se a
	-- faísca saiu do ninho (a tela não precisa repetir).
	function World.PowerFx(id: any, position: Vector3?, userId: any, line: any?, slot: any?): boolean
		local power = (Config.PowerById or {})[id]
		local color: Color3 = if power and typeof(power.Color) == "Color3" then power.Color else GOLD
		local s = snapOfUser(userId)
		local stand: Vector3? = position or (if s then s.StandAt else nil)
		if not stand then
			return false
		end
		local function far(point: Vector3): boolean
			return (point - eye).Magnitude > 450 -- longe demais para ver: nem cria as peças
		end
		local floor = num(Layout.Floor)
		-- altura do chão: a do terreno do dono; sem ele, a posição do efeito costuma vir uns 3 studs acima do chão
		local ground = if s then s.Origin.Position.Y + floor else stand.Y - 3
		if id == "galo" then
			if far(stand) then
				return false
			end
			wave(Vector3.new(stand.X, ground + 0.4, stand.Z), color, 300)
			if s and Layout.Size then
				-- riscos de velocidade: da frente para o fundo do terreno, cada um na sua faixa
				local z0, z1 = Layout.Size[2], Layout.Size[3]
				local lanes = 10
				for lane = 1, lanes do
					local x = ((lane - 0.5) / lanes - 0.5) * (Layout.Size[1] - 8) + (math.random() - 0.5) * 6
					local y = floor + 1.5 + math.random() * 5
					local streak = fxPart({
						Name = "PowerStreak",
						Size = Vector3.new(0.45, 0.45, 18),
						Color = color:Lerp(Color3.new(1, 1, 1), 0.45),
						Material = Enum.Material.Neon,
						Transparency = 0.15,
						CFrame = s.Origin * CFrame.new(x, y, z0 + math.random() * 24),
						Parent = fxFolder,
					})
					TweenService:Create(streak, TweenInfo.new(0.75 + math.random() * 0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = s.Origin * CFrame.new(x, y, z1), Transparency = 1 }):Play()
					task.delay(1.3, function()
						streak:Destroy()
					end)
				end
			end
		elseif id == "moedas" then
			-- em volta do dono, se ele está no terreno; senão em volta da banca
			local center = Vector3.new(stand.X, ground, stand.Z)
			local owner = if type(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
			local character = owner and owner.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and (root.CFrame.Position - stand).Magnitude < 320 then
				center = root.CFrame.Position - Vector3.new(0, 3, 0)
			end
			if far(center) then
				return false
			end
			for burst = 0, 2 do
				task.delay(burst * 0.22, function()
					for _ = 1, 9 do
						if #coins >= MAX_COINS + 20 then
							break
						end
						local height = 34 + math.random() * 16
						local down = 6 + math.random() * 10
						local coin = fxPart({
							Name = "PowerCoin",
							Shape = Enum.PartType.Cylinder,
							Size = Vector3.new(0.22, 1.25, 1.25),
							Color = color,
							Material = Enum.Material.Neon,
							CFrame = CFrame.new(center + Vector3.new((math.random() - 0.5) * 46, height, (math.random() - 0.5) * 46)) * CFrame.Angles(math.random() * 6, math.random() * 6, 0),
							Parent = fxFolder,
						})
						-- (a "física" das moedas puxa 60 studs/s² para baixo: a moeda some quando chega ao chão)
						table.insert(coins, { Part = coin, Velocity = Vector3.new(0, -down, 0), Life = (-down + math.sqrt(down * down + 120 * height)) / 60 })
					end
				end)
			end
			task.delay(1.1, function()
				World.Puff(center + Vector3.new(0, 2, 0), color)
			end)
		else
			if far(stand) then
				return false
			end
			-- sorte (e qualquer poder novo): uma faísca da cor do poder na banca...
			World.Puff(Vector3.new(stand.X, ground + 5, stand.Z), color)
			World.Ping(Vector3.new(stand.X, ground + 4.4, stand.Z), color) -- (o Ping desenha o anel 4 studs abaixo: rente ao chão)
			-- ...e, se o servidor disse em que ninho o ovo apareceu, outra no ninho
			local row = if s and type(line) == "number" then Layout.Lines[line] else nil
			local nest = if row and type(row.Nests) == "table" and type(slot) == "number" then row.Nests[slot] else nil
			if nest then
				World.Puff(s.Origin:PointToWorldSpace(Vector3.new(nest[1], floor + 2, nest[2])), color)
				return true
			end
		end
		return false
	end
end

-- ---------------------------------------------------------------------------
-- Estado, idioma e partida
-- ---------------------------------------------------------------------------
function World.SetState(newState: any)
	state = newState
	for pad, info in pads do
		if pad.Parent then
			padPaint(pad :: any, info)
		else
			pads[pad] = nil
		end
	end
	for model, info in lots do
		if model.Parent then
			lotPaint(info)
		end
	end
	safe("hunt", refreshHunt)
end

-- Idioma mudou: refaz todos os textos do mapa
function World.Relabel()
	for pad, info in pads do
		if pad.Parent then
			padText(info)
			padMode(info, info.Mode, info.K)
		end
	end
	for _, info in workPads do
		info.Busy = nil -- o próximo quadro escreve de novo
	end
	for model, info in signs do
		if model.Parent then
			signText(info)
		end
	end
	for model, info in rares do
		if model.Parent then
			info.Label.Text = T("mut." .. info.Key)
		end
	end
	for model, info in lots do
		if model.Parent then
			lotText(info)
		end
	end
	for _, model in CollectionService:GetTagged("VUOPreview") do
		safe("preview", refreshPreview, model)
	end
	for _, part in CollectionService:GetTagged("VUOText") do
		safe("text", refreshText, part)
	end
	for _, prompt in CollectionService:GetTagged("VUOWheelPrompt") do
		if prompt:IsA("ProximityPrompt") then
			prompt.ActionText = T("wheel.prompt")
		end
	end
	for _, info in incubators do
		info.Text = "?" -- força reescrever no próximo meio segundo
	end
	for _, info in chests do
		info.Text = "?"
	end
	safe("secrets", V5.refreshSecrets, true)
	V5.relabelSeals()
	-- os nomes dos pets são refeitos no próximo quadro
	for owner in petSets do
		clearPets(owner)
	end
end

-- Tudo que é de um terreno e foi criado aqui (quando o terreno some do jogo)
local function clearPlotFx(s: any)
	s.BeltOn = false
	bancaFlash[s.Plot] = nil
	clearGround(s)
	clearShop(s)
	clearDiner(s)
	clearFleet(s)
	clearAmbient(s)
	clearRocket(s)
	clearFarmer(s)
end

local function refreshSnaps()
	local folder = workspace:FindFirstChild("Plots")
	local found: any = nil
	if folder then
		for _, plot in folder:GetChildren() do
			local s = snaps[plot]
			if not s then
				local origin = originOf(plot)
				if origin then
					s = newSnap(plot, origin)
					snaps[plot] = s
				end
			end
			if s then
				readSnap(s)
				if s.Mine then
					found = s
				end
			end
		end
	end
	mine = found
	for plot, s in snaps do
		if not plot.Parent then
			clearPlotFx(s)
			snaps[plot] = nil
		end
	end
end

local function watch(tag: string, onAdded: (Instance) -> (), onRemoved: ((Instance) -> ())?)
	for _, inst in CollectionService:GetTagged(tag) do
		task.spawn(safe, tag, onAdded, inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst)
		task.defer(safe, tag, onAdded, inst) -- espera os filhos e atributos chegarem
	end)
	if onRemoved then
		CollectionService:GetInstanceRemovedSignal(tag):Connect(onRemoved)
	end
end

-- Varredura de segurança: uma instância pode ganhar a tag antes de os atributos/filhos chegarem. De tempos
-- em tempos tenta de novo as que ficaram de fora (as funções "add" não fazem nada se já está pronto).
local RESCAN: { { any } } = {
	{ "VUOButton", addPad },
	{ "VUOWork", addWork },
	{ "VUOBiz", addBiz },
	{ "VUORare", addRare },
	{ "VUOLot", addLot },
	{ "VUOBag", addBag },
	{ "VUOKey", V5.addKey },
	{ "VUOChest", addChest }, -- (o Baú Secreto dos terrenos; o do obby já está pronto e não é refeito)
	{ "VUOSpin", addSpinner },
	{ "VUOMachine", addSpinner },
	{ "VUOHen", addHen },
}
local function rescan()
	for _, item in RESCAN do
		for _, inst in CollectionService:GetTagged(item[1]) do
			safe(item[1], item[2], inst)
		end
	end
end

-- algumas vezes por segundo: retratos, modos das placas, montes de moedas
local function syncGround(s: any)
	for i = 1, NUM_BIZ do
		if s.Cash[i] then
			syncPile(s, i, s.Ground[i], s.Cash[i])
		end
	end
	syncTips(s)
	-- venda na mão na banca dos OUTROS: aparece como o monte da banca crescendo
	local shop = s.Shop
	if shop then
		if not s.Mine and s.Biz[1] == 1 and s.Ground[1] > shop.LastGround then
			shopSale(s)
		end
		shop.LastGround = s.Ground[1]
	end
end

local function fastRefresh()
	updateEye()
	safe("snaps", refreshSnaps)
	safe("padModes", refreshPads)
	safe("signModes", refreshSigns, false)
	safe("lots", refreshLots)
	safe("bags", refreshBags)
	safe("keys", V5.refreshKeys)
	safe("secrets", V5.refreshSecrets)
	safe("weather", V5.refreshWeather)
	for _, s in snaps do
		safe("groundSync", syncGround, s)
	end
end

-- duas vezes por segundo: textos e o que só precisa existir ou não
local function slowRefresh()
	local now = workspace:GetServerTimeNow()
	safe("trees", refreshTrees)
	safe("likes", refreshLikes)
	safe("incubators", refreshIncubators)
	safe("giant", refreshGiant)
	safe("chests", refreshChests)
	safe("signs", refreshSigns, true)
	for _, s in snaps do
		safe("fleet", syncFleet, s)
		safe("ambient", syncAmbient, s, now)
		safe("rocket", syncRocket, s)
	end
end

function World.Start(gui: Instance)
	fxFolder = new("Folder", { Name = "VUOFx", Parent = workspace })
	startArrow()

	-- A câmera nasce afastada (dá para ver a granja, não só as costas do boneco). O truque: por um instante a
	-- distância mínima fica alta, o Roblox afasta a câmera, e logo o jogador volta a poder aproximar.
	local function zoomOut()
		pcall(function()
			player.CameraMinZoomDistance = 26
			task.wait(0.35)
			player.CameraMinZoomDistance = 0.5
		end)
	end
	task.spawn(zoomOut)
	player.CharacterAdded:Connect(function()
		task.wait(0.3)
		zoomOut()
	end)

	updateEye()
	safe("snaps", refreshSnaps)

	watch("VUOButton", addPad, removePad)
	watch("VUOWork", addWork, removeWork)
	watch("VUOBiz", addBiz, removeBiz)
	watch("VUORare", addRare, removeRare)
	watch("VUOLot", addLot, removeLot)
	watch("VUOBag", addBag, removeBag)
	watch("VUOKey", V5.addKey, V5.removeKey)
	watch("VUOPreview", refreshPreview)
	watch("VUOText", refreshText)
	watch("VUOTree", addTree)
	watch("VUOWindmill", addMill)
	watch("VUOGift", addGift)
	watch("VUOHunt", function()
		refreshHunt()
	end)
	watch("VUOHen", addHen, removeHen)
	watch("VUOMachine", addSpinner)
	watch("VUOSpin", addSpinner)
	watch("VUOIncubator", addIncubator)
	watch("VUOGiant", addGiant)
	watch("VUOWheel", addWheel)
	watch("VUOWheelPrompt", addWheelPrompt)
	watch("VUOChest", addChest, V5.removeSecret)

	RunService.RenderStepped:Connect(function(dt: number)
		dt = math.min(dt, 0.1) -- travou um instante: não deixa nada "teleportar"
		local t = os.clock()
		local now = workspace:GetServerTimeNow()
		updateEye()
		safe("coins", stepCoins, dt)
		safe("arcs", stepArcs, dt)
		safe("flyers", stepFlyers, dt)
		safe("pads", stepPads, t)
		safe("work", stepWork, t, now)
		safe("signs", stepSigns, dt, t, now)
		safe("ground", stepGround, dt, t)
		safe("lots", stepLots, t)
		safe("bags", stepBags, t, now)
		safe("keys", V5.stepKeys, dt, t)
		safe("secrets", V5.stepSecrets, t)
		safe("belts", stepBelts, dt, now)
		for _, s in snaps do
			-- cada função confere sozinha se o terreno tem aquilo e se está perto da câmera
			safe("shop", stepShop, s, dt, t)
			safe("diner", stepDiner, s, dt, t, now)
			safe("fleet", stepFleet, s, t, now)
			safe("rocket", stepRocket, s, dt, now)
			safe("farmer", stepFarmer, s, dt, t)
		end
		safe("hens", stepHens, t)
		safe("mills", stepMills, dt)
		safe("spinners", stepSpinners, t)
		safe("pets", stepPets, dt, t)
		safe("incubators", stepIncubators, t)
		safe("giant", stepGiant, t)
		safe("wheels", stepWheels, dt)
		safe("arrow", stepArrow, t)
		safe("rain", stepRain)
		safe("weather", V5.stepWeather)
	end)

	-- o que não precisa ser todo quadro: um laço só, para o jogo inteiro
	task.spawn(function()
		local n = 0
		while true do
			n += 1
			safe("fast", fastRefresh)
			if n % 3 == 0 then
				safe("slow", slowRefresh)
			end
			if n % 10 == 0 then
				safe("rescan", rescan)
			end
			task.wait(0.2)
		end
	end)
end

return World
