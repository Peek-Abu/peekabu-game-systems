--!strict
--[=[
	SoundServiceServer: asks clients to play a registered sound when they cannot know to themselves
	(design: docs/superpowers/specs/2026-10-09-sound-design.md). Prefer letting clients play sounds from
	state they already see; use this for server-only events (a hidden monster's growl, a round horn).

	- `playAt(position, id, radius?)` — to every player whose character is within `radius`.
	- `playFor(player, id)` / `playForAll(id)` — 2D.

	Validates the id first (an unknown id is a refusal with a reason, never a packet).

	Spec-exempt shell (Players, ByteNet); the selection rule is SoundFormulas.listenersInRange (specced).

	@class SoundServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundShared = ReplicatedStorage.Shared.Features.Sound
local SoundConstants = require(SoundShared.Data.SoundConstants)
local SoundRegistry = require(SoundShared.Data.SoundRegistry)
local SoundFormulas = require(SoundShared.Utils.SoundFormulas)
local SoundEvents = require(SoundShared.Net.SoundEvents)

local counters = { sent = 0, refused = 0 }

local function refuse(id: string): (boolean, string?)
	counters.refused += 1
	return false, `"{id}" is not a registered sound`
end

export type SoundServiceServer = {
	dependencies: { string },
	getState: (self: SoundServiceServer) -> { [string]: any },
	playAt: (self: SoundServiceServer, position: Vector3, id: string, radius: number?) -> (boolean, string?),
	playFor: (self: SoundServiceServer, player: Player, id: string) -> (boolean, string?),
	playForAll: (self: SoundServiceServer, id: string) -> (boolean, string?),
}

local SoundServiceServer: SoundServiceServer = {
	dependencies = {},

	playAt = function(_self, position, id, radius)
		if not SoundRegistry.has(id) then
			return refuse(id)
		end
		local listeners: { SoundFormulas.Listener } = {}
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
			listeners[#listeners + 1] = {
				id = player.UserId,
				position = if root ~= nil and root:IsA("BasePart") then root.Position else nil,
			}
		end
		local reach = radius or SoundConstants.DEFAULT_SERVER_RADIUS
		for _, userId in SoundFormulas.listenersInRange(position, reach, listeners) do
			local player = Players:GetPlayerByUserId(userId)
			if player ~= nil then
				SoundEvents.packets.Play.sendTo({ id = id, position = position }, player)
				counters.sent += 1
			end
		end
		return true, nil
	end,

	playFor = function(_self, player, id)
		if not SoundRegistry.has(id) then
			return refuse(id)
		end
		SoundEvents.packets.Play.sendTo({ id = id }, player)
		counters.sent += 1
		return true, nil
	end,

	playForAll = function(_self, id)
		if not SoundRegistry.has(id) then
			return refuse(id)
		end
		SoundEvents.packets.Play.sendToAll({ id = id })
		counters.sent += 1
		return true, nil
	end,

	getState = function(_self)
		return { registered = #SoundRegistry.ids(), counters = table.clone(counters) }
	end,
}

return SoundServiceServer
