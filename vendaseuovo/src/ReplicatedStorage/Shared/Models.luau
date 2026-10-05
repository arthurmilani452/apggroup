--[[
	Models: monta galinhas, ovos e produtos com peças (não precisa de modelo 3D).
	Quando existe um MODELO 3D importado (veja Models3D.luau), ele é usado no lugar das peças.
	Todo modelo sai com a base no chão (y = 0) e com um "Root" como PrimaryPart.
]]

local Models3D = require(script.Parent.Models3D)

local Models = {}

local ORANGE = Color3.fromRGB(255, 150, 30)
local RED = Color3.fromRGB(220, 40, 40)
local BLACK = Color3.fromRGB(20, 20, 20)

local function newPart(model: Model, root: BasePart?, name: string, size: Vector3, cframe: CFrame, color: Color3, props: { [string]: any }?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = true
	if props then
		for key, value in props do
			(p :: any)[key] = value
		end
	end
	p.Parent = model
	if root then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
	end
	return p
end

local function ellipsoid(part: BasePart)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
end

local function makeRoot(model: Model, size: Vector3, center: Vector3): BasePart
	local root = newPart(model, nil, "Root", size, CFrame.new(center), Color3.new(1, 1, 1), { Transparency = 1 })
	model.PrimaryPart = root
	return root
end

function Models.Hen(hen: any): Model
	local fromFile = Models3D.Get(hen.Id, 2.8)
	if fromFile then
		fromFile.Name = "Hen"
		if hen.Glow then
			local light = Instance.new("PointLight")
			light.Color = hen.Body
			light.Range = 10
			light.Brightness = 1.5
			light.Parent = fromFile.PrimaryPart
		end
		return fromFile
	end
	local model = Instance.new("Model")
	model.Name = "Hen"
	local root = makeRoot(model, Vector3.new(2, 2.8, 2.6), Vector3.new(0, 1.4, 0))
	local material = if hen.Glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local body = newPart(model, root, "Body", Vector3.new(2, 1.8, 2.4), CFrame.new(0, 1.4, 0), hen.Body, { Material = material })
	ellipsoid(body)
	local head = newPart(model, root, "Head", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 2.5, -0.9), hen.Body, { Shape = Enum.PartType.Ball })
	newPart(model, root, "Beak", Vector3.new(0.4, 0.3, 0.5), CFrame.new(0, 2.4, -1.65), ORANGE)
	newPart(model, root, "Comb", Vector3.new(0.2, 0.5, 0.7), CFrame.new(0, 3.2, -0.9), RED)
	newPart(model, root, "Wattle", Vector3.new(0.2, 0.35, 0.2), CFrame.new(0, 2.1, -1.5), RED)
	for i, side in { -1, 1 } do
		newPart(model, root, "Eye" .. i, Vector3.new(0.22, 0.22, 0.22), CFrame.new(side * 0.42, 2.65, -1.38), BLACK, { Shape = Enum.PartType.Ball })
		local wing = newPart(model, root, "Wing" .. i, Vector3.new(0.35, 1, 1.5), CFrame.new(side * 1.02, 1.45, 0.1), hen.Wing)
		ellipsoid(wing)
		newPart(model, root, "Leg" .. i, Vector3.new(0.2, 0.6, 0.2), CFrame.new(side * 0.4, 0.3, 0), ORANGE)
		newPart(model, root, "Foot" .. i, Vector3.new(0.5, 0.1, 0.6), CFrame.new(side * 0.4, 0.05, -0.15), ORANGE)
	end
	local tail = newPart(model, root, "Tail", Vector3.new(1.2, 1.1, 0.4), CFrame.new(0, 2, 1.2) * CFrame.Angles(math.rad(-25), 0, 0), hen.Wing)
	ellipsoid(tail)
	if hen.Spots then
		for i, offset in { Vector3.new(0.6, 1.8, -0.3), Vector3.new(-0.5, 1.6, 0.5), Vector3.new(0.3, 1.2, 0.9), Vector3.new(-0.7, 1.1, -0.4) } do
			newPart(model, root, "Spot" .. i, Vector3.new(0.45, 0.45, 0.45), CFrame.new(offset), Color3.fromRGB(240, 240, 240), { Shape = Enum.PartType.Ball })
		end
	end
	if hen.Glow then
		local light = Instance.new("PointLight")
		light.Color = hen.Body
		light.Range = 10
		light.Brightness = 1.5
		light.Parent = body
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120))
		sparkle.Size = NumberSequence.new(0.4, 0)
		sparkle.Lifetime = NumberRange.new(0.6, 1)
		sparkle.Rate = 6
		sparkle.Speed = NumberRange.new(1, 2)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.LightEmission = 1
		sparkle.Parent = head
	end
	return model
