-- Format: números de dinheiro curtos ($950, $1.2K, $3.4M).
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T" }

function Format.Money(value: number): string
	value = math.floor(value + 0.5)
	local negative = value < 0
	value = math.abs(value)
	local index = 1
	local shown = value
	while shown >= 1000 and index < #SUFFIXES do
		shown /= 1000
		index += 1
	end
	local text
	if index == 1 then
		text = tostring(shown)
	elseif shown >= 100 then
		text = string.format("%d%s", math.floor(shown), SUFFIXES[index])
	else
		text = string.format("%.1f", math.floor(shown * 10) / 10):gsub("%.0$", "") .. SUFFIXES[index]
	end
	return (if negative then "-$" else "$") .. text
end

function Format.Stars(rep: number): string
	return string.format("%.1f", math.floor(rep * 10) / 10)
end

return Format
