--[[
	Grid (ModuleScript em ReplicatedStorage > Shared)          Prefeito Tycoon
	A grade de um terreno: onde dá para construir, quem ocupa cada casa, ruas ligadas à Avenida.
	PURO (sem API do Roblox): dá para testar no Lune. O servidor e o cliente usam as mesmas regras.

	Coordenadas: x de 1 a N (esquerda -> direita olhando do hub), z de 1 a N (da avenida para o fundo).
	A fileira z = 1 é a Avenida: rua fixa que não se constrói nem se demole. Os prédios são guardados
	pela casa do canto (menor x, menor z) + rotação 0..3.

	API:
	  Grid.new() -> State
	  Grid.Bounds(level) -> x1, x2, z1, z2         área liberada pela expansão
	  Grid.CanPlace(state, level, def, x, z, rot) -> ok, motivo?
	  Grid.Place(state, def, x, z, rot) -> uid      (não confere nada: chame CanPlace antes)
	  Grid.Remove(state, uid) -> Placed?
	  Grid.At(state, x, z) -> uid?
	  Grid.Connected(state) -> { [cellIndex]: true }  ruas ligadas à Avenida (inclui a Avenida)
	  Grid.HasAccess(state, connected, placed) -> boolean
	  Grid.Serialize(state) -> { "id,x,z,r" }
	  Grid.Deserialize(list, level) -> State        (ignora o que for inválido)
	  Grid.Center(placed) -> cx, cz                 centro do prédio em "casas" (pode ser .5)
	  Grid.LocalPosition(cx, cz) -> lx, lz          em studs, relativo à frente-centro do terreno
]]

local Shared = script.Parent
local Config = require(Shared.Config)
local Buildings = require(Shared.Buildings)

export type Placed = { Uid: number, Id: string, X: number, Z: number, R: number, W: number, D: number }
export type State = { Buildings: { [number]: Placed }, Cells: { [number]: number }, NextUid: number, Count: number }

local Grid = {}

local N = Config.GridSize
local AVENUE = Config.AvenueRow

function Grid.new(): State
	return { Buildings = {}, Cells = {}, NextUid = 1, Count = 0 }
end

function Grid.Index(x: number, z: number): number
	return (z - 1) * N + x
end

