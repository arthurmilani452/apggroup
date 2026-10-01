--[[
	Signal (ModuleScript em ReplicatedStorage > Shared)          dono: foundation
	"Evento" simples entre módulos do mesmo lado (servidor com servidor, cliente com cliente),
	sem BindableEvent (não copia tabelas, não perde metatables).
	Cada ouvinte roda no próprio task.spawn: se um ouvinte der erro, os outros continuam.

	API:
	  local sig = Signal.new()
	  local conn = sig:Connect(function(...) end)   -- conn:Disconnect()
	  sig:Once(function(...) end)
	  sig:Fire(...)
	  sig:Wait() -> ...                             -- espera o próximo Fire (dentro de uma thread)
	  sig:DisconnectAll()
]]

local Signal = {}
Signal.__index = Signal

export type Connection = { Connected: boolean, Disconnect: (self: Connection) -> () }

local Connection = {}
Connection.__index = Connection

function Connection:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false
	local list = self._signal._handlers
	local index = table.find(list, self)
	if index then
		table.remove(list, index)
	end
end

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn: (...any) -> ())
	local conn = setmetatable({ Connected = true, _fn = fn, _signal = self }, Connection)
	table.insert(self._handlers, conn)
	return conn
end

function Signal:Once(fn: (...any) -> ())
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end

function Signal:Fire(...: any)
	-- cópia: um ouvinte pode desconectar outro durante o Fire
	for _, conn in table.clone(self._handlers) do
		if conn.Connected then
			task.spawn(conn._fn, ...)
		end
	end
end

function Signal:Wait(): ...any
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:DisconnectAll()
	for _, conn in table.clone(self._handlers) do
		conn:Disconnect()
	end
end

return Signal