end

-- Cenário em 3D (barraca, ninho, fogão, carroça, fonte, granja) quando existir; senão nil (fica o de peças)
function Models.Prop(id: string, height: number): Model?
	return Models3D.Get(id, height)
end

-- Troca o visual de peças pelo 3D: todo Model com o atributo Prop3D (ex.: "barraca") dentro de "root"
-- fica invisível (mas continua com colisão) e ganha o modelo 3D por cima, do mesmo tamanho.
-- Atributos do builder: Prop3D (id), PropHeight (altura em studs), Facing (giro em graus).
function Models.ApplyProps(root: Instance)
	local looks = {}
	if root:GetAttribute("Prop3D") then
		table.insert(looks, root)
	end
	for _, d in root:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("Prop3D") then
			table.insert(looks, d)
		end
	end
	for _, look in looks do
		local id = look:GetAttribute("Prop3D")
		if look:GetAttribute("Applied") or not Models3D.Has(id) then
			continue
		end
		local cf, size = (look :: Model):GetBoundingBox()
		local height = tonumber(look:GetAttribute("PropHeight")) or size.Y
		local model = Models3D.Get(id, height)
		if not model then
			continue
		end
		for _, d in look:GetDescendants() do
			if d:IsA("BasePart") then
				d.Transparency = 1
			elseif d:IsA("Decal") or d:IsA("Texture") then
				d.Transparency = 1
			elseif d:IsA("SurfaceGui") then
				d.Enabled = false
			end
		end
		local facing = math.rad(tonumber(look:GetAttribute("Facing")) or 0)
		local base = Vector3.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z)
		model:PivotTo(CFrame.new(base) * CFrame.Angles(0, facing, 0) * CFrame.new(0, model.PrimaryPart.Size.Y / 2, 0))
		model.Name = id .. "3D"
		model.Parent = look.Parent
		look:SetAttribute("Applied", true)
	end
end

-- Ovo solto (ninho, panela)
function Models.Egg(color: Color3): BasePart
	local egg = Instance.new("Part")
	egg.Name = "Egg"
	egg.Size = Vector3.new(0.6, 0.8, 0.6)
	egg.Color = color
	egg.Material = Enum.Material.SmoothPlastic
	egg.Anchored = true
	egg.CanCollide = false
	egg.CanTouch = false
	egg.CanQuery = false
	egg.Massless = true
	ellipsoid(egg)
	return egg
end

-- Produto da vitrine: ovo cru em pé, ou ovo cozido aberto num copinho
function Models.Item(eggColor: Color3, recipe: string): Model
	local fromFile = Models3D.Get(if recipe == "boiled" then "ovocozido" else "ovo", if recipe == "boiled" then 1.2 else 0.9)
	if fromFile then
		fromFile.Name = "Item"
		if recipe ~= "boiled" then
			-- o ovo 3D ganha a cor da raça (ovo dourado, pintado...)
			for _, d in fromFile:GetDescendants() do
				if d:IsA("MeshPart") then
					d.TextureID = ""
					d.Color = eggColor
				end
			end
		end
		return fromFile
	end
	local model = Instance.new("Model")
	model.Name = "Item"
	local root = makeRoot(model, Vector3.new(0.8, 1.2, 0.8), Vector3.new(0, 0.6, 0))
	if recipe == "boiled" then
		newPart(model, root, "Cup", Vector3.new(0.5, 0.7, 0.7), CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(80, 160, 230), { Shape = Enum.PartType.Cylinder })
		local white = newPart(model, root, "White", Vector3.new(0.6, 0.6, 0.6), CFrame.new(0, 0.75, 0), Color3.fromRGB(250, 250, 245))
		ellipsoid(white)
		newPart(model, root, "Yolk", Vector3.new(0.35, 0.35, 0.35), CFrame.new(0, 1.0, 0), Color3.fromRGB(255, 190, 30), { Shape = Enum.PartType.Ball })
		local band = newPart(model, root, "Shell", Vector3.new(0.62, 0.15, 0.62), CFrame.new(0, 0.55, 0), eggColor)
		ellipsoid(band)
	else
		local egg = newPart(model, root, "Egg", Vector3.new(0.6, 0.8, 0.6), CFrame.new(0, 0.4, 0), eggColor)
		ellipsoid(egg)
	end
	return model
end

-- Ancora (true) ou solta (false) um modelo montado aqui. Soltar é para carregar na cabeça de alguém.
function Models.SetAnchored(model: Model, anchored: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = anchored
		end
	end
end

return Models
