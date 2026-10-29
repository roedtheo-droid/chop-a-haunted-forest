--!strict
-- Small helpers that turn numbers into text, shared by the server and the client.

local Format = {}

-- A whole number with commas between every three digits: 1353 -> "1,353".
function Format.number(value: number): string
	local digits = tostring(math.floor(math.abs(value)))
	local withCommas = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if withCommas:sub(1, 1) == "," then
		withCommas = withCommas:sub(2)
	end
	return if value < 0 then `-{withCommas}` else withCommas
end

return table.freeze(Format)
