--[[
	Instalar3D (v6): coloca no jogo os modelos 3D do Higgsfield, sozinho. Só roda no Studio.

	Como usar:
	  1. Arquivo > Importar 3D e escolha os .glb da pasta higgsfield/modelos (dá para escolher vários).
	     O importador deixa cada um no Workspace com o nome do arquivo (Celeiro_1, Moinho...).
	  2. Na barra de comando do Studio (Exibir > Barra de Comando), cole e aperte Enter:
	         require(game.ServerScriptService.Game.Instalar3D)()
	  3. Pronto. Para cada modelo com nome conhecido, ele:
	       • ancora as peças e ajusta o tamanho para caber no lugar do modelo antigo;
	       • gira 90° se ele estiver "de lado" em relação ao antigo;
	       • cria a peça Root (base, centro) que o jogo usa para posicionar;
	       • guarda o modelo antigo em ServerStorage > Assets_Antigos (para voltar, é só arrastar de volta);
	       • põe o novo em ReplicatedStorage > Assets com o mesmo nome.
	  Dá para desfazer tudo com Ctrl+Z.

	A Roleta fica de fora: a parte que gira tem nome próprio no modelo antigo. Para trocar mesmo assim:
	         require(game.ServerScriptService.Game.Instalar3D)({ Roleta = true })
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

-- tamanho do lugar de cada modelo (largura x altura x profundidade, em studs), medido nos modelos antigos
local SIZES: { [string]: Vector3 } = {
	Celeiro_1 = Vector3.new(36.2, 13.6, 31.1),
	Celeiro_2 = Vector3.new(35.7, 12.4, 27.8),
	Celeiro_3 = Vector3.new(39, 13, 31.5),
	Celeiro_4 = Vector3.new(46, 26.6, 14.4),
	Celeiro_5 = Vector3.new(36.1, 23.1, 33.3),
	Chocadeira = Vector3.new(6, 6.5, 6.1),
	Esteira = Vector3.new(3.4, 2.5, 4),
	Garagem = Vector3.new(12.8, 9, 15.6),
	Lampiao = Vector3.new(1.9, 9, 3.8),
	Maquina_Carimbo = Vector3.new(9.1, 9.5, 6),
	Maquina_Embaladora = Vector3.new(10, 9, 8),
	Maquina_Lavadora = Vector3.new(9.2, 9, 7),
	Maquina_Pintora = Vector3.new(9.1, 9.5, 7.1),
	Moinho = Vector3.new(24.6, 32.6, 15.5),
	Ovo_Dourado = Vector3.new(1.2, 1.5, 1.1),
	Pet_Ovinho = Vector3.new(2.3, 2.5, 2),
	Pinheiro = Vector3.new(8.4, 15, 8.4),
	Placa_Neon = Vector3.new(4.9, 10, 1.8),
	Plataforma_Foguete = Vector3.new(18, 20, 18),
	Portal = Vector3.new(23.2, 13.7, 2.9),
	Roleta = Vector3.new(9, 13, 4.6),
}

local function findImported(name: string): Instance?
	for _, place in { workspace, ServerStorage, ReplicatedStorage } do
		local folder = place:FindFirstChild("Higgsfield")
		local found = (folder and folder:FindFirstChild(name)) or place:FindFirstChild(name)
		if found and (found:IsA("Model") or found:IsA("BasePart")) and not found:IsDescendantOf(ReplicatedStorage:FindFirstChild("Assets") or game) then
			return found
		end
	end
	return nil
end

local function install(name: string, imported: Instance, target: Vector3, assets: Instance, backup: Instance): string
	local model: Model
	if imported:IsA("Model") then
		model = imported
	else
		model = Instance.new("Model")
		model.Name = name
		model.Parent = imported.Parent
		imported.Parent = model
	end
	-- um Root antigo (de outra tentativa) atrapalharia a medida
	local oldRoot = model:FindFirstChild("Root")
	if oldRoot then
		oldRoot:Destroy()
	end
	model.PrimaryPart = nil
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanTouch = false
			part.CanQuery = false
		end
	end
	local _, size = model:GetBoundingBox()
	-- de lado? (largo onde o antigo é fundo e vice-versa): gira 90°
	if (size.X > size.Z * 1.25 and target.Z > target.X * 1.25) or (size.Z > size.X * 1.25 and target.X > target.Z * 1.25) then
		model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.rad(90), 0))
		_, size = model:GetBoundingBox()
	end
	-- maior tamanho que ainda cabe no lugar do antigo
	local factor = math.min(target.X / size.X, target.Y / size.Y, target.Z / size.Z)
	if factor > 0 and factor ~= math.huge then
		model:ScaleTo(model:GetScale() * factor)
	end
	-- Root no centro da base, olhando para -Z
	local box, finalSize = model:GetBoundingBox()
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.CastShadow = false
	root.CFrame = CFrame.new(box.Position - Vector3.new(0, finalSize.Y / 2, 0))
	root.Parent = model
	model.PrimaryPart = root
	model.Name = name
	-- o antigo vai para o backup
	local old = assets:FindFirstChild(name)
	if old then
		local previous = backup:FindFirstChild(name)
		if previous then
			previous:Destroy()
		end
		old.Parent = backup
	end
	model:PivotTo(CFrame.new(0, 0, 0))
	model.Parent = assets
	return ("%s: ok (%.1f x %.1f x %.1f)"):format(name, finalSize.X, finalSize.Y, finalSize.Z)
end

return function(options: { [string]: boolean }?)
	if RunService:IsRunning() then
		warn("[Instalar3D] use no Studio com o jogo PARADO (barra de comando), não durante o Play")
		return
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		warn("[Instalar3D] não achei ReplicatedStorage > Assets")
		return
	end
	local backup = ServerStorage:FindFirstChild("Assets_Antigos")
	if not backup then
		backup = Instance.new("Folder")
		backup.Name = "Assets_Antigos"
		backup.Parent = ServerStorage
	end
	local okRec, recording = pcall(ChangeHistoryService.TryBeginRecording, ChangeHistoryService, "Instalar modelos 3D")
	if not okRec then
		recording = nil
	end
	local done, missing = {}, {}
	for name, target in SIZES do
		if name == "Roleta" and not (options and options.Roleta) then
			continue
		end
		local imported = findImported(name)
		if imported then
			local ok, result = pcall(install, name, imported, target, assets, backup :: Instance)
			table.insert(done, if ok then result else (name .. ": ERRO " .. tostring(result)))
		else
			table.insert(missing, name)
		end
	end
	if recording then
		pcall(ChangeHistoryService.FinishRecording, ChangeHistoryService, recording, Enum.FinishRecordingOperation.Commit)
	end
	table.sort(done)
	table.sort(missing)
	print(("[Instalar3D] instalados %d:"):format(#done))
	for _, line in done do
		print("   " .. line)
	end
	if #missing > 0 then
		print("[Instalar3D] não achei no Workspace (importe e rode de novo): " .. table.concat(missing, ", "))
	end
end
