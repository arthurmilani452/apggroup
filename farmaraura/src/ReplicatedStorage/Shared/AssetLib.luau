--[[
	AssetLib: pega os modelos de ReplicatedStorage > Assets ("Ovo_Dourado", "Galinha_Cristal", "Banca"...).
	Cada modelo tem uma peça invisível "Root" (PrimaryPart) no CENTRO DA BASE, olhando para a frente (-Z):
	model:PivotTo(cf) coloca a base exatamente em cf.

	Para trocar por arte 3D de verdade (malha): importe o modelo no Studio, coloque em Assets com o MESMO
	nome e apague o antigo. Se o modelo novo não tiver "Root", o jogo cria uma na base dele.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetLib = {}

local function assetsFolder(): Instance?
	return ReplicatedStorage:FindFirstChild("Assets")
end

function AssetLib.Has(name: string): boolean
	local folder = assetsFolder()
	return folder ~= nil and folder:FindFirstChild(name) ~= nil
end

local function ensureRoot(model: Model)
	local root = model.PrimaryPart
	if root then
		return
	end
	local cf, size = model:GetBoundingBox()
	local part = Instance.new("Part")
	part.Name = "Root"
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.CFrame = cf * CFrame.new(0, -size.Y / 2, 0)
	part.Parent = model
	model.PrimaryPart = part
end

-- Cópia pronta para usar: ancorada, sem scripts, na escala pedida. nil se o asset não existir.
function AssetLib.Get(name: string, scale: number?): Model?
	local folder = assetsFolder()
	local source = folder and folder:FindFirstChild(name)
	if not source then
		return nil
	end
	local model: Model
	if source:IsA("Model") then
		model = source:Clone()
	else
		model = Instance.new("Model")
		model.Name = name
		source:Clone().Parent = model
	end
	local hasPart = false
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			hasPart = true
		end
	end
	if not hasPart then
		model:Destroy()
		return nil
	end
	ensureRoot(model)
	if scale and math.abs(scale - 1) > 0.001 then
		pcall(function()
			model:ScaleTo(scale)
		end)
	end
	model:SetAttribute("Asset", name)
	return model
end

function AssetLib.SetCollide(model: Instance, collide: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = collide
			if not collide then
				d.CanTouch = false
				d.CanQuery = false
			end
		end
	end
end

-- Solda todas as peças ao "root" (para carregar o modelo grudado no personagem)
function AssetLib.WeldTo(model: Model, root: BasePart)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = d
			weld.Parent = d
		end
	end
end

function AssetLib.Find(model: Instance, name: string): BasePart?
	local found = model:FindFirstChild(name, true)
	if found and found:IsA("BasePart") then
		return found
	end
	return nil
end

return AssetLib
