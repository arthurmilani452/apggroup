--[[
	Rng (ModuleScript em ReplicatedStorage > Shared)            dono: foundation
	Gerador de números aleatórios DETERMINÍSTICO (PCG32, variante XSH-RR), em Luau puro.
	  • Mesma seed = mesma sequência, no Roblox e no Lune (sem API do Roblox, sem Random.new).
	  • Usado pelo FacilityCore (mapa), Ordens de Serviço do dia, sorteio de sucata etc.
	  • O estado de 64 bits é guardado em 4 "pedaços" de 16 bits para as contas caberem
	    exatamente num número do Luau (double, 53 bits).

	API:
	  Rng.new(seed: number, stream: number?) -> rng
	  rng:NextU32()            -> inteiro em [0, 2^32)
	  rng:NextFloat()          -> número em [0, 1)
	  rng:NextInt(min, max)    -> inteiro em [min, max] (inclusivo)
	  rng:NextNumber(min, max) -> número em [min, max)
	  rng:Chance(p)            -> true com probabilidade p
	  rng:Pick(list)           -> um elemento da lista (nil se vazia)
	  rng:Shuffle(list)        -> embaralha a lista no lugar (Fisher-Yates) e devolve a lista
	  rng:WeightedPick(list, weightOf?) -> (elemento, índice); weightOf(item) -> peso (padrão item.Weight)
	  rng:Clone()              -> cópia com o mesmo estado
	  Rng.Hash(text: string)   -> inteiro u32 (FNV-1a), para transformar texto em seed
]]

local Rng = {}
Rng.__index = Rng

local TWO16 = 65536
local TWO32 = 4294967296

-- multiplicador do PCG32: 6364136223846793005 = 0x5851F42D4C957F2D (em pedaços de 16 bits, do menor para o maior)
local MUL = { 0x7F2D, 0x4C95, 0xF42D, 0x5851 }

export type Rng = typeof(setmetatable(
	{} :: { s: { number }, inc: { number } },
	Rng
))

-- 64 bits (4 pedaços de 16) a partir de um número inteiro não negativo (até 2^53)
local function fromNumber(n: number): { number }
	n = math.floor(math.abs(n)) % (2 ^ 53)
	local lo = n % TWO32
	local hi = math.floor(n / TWO32) % TWO32
	return { lo % TWO16, math.floor(lo / TWO16), hi % TWO16, math.floor(hi / TWO16) }
end

-- a * b mod 2^64
local function mul64(a: { number }, b: { number }): { number }
	local r0 = a[1] * b[1]
	local r1 = a[1] * b[2] + a[2] * b[1]
	local r2 = a[1] * b[3] + a[2] * b[2] + a[3] * b[1]
	local r3 = a[1] * b[4] + a[2] * b[3] + a[3] * b[2] + a[4] * b[1]
	local carry = math.floor(r0 / TWO16)
	r0 %= TWO16
	r1 += carry
	carry = math.floor(r1 / TWO16)
	r1 %= TWO16
	r2 += carry
	carry = math.floor(r2 / TWO16)
	r2 %= TWO16
	r3 = (r3 + carry) % TWO16
	return { r0, r1, r2, r3 }
end

-- a + b mod 2^64
local function add64(a: { number }, b: { number }): { number }
	local out = table.create(4, 0)
	local carry = 0
	for i = 1, 4 do
		local v = a[i] + b[i] + carry
		out[i] = v % TWO16
		carry = math.floor(v / TWO16)
	end
	return out
end

-- avança o estado: state = state * MUL + inc
local function step(self)
	self.s = add64(mul64(self.s, MUL), self.inc)
end

-- saída XSH-RR a partir do estado antigo (hi/lo de 32 bits)
local function output(old: { number }): number
	local lo = old[2] * TWO16 + old[1]
	local hi = old[4] * TWO16 + old[3]
	-- t = old >> 18
	local tLo = bit32.bor(bit32.rshift(lo, 18), bit32.lshift(hi, 14))
	local tHi = bit32.rshift(hi, 18)
	-- u = t xor old
	local uLo = bit32.bxor(tLo, lo)
	local uHi = bit32.bxor(tHi, hi)
	-- x = (u >> 27) truncado para 32 bits
	local x = bit32.bor(bit32.rshift(uLo, 27), bit32.lshift(uHi, 5))
	local rot = bit32.rshift(hi, 27)
	return bit32.rrotate(x, rot)
end

function Rng.new(seed: number, stream: number?): Rng
	local self = setmetatable({ s = { 0, 0, 0, 0 }, inc = { 0, 0, 0, 0 } }, Rng)
	-- inc = (stream << 1) | 1 (sempre ímpar)
	local seq = math.floor(math.abs(stream or 54)) % (2 ^ 52)
	self.inc = fromNumber(seq * 2 + 1)
	step(self)
	self.s = add64(self.s, fromNumber(seed))
	step(self)
	return self
end

function Rng:NextU32(): number
	local old = self.s
	step(self)
	return output(old)
end

function Rng:NextFloat(): number
	-- 53 bits de precisão: dois sorteios de 32 bits (27 + 26 bits)
	local a = bit32.rshift(self:NextU32(), 5)
	local b = bit32.rshift(self:NextU32(), 6)
	return (a * 67108864 + b) / 9007199254740992
end

function Rng:NextInt(min: number, max: number): number
	if max < min then
		min, max = max, min
	end
	return min + math.floor(self:NextFloat() * (max - min + 1))
end

function Rng:NextNumber(min: number, max: number): number
	return min + self:NextFloat() * (max - min)
end

function Rng:Chance(p: number): boolean
	return self:NextFloat() < p
end

function Rng:Pick<T>(list: { T }): T?
	local n = #list
	if n == 0 then
		return nil
	end
	return list[self:NextInt(1, n)]
end

function Rng:Shuffle<T>(list: { T }): { T }
	for i = #list, 2, -1 do
		local j = self:NextInt(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

function Rng:WeightedPick(list: { any }, weightOf: ((any) -> number)?): (any, number?)
	local total = 0
	for _, item in list do
		local w = if weightOf then weightOf(item) else (item.Weight or 1)
		if w > 0 then
			total += w
		end
	end
	if total <= 0 then
		return nil, nil
	end
	local roll = self:NextFloat() * total
	for index, item in list do
		local w = if weightOf then weightOf(item) else (item.Weight or 1)
		if w > 0 then
			roll -= w
			if roll < 0 then
				return item, index
			end
		end
	end
	-- arredondamento: devolve o último com peso
	for index = #list, 1, -1 do
		local item = list[index]
		local w = if weightOf then weightOf(item) else (item.Weight or 1)
		if w > 0 then
			return item, index
		end
	end
	return nil, nil
end

function Rng:Clone(): Rng
	local copy = setmetatable({ s = table.clone(self.s), inc = table.clone(self.inc) }, Rng)
	return copy
end

-- FNV-1a de 32 bits (texto -> seed)
function Rng.Hash(text: string): number
	local hash = 2166136261
	for i = 1, #text do
		hash = bit32.bxor(hash, string.byte(text, i))
		-- hash * 16777619 mod 2^32, em duas partes para não perder precisão
		local lo = bit32.band(hash, 0xFFFF)
		local hi = bit32.rshift(hash, 16)
		hash = (lo * 16777619 + bit32.lshift((hi * 16777619) % TWO16, 16)) % TWO32
	end
	return hash
end

return Rng
