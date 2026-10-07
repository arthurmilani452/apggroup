-- Format: números curtos (950, 1.2K, 3.4M, 7B... até 1e63, depois notação 1.2e70) e tempo (1:05).
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg" }

function Format.Short(value: number): string
	if value ~= value then
		return "0"
	end
	local negative = value < 0
	value = math.abs(value)
	if value == math.huge then
		return (if negative then "-" else "") .. "∞"
	end
	local text
	if value < 1000 then
		text = tostring(math.floor(value + 0.5))
	else
		local index = math.floor(math.log10(value) / 3) + 1
		if index > #SUFFIXES then
			local exponent = math.floor(math.log10(value))
			text = string.format("%.2fe%d", value / 10 ^ exponent, exponent)
		else
			local shown = value / 10 ^ ((index - 1) * 3)
			if shown >= 999.5 and index < #SUFFIXES then
				shown = 1
				index += 1
			end
			if shown >= 100 then
				text = string.format("%d%s", math.floor(shown), SUFFIXES[index])
			elseif shown >= 10 then
				local rounded = string.format("%.1f", math.floor(shown * 10) / 10)
				text = string.gsub(rounded, "%.0$", "") .. SUFFIXES[index]
			else
				local rounded = string.format("%.2f", math.floor(shown * 100) / 100)
				rounded = string.gsub(rounded, "0$", "")
				rounded = string.gsub(rounded, "%.0?$", "")
				text = rounded .. SUFFIXES[index]
			end
		end
	end
	return (if negative then "-" else "") .. text
end

-- Multiplicador: x1.5, x12, x3.4K
function Format.Mult(value: number): string
	if value < 10 then
		local text = string.format("%.2f", value)
		text = string.gsub(text, "0$", "")
		text = string.gsub(text, "%.0?$", "")
		return "x" .. text
	end
	return "x" .. Format.Short(value)
end

function Format.Time(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Format
