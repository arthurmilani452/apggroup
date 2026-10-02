--[[
	LotLayout (ModuleScript em ReplicatedStorage > Shared)          Prefeito Tycoon
	Onde fica cada terreno no mundo. Servidor e cliente usam as mesmas contas.

	Os terrenos ficam em volta do hub (centro em 0, 0, 0). Cada terreno tem um CFrame na
	"frente-centro" (onde começa a Avenida): o -Z local olha para o hub e o +Z vai para o fundo.

	API:
	  LotLayout.CFrame(index) -> CFrame
	  LotLayout.CellCFrame(index, cx, cz) -> CFrame      centro de uma casa (ou de um prédio)
	  LotLayout.BuildingCFrame(index, placed) -> CFrame  centro + giro do prédio
	  LotLayout.SpawnCFrame(index) -> CFrame             onde o jogador aparece na cidade
	  LotLayout.ToCell(index, worldPosition) -> x, z     casa da grade embaixo de um ponto
	  LotLayout.Contains(index, worldPosition, margin?) -> boolean
]]

local Shared = script.Parent
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)

local LotLayout = {}

local cache: { [number]: CFrame } = {}

function LotLayout.CFrame(index: number): CFrame
	local cached = cache[index]
	if cached then
		return cached
	end
	local angle = (index - 1) * 2 * math.pi / Config.MaxPlayers
	local dir = Vector3.new(math.sin(angle), 0, math.cos(angle))
	local pos = dir * Config.LotRadius + Vector3.new(0, Config.LotGroundY, 0)
	-- girar em Y pelo próprio ângulo deixa o -Z local apontando para o hub (igual a lookAt(pos, pos - dir))
	local cf = CFrame.new(pos) * CFrame.Angles(0, angle, 0)
	cache[index] = cf
	return cf
end

function LotLayout.CellCFrame(index: number, cx: number, cz: number): CFrame
	local lx, lz = Grid.LocalPosition(cx, cz)
	return LotLayout.CFrame(index) * CFrame.new(lx, 0, lz)
end

function LotLayout.BuildingCFrame(index: number, placed: any): CFrame
	local cx, cz = Grid.Center(placed)
	return LotLayout.CellCFrame(index, cx, cz) * CFrame.Angles(0, -placed.R * math.pi / 2, 0)
end

function LotLayout.SpawnCFrame(index: number): CFrame
	return LotLayout.CFrame(index) * CFrame.new(0, 4, -50) * CFrame.Angles(0, math.pi, 0)
end

function LotLayout.ToCell(index: number, position: Vector3): (number, number)
	local p = LotLayout.CFrame(index):PointToObjectSpace(position)
	return Grid.CellAt(p.X, p.Z)
end

-- O ponto está dentro do terreno (grade + a área da Prefeitura na frente)?
function LotLayout.Contains(index: number, position: Vector3, margin: number?): boolean
	local p = LotLayout.CFrame(index):PointToObjectSpace(position)
	local half = Config.GridSize * Config.CellSize / 2
	local extra = margin or 0
	return math.abs(p.X) <= half + extra and p.Z >= -60 - extra and p.Z <= half * 2 + extra
end

return LotLayout
