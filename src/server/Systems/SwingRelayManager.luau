--!strict
-- Tells everyone when a player swings an axe or saws with the Chainsaw, so every computer can
-- move that player's arms (see Client/Controllers/ToolAnimController). Only for looks: the
-- hits themselves go through SwingAtTree and TreeManager.
--
-- Why a remote? Arms moved by code only move on the computer that moves them, so the player
-- who swings has to tell the others. The client sends no numbers: the server looks up which
-- tool the player really holds, and ignores swings that come faster than the tool allows.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ToolManager = require(script.Parent.ToolManager)

local SwingRelayManager = {}

local lastSwing: { [Player]: number } = {}
local swungRemote: RemoteEvent

local function onSwing(player: Player)
	local toolId = ToolManager.getEquippedId(player)
	if not (Config.ChopAnims[toolId] or Config.SawAnims[toolId]) then
		return
	end
	local now = os.clock()
	local gap = Config.Tools[toolId].Cooldown * Config.Anticheat.CooldownTolerance
	if now - (lastSwing[player] or -math.huge) < gap then
		return
	end
	lastSwing[player] = now
	for _, other in Players:GetPlayers() do
		if other ~= player then
			swungRemote:FireClient(other, player, toolId)
		end
	end
end

function SwingRelayManager.init()
	swungRemote = Remotes.getEvent("ToolSwung")
end

function SwingRelayManager.start()
	Remotes.getEvent("SwingTool").OnServerEvent:Connect(onSwing)
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
	end)
end

return SwingRelayManager
