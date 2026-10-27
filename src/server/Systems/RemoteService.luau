--!strict
-- Creates every remote listed in Shared/Remotes.luau.
-- This must be the FIRST system, so other systems can use remotes in their start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local RemoteService = {}

function RemoteService.init()
	local folder = Instance.new("Folder")
	folder.Name = Remotes.FolderName

	for name, kind in Remotes.List do
		local remote: Instance
		if kind == "Event" then
			remote = Instance.new("RemoteEvent")
		else
			remote = Instance.new("RemoteFunction")
		end
		remote.Name = name
		remote.Parent = folder
	end

	-- Parent the folder last, so the client never sees a half-filled folder.
	folder.Parent = ReplicatedStorage
end

function RemoteService.start() end

return RemoteService
