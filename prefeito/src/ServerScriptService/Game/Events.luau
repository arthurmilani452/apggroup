--[[
	Events (ModuleScript em ServerScriptService > Game)          Prefeito Tycoon
	Eventos globais: a cada Config.EventEvery segundos um evento vale para todas as cidades por
	Config.EventDuration segundos. O cliente lê os atributos de ReplicatedStorage:
	  Event (Id ou ""), EventName, EventText, EventEnds (os.time), NextEvent (os.time)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(script.Parent.Remotes)

local Events = {}

local current: any = nil
local lastId = ""

function Events.Current(): any
	return current
end

local function setAttributes(event: any, ends: number, nextAt: number)
	ReplicatedStorage:SetAttribute("Event", if event then event.Id else "")
	ReplicatedStorage:SetAttribute("EventName", if event then event.Name else "")
	ReplicatedStorage:SetAttribute("EventText", if event then event.Text else "")
	ReplicatedStorage:SetAttribute("EventEnds", ends)
	ReplicatedStorage:SetAttribute("NextEvent", nextAt)
end

function Events.Start(id: string): boolean
	for _, event in Config.Events do
		if event.Id == id then
			current = event
			lastId = id
			local ends = os.time() + Config.EventDuration
			setAttributes(event, ends, ends + Config.EventEvery)
			Remotes.NotifyAll(event.Name .. "! " .. event.Text, "evento")
			return true
		end
	end
	return false
end

function Events.Stop()
	if current then
		Remotes.NotifyAll(current.Name .. " acabou.", "info")
	end
	current = nil
	setAttributes(nil, 0, os.time() + Config.EventEvery)
end

function Events.Init()
	setAttributes(nil, 0, os.time() + Config.EventEvery)
	task.spawn(function()
		while true do
			task.wait(Config.EventEvery)
			local options = {}
			for _, event in Config.Events do
				if event.Id ~= lastId then
					table.insert(options, event)
				end
			end
			if #options > 0 then
				Events.Start(options[math.random(1, #options)].Id)
				task.wait(Config.EventDuration)
				Events.Stop()
			end
		end
	end)
end

return Events
