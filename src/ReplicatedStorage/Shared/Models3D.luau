--[[
	Models3D (ModuleScript em ReplicatedStorage > Shared)
	v14/v15: usa os MODELOS 3D de verdade (feitos no Higgsfield) quando você importar eles no Studio.
	Se não tiver modelo, o jogo continua usando os bonecos de peças (nada quebra).

	Jeito fácil (v15): importe TODOS os .glb de uma vez (File > Import 3D, selecione todos) e jogue
	os modelos dentro de ReplicatedStorage > Models3D (ou deixe no Workspace: o servidor leva sozinho).
	O jogo reconhece cada um pelo NOME DO ARQUIVO: "tinyrex.glb" ou o nome original do Higgsfield
	("hf_..._<código>.glb", a lista de códigos fica em Models3DJobs). Não precisa renomear nada.

	Jeito antigo (continua valendo): uma pasta com o Id (ex.: Models3D > sneaky) com o modelo dentro.
	Quer outro bichinho em 3D? Crie uma pasta com o Id dele (veja em Critters.luau) e coloque o modelo dentro.

	Atributos opcionais (na pasta do Id, no próprio modelo importado ou na pasta Models3D para valer para todos):
	  Turn   = gira o modelo (graus: 0, 90, 180, 270). A pasta Models3D vem com Turn = 90, que deixa os
	           modelos do Higgsfield de frente. Se um aparecer DE COSTAS, coloque Turn = 270 no modelo.
	  Size   = tamanho em studs (se quiser maior ou menor que o padrão)
	  Lift   = sobe/desce o modelo (studs), se ele ficar enterrado ou flutuando (NPCs e montarias;
	           os bichinhos se ajustam ao chão sozinhos)

	O modelo é "normalizado" sozinho: centro nos pés, frente para -Z, escala pelo tamanho pedido.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Jobs = require(script.Parent.Models3DJobs)

local Models3D = {}
Models3D.Jobs = Jobs -- Id → código do arquivo 3D do Higgsfield

local jobToId: { [string]: string } = {}
for id, job in Jobs do
	jobToId[string.lower(job)] = id
end
local UUID = "(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x)"

type Template = { Model: Model, Height: number, Max: number }

local templates: { [string]: Template | false } = {}
local index: { [string]: Instance }? = nil -- Id → modelo importado solto (achado pelo nome do arquivo)
local folder: Instance? = nil
local lookedUp = false
local okClient, clientValue = pcall(function()
	return RunService:IsClient()
end)
local isClient = okClient and clientValue == true

-- No celular/PC o conteúdo do ReplicatedStorage pode chegar um pouquinho depois dos scripts:
-- enquanto o jogo não terminou de carregar, "não achei" não fica guardado (tenta de novo depois)
local function canRemember(): boolean
	if not isClient then
		return true
	end
	local ok, loaded = pcall(function()
		return game:IsLoaded()
	end)
	return ok and loaded == true
end

local function getFolder(): Instance?
	if folder and folder.Parent then
		return folder
	end
	folder = ReplicatedStorage:FindFirstChild("Models3D")
	if not folder and isClient and not lookedUp then
		lookedUp = true
		folder = ReplicatedStorage:WaitForChild("Models3D", 3)
	end
	return folder
end

-- Caixa alinhada ao mundo que envolve todas as peças
local function worldBounds(model: Model): (Vector3, Vector3)
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = -minV
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 then
			local cf, half = part.CFrame, part.Size / 2
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						local p = cf:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z))
						minV = minV:Min(p)
						maxV = maxV:Max(p)
					end
				end
			end
		end
	end
	return minV, maxV
end

-- Id de um modelo importado pelo nome dele (nome do arquivo .glb): "tinyrex" ou "hf_..._<código>"
local function idFromName(name: string): string?
	local lower = string.lower(name)
	if Jobs[lower] then
		return lower
	end
	local uuid = string.match(lower, UUID)
	return if uuid then jobToId[uuid] else nil
end

-- Índice dos modelos soltos dentro de Models3D (o primeiro achado de cada Id vale)
local function getIndex(root: Instance): { [string]: Instance }
	if index then
		return index
	end
	local found: { [string]: Instance } = {}
	for _, d in root:GetDescendants() do
		if d:IsA("Model") or d:IsA("BasePart") then
			local id = idFromName(d.Name)
			if id and not found[id] then
				found[id] = d
			end
		end
	end
	if canRemember() then
		index = found
	end
	return found
end

-- Acha o modelo importado: pasta com o nome do Id (jeito antigo) ou modelo solto com o nome do arquivo.
-- Devolve também onde ler os atributos (Turn/Size/Lift)
local function findSource(id: string): (Instance?, Instance?)
	local root = getFolder()
	if not root then
		return nil, nil
	end
	local entry = root:FindFirstChild(id)
	if entry then
		if entry:IsA("Model") and entry:FindFirstChildWhichIsA("BasePart", true) then
			return entry, entry
		end
		if entry:IsA("BasePart") then
			return entry, entry
		end
		for _, child in entry:GetChildren() do
			if (child:IsA("Model") and child:FindFirstChildWhichIsA("BasePart", true)) or child:IsA("BasePart") then
				return child, entry
			end
		end
	end
	local loose = getIndex(root)[id]
	if loose and (loose:IsA("BasePart") or loose:FindFirstChildWhichIsA("BasePart", true)) then
		return loose, loose
	end
	return nil, nil
end

