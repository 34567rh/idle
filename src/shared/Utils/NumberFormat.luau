--!strict

local NumberFormat = {}
local suffixes = { "", "K", "M", "B", "T", "Qa" }

function NumberFormat.Compact(value: number): string
	if value ~= value or math.abs(value) == math.huge then
		return "0"
	end
	local index = 1
	while math.abs(value) >= 1000 and index < #suffixes do
		value /= 1000
		index += 1
	end
	return if index == 1
		then string.format("%d", math.floor(value))
		else string.format("%.2f%s", value, suffixes[index])
end

return NumberFormat
