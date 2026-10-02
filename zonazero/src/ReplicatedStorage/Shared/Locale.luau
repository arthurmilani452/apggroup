-- Locale: escolhe português ou inglês pelo idioma do jogador e monta os textos.
local Players = game:GetService("Players")
local LocalizationService = game:GetService("LocalizationService")
local RunService = game:GetService("RunService")

local Strings = require(script.Parent.Strings)

local Locale = {}

local lang = "en"
if RunService:IsClient() then
	local code = ""
	pcall(function()
		code = LocalizationService.RobloxLocaleId
	end)
	if code == "" then
		local player = Players.LocalPlayer
		code = if player then player.LocaleId else ""
	end
	lang = if string.sub(string.lower(code), 1, 2) == "pt" then "pt" else "en"
end

function Locale.Language(): string
	return lang
end

function Locale.T(key: string, args: { [string]: any }?): string
	local text = Strings[lang][key] or Strings.en[key] or key
	if args then
		text = string.gsub(text, "{(%w+)}", function(name)
			local value = args[name]
			return if value ~= nil then tostring(value) else "{" .. name .. "}"
		end)
	end
	return text
end

-- Segundos em "1:05"
function Locale.Time(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Locale
