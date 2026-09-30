--[[
	PetFollow (ModuleScript em StarterPlayer > StarterPlayerScripts)
	Desenha os pets equipados de TODOS os jogadores seguindo o dono, com animação (PetMotion):
	pulinhos ao andar, balanço, amassa/estica, pulo junto com o dono, brincadeiras quando parado.
	Tudo acontece só na tela de cada jogador (o servidor só diz quais pets cada um equipou,
	no atributo "Pets" do jogador), então não pesa o servidor nem a internet.
	No celular: pets longe da câmera somem, pets médios se mexem sem amassar, e o chão é
	conferido poucas vezes por segundo.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Critters = require(Shared:WaitForChild("Critters"))
local Builder = require(Shared:WaitForChild("CritterBuilder"))
local PetMotion = require(script.Parent:WaitForChild("PetMotion"))

local PetFollow = {}

-- cada peça do pet guarda onde fica em relação aos PÉS (para amassar/esticar em volta do chão)
type Piece = {
	Part: BasePart,
	Offset: Vector3, -- posição em relação aos pés
	Rotation: CFrame, -- giro da peça em relação aos pés
	Size: Vector3,
	Axes: { Vector3 }, -- eixos da peça (para amassar certo peças giradas)
	CanResize: boolean,
}

type Pet = {
	Model: Model,
	Pieces: { Piece },
	Parts: { BasePart },
	CFrames: { CFrame },
	Motion: PetMotion.State,
	GroundY: number,
	NextRay: number,
	Squashed: boolean,
	LastScaleY: number,
	Dust: ParticleEmitter?,
}
type View = { Key: string, Pets: { Pet } }

local PET_SIZE = 2.6 -- tamanho máximo de um pet (studs)
local VIEW_DISTANCE = 160
local SQUASH_DISTANCE = 70 -- mais longe que isso o pet anda sem amassar (economiza no celular)
-- lugar de cada pet atrás do dono (+Z = atrás)
local SLOTS = { Vector3.new(-3.4, 0, 3.2), Vector3.new(3.4, 0, 3.2), Vector3.new(0, 0, 5.8) }

local views: { [Player]: View } = {}
local folder: Folder
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function makeDust(root: BasePart, ground: number): ParticleEmitter
	local attachment = Instance.new("Attachment")
	attachment.Name = "Feet"
	attachment.Position = Vector3.new(0, -ground, 0)
	attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Dust"
	emitter.Rate = 0
	emitter.Enabled = true
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(235, 225, 210))
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1.1) })
	emitter.Lifetime = NumberRange.new(0.35, 0.55)
	emitter.Speed = NumberRange.new(1.5, 3)
	emitter.SpreadAngle = Vector2.new(80, 10)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Drag = 4
	emitter.LightEmission = 0
	emitter.Parent = attachment
	return emitter
end

local function buildPet(entry: string, index: number): Pet?
	local id, mutation = string.match(entry, "^([^:]+):?(.*)$")
	local def = id and Critters.ById[id]
	if not def then
		return nil
	end
	local model, root, ground = Builder.Build(def)
	local aura = model:FindFirstChild("Aura")
	if aura then
		aura:Destroy()
	end
	if mutation and mutation ~= "" then
		Builder.ApplyMutation(model, mutation)
	end
	local _, size = model:GetBoundingBox()
	local biggest = math.max(size.X, size.Y, size.Z, 0.1)
	local scale = math.clamp(PET_SIZE / biggest, 0.15, 1)
	pcall(function()
		model:ScaleTo(scale)
	end)
	ground *= scale

	-- "esqueleto" feito à mão: tira as soldas e guarda cada peça em relação aos pés
	local feet = root.CFrame * CFrame.new(0, -ground, 0)
	local pieces: { Piece } = {}
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	local top = 0
	for _, d in model:GetDescendants() do
		if d:IsA("WeldConstraint") or d:IsA("Weld") or d:IsA("Motor6D") then
			d:Destroy()
		end
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			local relative = feet:ToObjectSpace(part.CFrame)
			local rotation = relative - relative.Position
			table.insert(pieces, {
				Part = part,
				Offset = relative.Position,
				Rotation = rotation,
				Size = part.Size,
				Axes = { rotation.RightVector, rotation.UpVector, rotation.LookVector },
				-- bolas (olhos) ficam sempre redondas: só as outras peças amassam
				CanResize = part ~= root and not (part:IsA("Part") and part.Shape == Enum.PartType.Ball),
			})
			table.insert(parts, part)
			table.insert(cframes, part.CFrame)
			if part ~= root and part.Transparency < 1 then
				top = math.max(top, relative.Position.Y + part.Size.Y / 2)
			end
		end
	end
	model.Parent = folder
	local float = (Config.RarityIndex[def.Rarity] or 1) >= 5 or def.Float == true -- Lendário ou melhor voa
	return {
		Model = model,
		Pieces = pieces,
		Parts = parts,
		CFrames = cframes,
		Motion = PetMotion.new({ Float = float, Size = math.max(top, 0.5), Index = index }),
		GroundY = 0,
		NextRay = 0,
		Squashed = false,
		LastScaleY = 1,
		Dust = if float then nil else makeDust(root, ground),
	}
end

-- quanto um eixo da peça estica com a escala (sx, sy, sz) dos pés
local function stretch(axis: Vector3, sx: number, sy: number, sz: number): number
	return Vector3.new(axis.X * sx, axis.Y * sy, axis.Z * sz).Magnitude
