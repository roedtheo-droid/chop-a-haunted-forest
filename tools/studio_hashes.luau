--!strict
-- Run this inside Roblox Studio (Edit mode, e.g. in the Command Bar or with Claude's
-- execute_luau tool). It prints one line per script: "<path> <hash> <length>".
-- Compare the result with `python tools/repo_hashes.py` to see which scripts in Studio
-- are different from the files in src/. The hash is 32-bit FNV-1a, same as the Python side.

local function fnv1a(s: string): number
	local x = 2166136261
	for i = 1, #s do
		x = bit32.bxor(x, string.byte(s, i))
		-- x * 16777619 mod 2^32, split up so the number never gets too big to be exact
		x = (bit32.lshift(x, 24) + x * 403) % 4294967296
	end
	return x
end

local roots: { Instance } = {
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"),
	game:GetService("ServerScriptService"):WaitForChild("Server"),
	(game:GetService("StarterPlayer") :: any).StarterPlayerScripts:WaitForChild("Client"),
}

local lines: { string } = {}
for _, root in roots do
	local list = root:GetDescendants()
	table.insert(list, root)
	for _, inst in list do
		if inst:IsA("LuaSourceContainer") then
			local source: string = (inst :: any).Source
			table.insert(lines, `{inst:GetFullName()} {string.format("%d", fnv1a(source))} {#source}`)
		end
	end
end
table.sort(lines)
local result = table.concat(lines, "\n")
print(result)
return result