local function number(entry: Instance?, name: string): number?
	local value = entry and entry:GetAttribute(name)
	if typeof(value) ~= "number" or value ~= value or math.abs(value) >= 1e4 then
		-- sem atributo no modelo: vale o da pasta Models3D (para todos)
		local root = getFolder()
		value = if root and root ~= entry then root:GetAttribute(name) else nil
	end
	return if typeof(value) == "number" and value == value and math.abs(value) < 1e4 then value else nil
end

-- Onde ler os atributos de um Id (pasta do Id ou o modelo solto)
local entries: { [string]: Instance? } = {}

local function build(id: string): Template?
	local source, entry = findSource(id)
	if not source then
		return nil
	end
	entries[id] = entry
	local ok, result = pcall(function(): Template?
		local clone = source:Clone()
		local model: Model
		if clone:IsA("Model") then
			model = clone
		else
			model = Instance.new("Model")
			clone.Parent = model
		end
		model.Name = id
		-- sem PrimaryPart o pivô passa a ser o WorldPivot (pés no chão). pcall: o simulador de testes não aceita nil aqui
		pcall(function()
			model.PrimaryPart = nil
		end)
		-- só visual: tira scripts, humanoides e colisão
		for _, d in model:GetDescendants() do
			if d:IsA("LuaSourceContainer") or d:IsA("Humanoid") or d:IsA("AnimationController") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = false
				d.Massless = true
				d.Locked = true
			end
		end
		local minV, maxV = worldBounds(model)
		local size = maxV - minV
		if size.Y <= 0.01 or size.Magnitude ~= size.Magnitude then
			model:Destroy()
			return nil
		end
		local turn = number(entry, "Turn") or 0
		local bottom = Vector3.new((minV.X + maxV.X) / 2, minV.Y, (minV.Z + maxV.Z) / 2)
		model.WorldPivot = CFrame.new(bottom) * CFrame.Angles(0, math.rad(turn), 0)
		model:PivotTo(CFrame.identity)
		return { Model = model, Height = size.Y, Max = math.max(size.X, size.Y, size.Z) }
	end)
	if ok and result then
		return result
	end
	if not ok then
		warn("[Models3D] could not prepare", id, result)
	end
	return nil
end

local function template(id: string): Template?
	local cached = templates[id]
	if cached == nil then
		local built = build(id)
		if built or canRemember() then
			templates[id] = built or false
		end
		return built
	end
	return if cached then cached else nil
end

-- Existe modelo 3D para este Id?
function Models3D.Has(id: string?): boolean
	return typeof(id) == "string" and template(id) ~= nil
end

--[[
	Get(id, options) → Model? (clone novo), altura
	options.Size   = tamanho em studs (a pasta pode trocar com o atributo Size)
	options.Fit    = "Height" (altura = Size) ou "Max" (maior lado = Size)
	options.Anchored = false para soldar num personagem/peça que se mexe
	O pivô do modelo fica no CHÃO, no meio, olhando para -Z.
]]
function Models3D.Get(id: string?, options: any?): (Model?, number)
	if typeof(id) ~= "string" then
		return nil, 0
	end
	local t = template(id)
	if not t then
		return nil, 0
	end
	options = options or {}
	local entry = entries[id]
	local wanted = number(entry, "Size") or options.Size or 5
	local current = if options.Fit == "Max" then t.Max else t.Height
	local factor = math.clamp(wanted / math.max(current, 0.01), 0.01, 100)
	local model = t.Model:Clone()
	if math.abs(factor - 1) > 1e-3 then
		pcall(function()
			model:ScaleTo(model:GetScale() * factor)
		end)
	end
	model:PivotTo(CFrame.identity)
	-- Lift (studs, já no tamanho final): sobe/desce as peças e deixa o pivô no chão
	local lift = number(entry, "Lift") or 0
	if lift ~= 0 then
		model:PivotTo(CFrame.new(0, lift, 0))
		model.WorldPivot = CFrame.identity
	end
	if options.Anchored == false then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
			end
		end
	end
	return model, t.Height * factor
end

-- Esquece os modelos preparados (usado nos testes; no jogo não precisa)
function Models3D.Reset()
	templates = {}
	index = nil
	entries = {}
end

-- Lista dos Ids que já têm modelo 3D (para o Output)
function Models3D.Loaded(): { string }
	local list = {}
	local seen = {}
	local root = getFolder()
	local function check(id: string)
		if not seen[id] then
			seen[id] = true
			if Models3D.Has(id) then
				table.insert(list, id)
			end
		end
	end
	for id in Jobs do
		check(id)
	end
	if root then
		for _, entry in root:GetChildren() do
			if entry:IsA("Folder") or entry:IsA("Model") or entry:IsA("BasePart") then
				check(entry.Name)
			end
		end
	end
	table.sort(list)
	return list
end

-- Servidor: modelos importados que ficaram soltos no Workspace (com nome de arquivo conhecido)
-- vão sozinhos para ReplicatedStorage > Models3D quando o jogo liga. Devolve quantos moveu.
function Models3D.CollectFromWorkspace(): number
	local root = getFolder()
	if not root or isClient then
		return 0
	end
	local moved = 0
	for _, child in workspace:GetChildren() do
		if (child:IsA("Model") or child:IsA("MeshPart")) and not child:IsA("Terrain") then
			local lower = string.lower(child.Name)
			local byName = Jobs[child.Name] ~= nil -- nome exato (ex.: "tinyrex")
			local byCode = string.find(lower, "^hf_") ~= nil and idFromName(child.Name) ~= nil
			if byName or byCode then
				child.Parent = root
				moved += 1
			end
		end
	end
	if moved > 0 then
		Models3D.Reset()
	end
	return moved
end

return Models3D