end

-- põe as peças no lugar (amassando/esticando em volta dos pés se squash = true)
local function place(pet: Pet, feet: CFrame, scale: Vector3, squash: boolean)
	local sx, sy, sz = scale.X, scale.Y, scale.Z
	if not squash then
		sx, sy, sz = 1, 1, 1
	end
	local resize = squash and math.abs(sy - pet.LastScaleY) > 0.004
	local unsquash = not squash and pet.Squashed
	for i, piece in pet.Pieces do
		local o = piece.Offset
		pet.CFrames[i] = feet * CFrame.new(o.X * sx, o.Y * sy, o.Z * sz) * piece.Rotation
		if piece.CanResize and (resize or unsquash) then
			local axes = piece.Axes
			local size = piece.Size
			piece.Part.Size = Vector3.new(
				size.X * stretch(axes[1], sx, sy, sz),
				size.Y * stretch(axes[2], sx, sy, sz),
				size.Z * stretch(axes[3], sx, sy, sz)
			)
		end
	end
	if resize or unsquash then
		pet.LastScaleY = sy
	end
	pet.Squashed = squash
	workspace:BulkMoveTo(pet.Parts, pet.CFrames, Enum.BulkMoveMode.FireCFrameChanged)
end

local function clear(player: Player)
	local view = views[player]
	if view then
		for _, pet in view.Pets do
			pet.Model:Destroy()
		end
	end
	views[player] = nil
end

local function refresh(player: Player)
	local key = player:GetAttribute("Pets")
	key = if typeof(key) == "string" then key else ""
	local view = views[player]
	if view and view.Key == key then
		return
	end
	clear(player)
	local pets = {}
	for entry in string.gmatch(key, "[^,]+") do
		if #pets >= #SLOTS then
			break
		end
		local ok, pet = pcall(buildPet, entry, #pets + 1)
		if ok and pet then
			table.insert(pets, pet)
		elseif not ok then
			warn("[PetFollow] could not build pet", entry, pet)
		end
	end
	views[player] = { Key = key, Pets = pets }
end

local function watch(player: Player)
	refresh(player)
	player:GetAttributeChangedSignal("Pets"):Connect(function()
		refresh(player)
	end)
end

local function updateFilter()
	local ignore: { Instance } = { folder }
	local active = workspace:FindFirstChild("ActiveCritters")
	if active then
		table.insert(ignore, active)
	end
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	rayParams.FilterDescendantsInstances = ignore
end

function PetFollow.Init()
	folder = Instance.new("Folder")
	folder.Name = "ClientPets"
	folder.Parent = workspace

	for _, other in Players:GetPlayers() do
		watch(other)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)

	local nextFilter = 0
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		if now >= nextFilter then
			nextFilter = now + 1
			updateFilter()
		end
		local camera = workspace.CurrentCamera
		local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero
		local localPlayer = Players.LocalPlayer
		local hideOthers = localPlayer:GetAttribute("ShowOtherPets") == false
		local lowGfx = localPlayer:GetAttribute("LowGfx") == true
		local range = if lowGfx then VIEW_DISTANCE * 0.5 else VIEW_DISTANCE
		for owner, view in views do
			local character = owner.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local distance = if root then (root.Position - cameraPosition).Magnitude else math.huge
			local visible = root ~= nil
				and distance < range
				and not (hideOthers and owner ~= localPlayer)
				and not owner:GetAttribute("HidePets") -- esconde-esconde: os pets não entregam o esconderijo
			-- o dono pulou? (velocidade para cima; funciona para todos os jogadores)
			local rising = root ~= nil and root.AssemblyLinearVelocity.Y > 9
			local squash = not lowGfx and distance < SQUASH_DISTANCE
			for index, pet in view.Pets do
				if not visible or not root then
					if pet.Model.Parent then
						pet.Model.Parent = nil
					end
					pet.Motion.Position = nil
					continue
				end
				if not pet.Model.Parent then
					pet.Model.Parent = folder
				end
				local look = root.CFrame.LookVector
				local flatLook = Vector3.new(look.X, 0, look.Z)
				if flatLook.Magnitude < 0.01 then
					flatLook = Vector3.new(0, 0, -1)
				end
				flatLook = flatLook.Unit
				local facing = CFrame.lookAt(root.Position, root.Position + flatLook)
				local target = (facing * CFrame.new(SLOTS[index])).Position
				-- chão (poucas vezes por segundo)
				local here = pet.Motion.Position or target
				if now >= pet.NextRay then
					pet.NextRay = now + 0.12 + math.random() * 0.05
					local hit = workspace:Raycast(Vector3.new(here.X, root.Position.Y + 4, here.Z), Vector3.new(0, -24, 0), rayParams)
					pet.GroundY = if hit then hit.Position.Y else root.Position.Y - 3
				end
				local pose = PetMotion.Step(pet.Motion, dt, {
					Target = target,
					OwnerLook = flatLook,
					OwnerRising = rising,
					GroundY = pet.GroundY,
					Now = now,
				})
				place(pet, pose.CFrame, pose.Scale, squash)
				if pose.Landed and pet.Dust and squash then
					pet.Dust:Emit(if pose.Speed > 10 then 4 else 2)
				end
			end
		end
	end)
end

return PetFollow
