-- Format: números curtos (950, 1.2K, 3.4M, 7B) e tempo (1:05).
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qd", "Qn" }

function Format.Short(value: number): string
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
		local rounded = string.format("%.1f", math.floor(shown * 10) / 10)
		rounded = string.gsub(rounded, "%.0$", "")
		text = rounded .. SUFFIXES[index]
	end
	return (if negative then "-" else "") .. text
end

function Format.Time(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Format