function Grid.Bounds(level: number): (number, number, number, number)
	local expansions = Config.Expansions
	local info = expansions[math.clamp(level, 1, #expansions)]
	local size = math.min(info.Size, N)
	local x1 = math.floor((N - size) / 2) + 1
	return x1, x1 + size - 1, AVENUE + 1, math.min(N, AVENUE + size)
end

function Grid.At(state: State, x: number, z: number): number?
	return state.Cells[Grid.Index(x, z)]
end

function Grid.CanPlace(state: State, level: number, def: Buildings.Building?, x: number, z: number, rot: number): (boolean, string?)
	if not def then
		return false, "Prédio desconhecido"
	end
	if type(x) ~= "number" or type(z) ~= "number" or type(rot) ~= "number" then
		return false, "Posição inválida"
	end
	if x ~= math.floor(x) or z ~= math.floor(z) or rot ~= math.floor(rot) or rot < 0 or rot > 3 then
		return false, "Posição inválida"
	end
	local w, d = Buildings.Footprint(def, rot)
	local x1, x2, z1, z2 = Grid.Bounds(level)
	if x < x1 or z < z1 or x + w - 1 > x2 or z + d - 1 > z2 then
		return false, "Fora do terreno liberado"
	end
	for dz = 0, d - 1 do
		for dx = 0, w - 1 do
			if state.Cells[Grid.Index(x + dx, z + dz)] then
				return false, "Espaço ocupado"
			end
		end
	end
	return true, nil
end

function Grid.Place(state: State, def: Buildings.Building, x: number, z: number, rot: number): number
	local w, d = Buildings.Footprint(def, rot)
	local uid = state.NextUid
	state.NextUid += 1
	state.Buildings[uid] = { Uid = uid, Id = def.Id, X = x, Z = z, R = rot, W = w, D = d }
	state.Count += 1
	for dz = 0, d - 1 do
		for dx = 0, w - 1 do
			state.Cells[Grid.Index(x + dx, z + dz)] = uid
		end
	end
	return uid
end

function Grid.Remove(state: State, uid: number): Placed?
	local placed = state.Buildings[uid]
	if not placed then
		return nil
	end
	for dz = 0, placed.D - 1 do
		for dx = 0, placed.W - 1 do
			local index = Grid.Index(placed.X + dx, placed.Z + dz)
			if state.Cells[index] == uid then
				state.Cells[index] = nil
			end
		end
	end
	state.Buildings[uid] = nil
	state.Count -= 1
	return placed
end

local function isRoad(state: State, x: number, z: number): boolean
	if z == AVENUE then
		return true
	end
	local uid = state.Cells[Grid.Index(x, z)]
	if not uid then
		return false
	end
	local placed = state.Buildings[uid]
	if not placed then
		return false
	end
	local def = Buildings.ById[placed.Id]
	return def ~= nil and def.Category == "road"
end

-- Ruas ligadas à Avenida (busca em largura a partir de toda a fileira da Avenida)
function Grid.Connected(state: State): { [number]: boolean }
	local connected: { [number]: boolean } = {}
	local queue: { number } = {}
	for x = 1, N do
		local index = Grid.Index(x, AVENUE)
		connected[index] = true
		table.insert(queue, index)
	end
	local head = 1
	while head <= #queue do
		local index = queue[head]
		head += 1
		local x = (index - 1) % N + 1
		local z = (index - 1) // N + 1
		for _, step in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local nx, nz = x + step[1], z + step[2]
			if nx >= 1 and nx <= N and nz >= 1 and nz <= N then
				local nextIndex = Grid.Index(nx, nz)
				if not connected[nextIndex] and isRoad(state, nx, nz) then
					connected[nextIndex] = true
					table.insert(queue, nextIndex)
				end
			end
		end
	end
	return connected
end

-- O prédio encosta (de lado, não na diagonal) em alguma rua ligada?
function Grid.HasAccess(_state: State, connected: { [number]: boolean }, placed: Placed): boolean
	local function check(x: number, z: number): boolean
		return x >= 1 and x <= N and z >= 1 and z <= N and connected[Grid.Index(x, z)] == true
	end
	for dx = 0, placed.W - 1 do
		if check(placed.X + dx, placed.Z - 1) or check(placed.X + dx, placed.Z + placed.D) then
			return true
		end
	end
	for dz = 0, placed.D - 1 do
		if check(placed.X - 1, placed.Z + dz) or check(placed.X + placed.W, placed.Z + dz) then
			return true
		end
	end
	return false
end

function Grid.Center(placed: Placed): (number, number)
	return placed.X + (placed.W - 1) / 2, placed.Z + (placed.D - 1) / 2
end

-- Centro de uma casa (ou de um prédio, com cx/cz fracionários) em studs, relativo à frente-centro
-- do terreno. +X vai para a direita, +Z vai da avenida para o fundo.
function Grid.LocalPosition(cx: number, cz: number): (number, number)
	local cell = Config.CellSize
	return (cx - 0.5) * cell - N * cell / 2, (cz - 0.5) * cell
end

-- Casa da grade de um ponto local (inverso de LocalPosition). Pode cair fora de 1..N.
function Grid.CellAt(lx: number, lz: number): (number, number)
	local cell = Config.CellSize
	return math.floor((lx + N * cell / 2) / cell) + 1, math.floor(lz / cell) + 1
end

function Grid.Serialize(state: State): { string }
	local uids = {}
	for uid in state.Buildings do
		table.insert(uids, uid)
	end
	table.sort(uids)
	local out = table.create(#uids)
	for _, uid in uids do
		local placed = state.Buildings[uid]
		table.insert(out, string.format("%s,%d,%d,%d", placed.Id, placed.X, placed.Z, placed.R))
	end
	return out
end

function Grid.Deserialize(list: any, level: number): State
	local state = Grid.new()
	if type(list) ~= "table" then
		return state
	end
	for _, entry in list do
		if type(entry) == "string" then
			local id, xs, zs, rs = string.match(entry, "^([%w_]+),(%-?%d+),(%-?%d+),(%d)$")
			local def = id and Buildings.ById[id]
			if def then
				local x, z, rot = tonumber(xs) :: number, tonumber(zs) :: number, tonumber(rs) :: number
				if Grid.CanPlace(state, level, def, x, z, rot) then
					Grid.Place(state, def, x, z, rot)
				end
			end
		end
	end
	return state
end

return Grid
