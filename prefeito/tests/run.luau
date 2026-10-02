--[[
	Testes dos módulos PUROS (sem Roblox) com o Lune:   lune run prefeito/tests/run
	(rode da pasta /home/user/apggroup)

	Como funciona: monta uma "árvore falsa" parecida com a do Roblox a partir de prefeito/src
	(pasta = Folder, X.luau = ModuleScript, pasta com init.luau = ModuleScript com filhos) e
	carrega cada módulo com `script` e `require(instância)` do jeito do Roblox.
	Só funciona com módulos que não chamam serviços do Roblox ao serem carregados
	(Config, Buildings, Grid, CityMath, Format).

	Cada arquivo *_spec.luau desta pasta devolve uma função(ctx) onde:
	  ctx.require(caminho)   -- ex.: ctx.require("ReplicatedStorage/Shared/Rng")
	  ctx.check(cond, msg)   -- falha o teste com a mensagem
	  ctx.eq(a, b, msg)
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local ROOT = "prefeito/src"
local TESTS = "prefeito/tests"

type Node = { Name: string, Path: string, Kind: string, Children: { Node }, Parent: Node? }

local nodeMeta = {}

local function makeNode(name: string, path: string, kind: string, parent: Node?): Node
	local node = setmetatable({ Name = name, Path = path, Kind = kind, Children = {}, Parent = parent }, nodeMeta)
	return node :: any
end

local function scan(dir: string, parent: Node): ()
	for _, entry in fs.readDir(dir) do
		local full = dir .. "/" .. entry
		if fs.isDir(full) then
			local initPath = full .. "/init.luau"
			local node = makeNode(entry, if fs.isFile(initPath) then initPath else full, if fs.isFile(initPath) then "ModuleScript" else "Folder", parent)
			table.insert(parent.Children, node)
			scan(full, node)
		elseif entry ~= "init.luau" and string.sub(entry, -5) == ".luau" then
			local base = string.sub(entry, 1, -6)
			local kind = "ModuleScript"
			if string.sub(base, -7) == ".server" then
				kind = "Script"
				base = string.sub(base, 1, -8)
			elseif string.sub(base, -7) == ".client" then
				kind = "LocalScript"
				base = string.sub(base, 1, -8)
			end
			table.insert(parent.Children, makeNode(base, full, kind, parent))
		end
	end
end

local function findChild(node: Node, name: string): Node?
	for _, child in node.Children do
		if child.Name == name then
			return child
		end
	end
	return nil
end

nodeMeta.__index = function(node: any, key: string)
	local method = ({
		FindFirstChild = function(self, name)
			return findChild(self, name)
		end,
		WaitForChild = function(self, name)
			local child = findChild(self, name)
			if not child then
				error("WaitForChild: " .. name .. " não existe em " .. self.Path)
			end
			return child
		end,
		GetChildren = function(self)
			return table.clone(self.Children)
		end,
		IsA = function(self, className)
			return self.Kind == className
		end,
		GetFullName = function(self)
			return self.Path
		end,
	})[key]
	if method then
		return method
	end
	if key == "ClassName" then
		return rawget(node, "Kind")
	end
	local child = findChild(node, key)
	if child then
		return child
	end
	error(("'%s' não é filho de %s"):format(tostring(key), rawget(node, "Path")))
end

local root = makeNode("game", ROOT, "DataModel", nil)
scan(ROOT, root)

local cache: { [any]: any } = {}
local loading: { [any]: boolean } = {}

local fakeGame = {}
function fakeGame:GetService(name: string)
	local node = findChild(root, name)
	if node then
		return node
	end
	error("GetService(" .. name .. ") não existe no teste (módulo não é puro)")
end

local function requireNode(node: Node): any
	if cache[node] ~= nil then
		return cache[node]
	end
	if node.Kind ~= "ModuleScript" then
		error("require de algo que não é ModuleScript: " .. node.Path)
	end
	if loading[node] then
		error("require circular: " .. node.Path)
	end
	loading[node] = true
	local source = fs.readFile(node.Path)
	local env = setmetatable({
		script = node,
		game = fakeGame,
		require = function(target)
			if type(target) == "table" and getmetatable(target) == nodeMeta then
				return requireNode(target)
			end
			error("require no teste só aceita instâncias da árvore: " .. tostring(target))
		end,
		warn = function(...)
			print("[warn]", ...)
		end,
		-- tipos do Roblox do Lune: módulos que montam Instances (ex.: BuildingModels) também rodam aqui
		Instance = roblox.Instance,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Enum = roblox.Enum,
		NumberRange = roblox.NumberRange,
		NumberSequence = roblox.NumberSequence,
		ColorSequence = roblox.ColorSequence,
	}, { __index = _G })
	local chunk = luau.load(source, { debugName = node.Path, environment = env })
	local result = chunk()
	loading[node] = nil
	cache[node] = result
	return result
end

local function requirePath(path: string): any
	local node = root
	for part in string.gmatch(path, "[^/]+") do
		local child = findChild(node, part)
		if not child then
			error("caminho não encontrado: " .. path)
		end
		node = child
	end
	return requireNode(node)
end

-- roda os specs
local failures = 0
local passes = 0
local only = process.args[1]
for _, entry in fs.readDir(TESTS) do
	if string.sub(entry, -10) == "_spec.luau" and (only == nil or string.find(entry, only, 1, true)) then
		local ctx = {}
		local errors = {}
		ctx.require = requirePath
		ctx.roblox = roblox
		function ctx.check(cond: any, msg: string?)
			if not cond then
				table.insert(errors, msg or "falhou")
			end
		end
		function ctx.eq(a: any, b: any, msg: string?)
			if a ~= b then
				table.insert(errors, ("%s: esperado %s, veio %s"):format(msg or "eq", tostring(b), tostring(a)))
			end
		end
		local spec = luau.load(fs.readFile(TESTS .. "/" .. entry), { debugName = entry })()
		local ok, err = pcall(spec, ctx)
		if not ok then
			table.insert(errors, "erro: " .. tostring(err))
		end
		if #errors == 0 then
			passes += 1
			print("OK   " .. entry)
		else
			failures += 1
			print("FAIL " .. entry)
			for i = 1, math.min(#errors, 20) do
				print("     - " .. errors[i])
			end
		end
	end
end
print(("%d ok, %d falharam"):format(passes, failures))
process.exit(if failures > 0 then 1 else 0)
