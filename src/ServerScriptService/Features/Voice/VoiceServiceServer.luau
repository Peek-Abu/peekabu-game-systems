--!strict
--[=[
	VoiceServiceServer: one microphone input per player and the server-enforced voice routing (design:
	docs/superpowers/specs/2026-10-09-voice-design.md).

	- Each player gets an `AudioDeviceInput` named `VoiceInput` (`.Player` set, parented to the Player): the
	  engine streams their microphone into it and it replicates to every client, which wires what it may
	  hear (VoiceServiceClient).
	- Audibility is enforced here: every speaker's input is `AccessType = Allow` with an access list of the
	  listeners VoiceRoutingRules lets hear them (the living never hear the dead; radio channels). Lists are
	  re-checked every ACCESS_INTERVAL and written only when they change.
	- `setRadio` publishes the public `radio` field; `setMuted` mutes a player's input for everyone.

	Spec-exempt shell (Players, audio Instances); the routing is the specced VoiceRoutingRules.

	@class VoiceServiceServer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Observers = require(ReplicatedStorage.Packages.Observers)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local DeathConstants = require(ReplicatedStorage.Shared.Features.Death.Data.DeathConstants)
local VoiceConstants = require(ReplicatedStorage.Shared.Features.Voice.Data.VoiceConstants)
local VoiceTypes = require(ReplicatedStorage.Shared.Features.Voice.Data.VoiceTypes)
local VoiceRoutingRules = require(ReplicatedStorage.Shared.Features.Voice.Rules.VoiceRoutingRules)
local StateSyncPublicPlayerStore = require(ServerScriptService.Features.StateSync.State.StateSyncPublicPlayerStore)

local log = Logger.new("VoiceServiceServer")

-- Optional values so a lookup can be compared with nil (Instance types cannot be, otherwise).
local inputs: { [number]: AudioDeviceInput? } = {}
-- The access list last written per speaker, as a comparable string.
local written: { [number]: string } = {}
local stoppers: { () -> () } = {}
local running = false

local function infoOf(userId: number): VoiceTypes.VoiceInfo
	return VoiceRoutingRules.infoFrom(
		StateSyncPublicPlayerStore.get(userId),
		DeathConstants.PUBLIC_FIELD,
		VoiceConstants.RADIO_FIELD
	)
end

-- Rewrites the access list of every speaker whose allowed listeners changed.
local function syncAccess()
	local infos: { [number]: VoiceTypes.VoiceInfo } = {}
	for userId in inputs do
		infos[userId] = infoOf(userId)
	end
	for userId, input in inputs do
		if input == nil then
			continue
		end
		local listeners = VoiceRoutingRules.listenersOf(userId, infos, VoiceConstants.DEAD_HEAR_LIVING)
		local key = table.concat(listeners, ",")
		if written[userId] ~= key then
			written[userId] = key
			local ok, err = pcall(function()
				input:SetUserIdAccessList(listeners)
			end)
			if not ok then
				log:warn(`could not set the voice access list for {userId}: {err}`)
			end
		end
	end
end

local function addInput(player: Player)
	if inputs[player.UserId] ~= nil then
		return
	end
	local input = Instance.new("AudioDeviceInput")
	input.Name = VoiceConstants.INPUT_NAME
	input.Player = player
	-- Nobody hears anyone until syncAccess allows them.
	input.AccessType = Enum.AccessModifierType.Allow
	input.Parent = player
	inputs[player.UserId] = input
	written[player.UserId] = nil
end

export type VoiceServiceServer = {
	dependencies: { string },
	start: (self: VoiceServiceServer) -> (),
	stop: (self: VoiceServiceServer) -> (),
	getState: (self: VoiceServiceServer) -> { [string]: any },
	setRadio: (self: VoiceServiceServer, player: Player, channel: string?) -> (),
	radioOf: (self: VoiceServiceServer, player: Player) -> string?,
	setMuted: (self: VoiceServiceServer, player: Player, muted: boolean) -> (),
}

local VoiceServiceServer: VoiceServiceServer = {
	dependencies = { "StateSyncServiceServer" },

	start = function(_self)
		table.insert(
			stoppers,
			Observers.observePlayer(function(player: Player)
				addInput(player)
				return function()
					inputs[player.UserId] = nil
					written[player.UserId] = nil
				end
			end)
		)
		running = true
		task.spawn(function()
			while running do
				syncAccess()
				task.wait(VoiceConstants.ACCESS_INTERVAL)
			end
		end)
	end,

	stop = function(_self)
		running = false
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
		for _, input in inputs do
			if input ~= nil then
				input:Destroy()
			end
		end
		table.clear(inputs)
		table.clear(written)
	end,

	--[=[
		Puts a player on a radio channel (nil takes them off). Living players on the same channel hear each
		other at any range.
	]=]
	setRadio = function(_self, player, channel)
		if channel == nil then
			StateSyncPublicPlayerStore.clearField(player.UserId, VoiceConstants.RADIO_FIELD)
		else
			StateSyncPublicPlayerStore.set(player.UserId, { [VoiceConstants.RADIO_FIELD] = channel })
		end
		syncAccess()
	end,

	radioOf = function(_self, player)
		return infoOf(player.UserId).radio
	end,

	--[=[
		Mutes (or unmutes) a player's microphone for everyone.
	]=]
	setMuted = function(_self, player, muted)
		local input = inputs[player.UserId]
		if input ~= nil then
			input.Muted = muted
		end
	end,

	getState = function(_self)
		local count = 0
		for _ in inputs do
			count += 1
		end
		return { inputs = count, accessLists = table.clone(written) }
	end,
}

return VoiceServiceServer
