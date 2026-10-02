--[[
	Format (ModuleScript em ReplicatedStorage > Shared)          Prefeito Tycoon
	Números e tempos em texto. PURO (sem API do Roblox): dá para testar no Lune.

	API:
	  Format.Number(n, decimals?, thousandsSep?, decimalSep?) -> "1,234" / "1.234,5"
	  Format.Int(n, thousandsSep?)  -> inteiro com separador de milhar (arredonda para baixo)
	  Format.Short(n)               -> "1.5K", "2.3M" (placas e placares com pouco espaço)
	  Format.Time(seconds)          -> "4:05" (minutos:segundos, para contagens)
	  Format.Money(n)               -> "$1.5K" (dinheiro curto)
	  Format.Percent(p)             -> "88%" (p de 0 a 100)
]]

local Format = {}

function Format.Number(n: number, decimals: number?, thousandsSep: string?, decimalSep: string?): string
	if n ~= n or n == math.huge or n == -math.huge then
		return "0"
	end
	local places = decimals or 0
	local negative = n < 0
	n = math.abs(n)
	local scale = 10 ^ places
	local scaled = math.floor(n * scale + 0.5)
	local intPart = math.floor(scaled / scale)
	local fracPart = scaled - intPart * scale
	local digits = string.format("%d", intPart)
	local sep = thousandsSep or ","
	local out = digits
	if sep ~= "" and #digits > 3 then
		local first = #digits % 3
		local pieces = {}
		if first > 0 then
			table.insert(pieces, string.sub(digits, 1, first))
		end
		for i = first + 1, #digits, 3 do
			table.insert(pieces, string.sub(digits, i, i + 2))
		end
		out = table.concat(pieces, sep)
	end
	if places > 0 then
		out ..= (decimalSep or ".") .. string.format("%0" .. places .. "d", fracPart)
	end
	if negative and scaled > 0 then
		out = "-" .. out
	end
	return out
end

function Format.Int(n: number, thousandsSep: string?): string
	if n ~= n then
		return "0"
	end
	local whole = if n >= 0 then math.floor(n) else -math.floor(-n)
	return Format.Number(whole, 0, thousandsSep)
end

local SUFFIXES = { "", "K", "M", "B", "T" }

function Format.Short(n: number): string
	if n ~= n then
		return "0"
	end
	local negative = n < 0
	n = math.floor(math.abs(n))
	local text
	if n < 1000 then
		text = tostring(n)
	else
		local index = 1
		local value = n
		while value >= 1000 and index < #SUFFIXES do
			value /= 1000
			index += 1
		end
		if value >= 100 then
			text = string.format("%d", math.floor(value + 1e-9))
		elseif value >= 10 then
			text = string.format("%.1f", math.floor(value * 10 + 1e-6) / 10)
		else
			text = string.format("%.2f", math.floor(value * 100 + 1e-6) / 100)
		end
		if string.find(text, ".", 1, true) then
			text = string.gsub(text, "0+$", "")
			text = string.gsub(text, "%.$", "")
		end
		text ..= SUFFIXES[index]
	end
	return (if negative then "-" else "") .. text
end

function Format.Time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function Format.Money(n: number): string
	return "$" .. Format.Short(n)
end

function Format.Percent(p: number): string
	if p ~= p then
		return "0%"
	end
	return string.format("%d%%", math.floor(p + 0.5))
end

return Format
