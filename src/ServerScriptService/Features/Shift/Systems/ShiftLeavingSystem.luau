--!strict
--[=[
	ShiftLeavingSystem: the load screen in the place being left (P1, owner 2026-11-14: "loadscreen should also appear in
	the hub / world you are teleporting FROM"). Runs on every server, the hub and the shift place alike.

	The moment Queue decides a teleport (QueueServiceServer.leaving: a truck departing, Back to depot, training's ride
	home, a redirect), each player in it is told (ShiftEvents.Leaving with ShiftLeavingRules.view: the trip's route
	slip, or the welcome card on the way home), and the client puts that card up and locks its own input
	(the client's ShiftTransitSystem). The server holds the character still too: its HumanoidRootPart is anchored, so
	nobody walks off however their client behaves. When Queue gives up on a player (QueueServiceServer.stayed, after its
	retries), they are told the trip failed and their root gets back the Anchored it had, so they can play on.

	Spec-exempt shell (Queue signals, ByteNet, characters); what the card says is the specced ShiftLeavingRules and the
	wire format the specced ShiftTransitUtils.

	@class ShiftLeavingSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ShiftEvents = require(ReplicatedStorage.Shared.Features.Shift.Net.ShiftEvents)
local ShiftTransitUtils = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftTransitUtils)
local QueueServiceServer = require(ServerScriptService.Features.Queue.QueueServiceServer)
local ShiftLeavingRules = require(ServerScriptService.Features.Shift.Rules.ShiftLeavingRules)

-- Per leaving player: the root anchored and whether it was anchored before (restored if the trip fails).
type Held = { root: BasePart?, wasAnchored: boolean }

local ShiftLeavingSystem = {}

-- The players leaving right now.
local held: { [Player]: Held } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local function hold(player: Player)
	if held[player] ~= nil then
		return
	end
	local root = rootOf(player)
	held[player] = { root = root, wasAnchored = root ~= nil and root.Anchored }
	if root ~= nil then
		root.Anchored = true
	end
end

local function release(player: Player)
	local entry = held[player]
	held[player] = nil
	local root = if entry ~= nil then entry.root else nil
	-- Only the same root, still in the world: a respawned character is free already.
	if entry ~= nil and root ~= nil and root.Parent ~= nil and root == rootOf(player) then
		root.Anchored = entry.wasAnchored
	end
end

-- Starts following Queue's teleports; returns the stopper.
function ShiftLeavingSystem.start(): () -> ()
	local leaving = QueueServiceServer.leaving:Connect(function(players, role, payload)
		local packet = ShiftTransitUtils.leavingPacket(ShiftLeavingRules.view(role, payload))
		for _, player in players do
			if player.Parent == Players then
				hold(player)
				ShiftEvents.packets.Leaving.sendTo(packet, player)
			end
		end
	end)
	local stayed = QueueServiceServer.stayed:Connect(function(players, _reason)
		local packet = ShiftTransitUtils.leavingPacket(nil)
		for _, player in players do
			release(player)
			if player.Parent == Players then
				ShiftEvents.packets.Leaving.sendTo(packet, player)
			end
		end
	end)
	local removing = Players.PlayerRemoving:Connect(function(player)
		held[player] = nil
	end)
	return function()
		leaving:Disconnect()
		stayed:Disconnect()
		removing:Disconnect()
		for player in held do
			release(player)
		end
	end
end

-- How many players are leaving right now.
function ShiftLeavingSystem.count(): number
	local count = 0
	for _ in held do
		count += 1
	end
	return count
end

return ShiftLeavingSystem
