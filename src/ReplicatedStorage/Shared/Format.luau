-- Formata números: 1500 -> "1.5K", 2300000 -> "2.3M"
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

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
	return (negative and "-" or "") .. text
end

function Format.Money(n: number): string
	return "$" .. Format.Short(n)
end

function Format.Time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Format
