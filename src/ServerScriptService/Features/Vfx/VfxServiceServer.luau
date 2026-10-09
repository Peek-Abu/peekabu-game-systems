--!strict
--[=[
	VfxServiceServer: asks clients to play VFX they cannot know about themselves, and owns the shared
	atmosphere (design: docs/superpowers/specs/2026-10-09-vfx-design.md).

	- `playAt(cframe, id, radius?)` — a recipe for every player within `radius`.
	- `playForAll(cframe, id)` — a recipe for everyone.
	- `setAtmosphere(id?, fade?)` — every client blends to a preset (nil = the place's own Lighting);
	  players who join later get the current one.

	Validates ids first (an unknown id is a refusal with a reason, never a packet).

	Spec-exempt shell (Players, ByteNet); listener selection reuses the specced
	SoundFormulas.listenersInRange.

	@class VfxServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VfxShared = ReplicatedStorage.Shared.Features.Vfx
local VfxConstants = require(VfxShared.Data.VfxConstants)
local VfxRecipeRegistry = require(VfxShared.Data.VfxRecipeRegistry)
local VfxAtmosphereRegistry = require(VfxShared.Data.VfxAtmosphereRegistry)
local VfxEvents = require(VfxShared.Net.VfxEvents)
local SoundFormulas = require(ReplicatedStorage.Shared.Features.Sound.Utils.SoundFormulas)

local currentAtmosphere: string? = nil
local counters = { sent = 0, refused = 0 }
local joinConnection: RBXScriptConnection? = nil

export type VfxServiceServer = {
	dependencies: { string },
	start: (self: VfxServiceServer) -> (),
	stop: (self: VfxServiceServer) -> (),
	getState: (self: VfxServiceServer) -> { [string]: any },
	playAt: (self: VfxServiceServer, cframe: CFrame, id: string, radius: number?) -> (boolean, string?),
	playForAll: (self: VfxServiceServer, cframe: CFrame, id: string) -> (boolean, string?),
	setAtmosphere: (self: VfxServiceServer, id: string?, fade: number?) -> (boolean, string?),
}

local VfxServiceServer: VfxServiceServer = {
	dependencies = {},

	--[=[
		Sends the current atmosphere (if any) to each player who joins, so late joiners match everyone.
	]=]
	start = function(_self)
		joinConnection = Players.PlayerAdded:Connect(function(player)
			local id = currentAtmosphere
			if id ~= nil then
				VfxEvents.packets.SetAtmosphere.sendTo({ id = id, fade = 0 }, player)
			end
		end)
	end,

	stop = function(_self)
		local connection = joinConnection
		if connection ~= nil then
			connection:Disconnect()
			joinConnection = nil
		end
	end,

	playAt = function(_self, cframe, id, radius)
		if not VfxRecipeRegistry.has(id) then
			counters.refused += 1
			return false, `"{id}" is not a registered vfx recipe`
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
		local reach = radius or VfxConstants.DEFAULT_SERVER_RADIUS
		for _, userId in SoundFormulas.listenersInRange(cframe.Position, reach, listeners) do
			local player = Players:GetPlayerByUserId(userId)
			if player ~= nil then
				VfxEvents.packets.PlayRecipe.sendTo({ id = id, cframe = cframe }, player)
				counters.sent += 1
			end
		end
		return true, nil
	end,

	playForAll = function(_self, cframe, id)
		if not VfxRecipeRegistry.has(id) then
			counters.refused += 1
			return false, `"{id}" is not a registered vfx recipe`
		end
		VfxEvents.packets.PlayRecipe.sendToAll({ id = id, cframe = cframe })
		counters.sent += 1
		return true, nil
	end,

	setAtmosphere = function(_self, id, fade)
		if id ~= nil and not VfxAtmosphereRegistry.has(id) then
			counters.refused += 1
			return false, `"{id}" is not a registered atmosphere`
		end
		currentAtmosphere = id
		VfxEvents.packets.SetAtmosphere.sendToAll({ id = id, fade = fade or VfxConstants.DEFAULT_ATMOSPHERE_FADE })
		counters.sent += 1
		return true, nil
	end,

	getState = function(_self)
		return { atmosphere = currentAtmosphere or "base", counters = table.clone(counters) }
	end,
}

return VfxServiceServer
