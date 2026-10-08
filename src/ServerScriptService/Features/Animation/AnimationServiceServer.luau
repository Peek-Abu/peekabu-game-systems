--!strict
--[=[
	AnimationServiceServer: the server's animation surface.

	- **Grants: play on a player's character.** `play(player, id, { speed?, variant? })` is THE entry point
	  for a server-decided action: Cmdr `animationplay` today; combat, abilities and emotes later. Those
	  callers decide WHETHER and WHAT (permission, cooldowns); this decides HOW (AnimationActionGrantSystem:
	  replicable entries only, clamped speed, the server's variant, duration from the declared length, the
	  layer's interruption rule) and sends ONE packet to the owning client, which plays it on its
	  character. Roblox replicates the owner's character animations to every other client, so there is no
	  second path and no double play. `stop` / `stopAttacks` / `stopAll` end grants early.
	- **Server-owned rigs.** NPCs and world models animate server-side through `playOnRig`.
	- **Diagnostics to one client.** `requestTrackReport` / `requestAssetProbe` (the anim-tracks and
	  anim-report read paths).

	No animation state on the charm-sync spine: what is playing is the owner client's business; the server
	only remembers what it granted (AnimationGrantTracker) to enforce the interruption rule.

	@class AnimationServiceServer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AnimationShared = ReplicatedStorage.Shared.Features.Animation
local AnimationEvents = require(AnimationShared.Net.AnimationEvents)
local AnimationPlayerSystem = require(AnimationShared.Systems.AnimationPlayerSystem)
local AnimationPlayerEngineSystem = require(AnimationShared.Systems.AnimationPlayerEngineSystem)
local AnimationRegistry = require(AnimationShared.Data.AnimationRegistry)
local AnimationTypes = require(AnimationShared.Data.AnimationTypes)
local Observers = require(ReplicatedStorage.Packages.Observers)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local AnimationGrantTracker = require(ServerScriptService.Features.Animation.State.AnimationGrantTracker)
local AnimationActionGrantSystem = require(ServerScriptService.Features.Animation.Systems.AnimationActionGrantSystem)

type ActionData = AnimationActionGrantSystem.ActionData
-- What the grant surface needs from its record of live grants: AnimationGrantTracker in the game, a fake in
-- the spec (the `_setActionChannel` seam).
export type ActionChannel = AnimationGrantTracker.Tracker<ActionData>

local log = Logger.new("AnimationService")

local actionChannel: ActionChannel? = nil
local function defaultRoll(count: number): number
	return math.random(1, count)
end
local roll: (count: number) -> number = defaultRoll
local counters = { granted = 0, refused = 0, stopped = 0 }

-- The session clock grants are stamped and expired against, in milliseconds.
local function nowMs(): number
	return math.floor(os.clock() * 1000)
end

-- The packets to the owning client: a grant on `key` (a layer name) of the player's own character.
local actionSenders: AnimationGrantTracker.Senders<ActionData> = {
	started = function(player, key, data, _durationMs)
		local layer = AnimationTypes.layerIndex(key)
		if layer == nil then
			return
		end
		AnimationEvents.packets.ActionStarted.sendTo({
			layer = layer,
			wireId = data.wireId,
			variant = data.variant,
			speedMilli = data.speedMilli,
		}, player)
	end,
	stopped = function(player, key)
		local layer = AnimationTypes.layerIndex(key)
		if layer == nil then
			return
		end
		AnimationEvents.packets.ActionStopped.sendTo({ layer = layer }, player)
	end,
}

local function hasCharacter(player: Player): boolean
	return player.Character ~= nil
end

local function refuse(reason: string): (boolean, string?)
	counters.refused += 1
	return false, reason
end

export type AnimationServiceServer = {
	dependencies: { string },
	start: (self: AnimationServiceServer) -> (),

	play: (
		self: AnimationServiceServer,
		player: Player,
		id: string,
		options: AnimationActionGrantSystem.Options?
	) -> (boolean, string?),
	stop: (self: AnimationServiceServer, player: Player, idOrLayer: string) -> (boolean, string?),
	stopAttacks: (self: AnimationServiceServer, player: Player) -> number,
	stopAll: (self: AnimationServiceServer, player: Player) -> number,
	validateStopClass: (self: AnimationServiceServer, class: string) -> boolean,
	requestTrackReport: (self: AnimationServiceServer, player: Player) -> (),
	requestAssetProbe: (self: AnimationServiceServer, player: Player) -> (),

	playOnRig: (
		self: AnimationServiceServer,
		rig: Model,
		id: string,
		opts: AnimationPlayerSystem.PlayOpts?
	) -> (AnimationPlayerSystem.PlayHandle?, string?),
	getState: (self: AnimationServiceServer) -> { [string]: any },

	-- Test seams (specs only): a fake channel instead of the AnimationGrantTracker, a fixed roll.
	_setActionChannel: (self: AnimationServiceServer, channel: ActionChannel?) -> ActionChannel?,
	_setRoll: (self: AnimationServiceServer, nextRoll: ((count: number) -> number)?) -> (),
}

local AnimationServiceServer: AnimationServiceServer = {
	dependencies = {},

	--[=[
		Builds the grant record, and forgets a player's grants when their character is replaced (its
		tracks died with it) or they leave.
	]=]
	start = function(_self)
		if actionChannel == nil then
			local tracker = AnimationGrantTracker.new(actionSenders, nowMs, hasCharacter)
			actionChannel = tracker
			-- The cleanup runs when the character is removed (respawn) or the player leaves.
			Observers.observeCharacter(function(player)
				return function()
					tracker:forget(player)
				end
			end)
		end
	end,

	--[=[
		Grants an action on `player`'s character. False and a reason when refused: unknown or
		non-replicable id, bad speed or variant, a protected action holding the layer, no character.
	]=]
	play = function(_self, player, id, options)
		local grant, reason = AnimationActionGrantSystem.decide(id, AnimationRegistry.get(id), options, roll)
		if grant == nil then
			return refuse(reason or "refused")
		end
		local channel = actionChannel
		if channel == nil then
			return refuse("actions are not ready (the service has not started)")
		end
		local current = channel:get(player, grant.layer)
		if
			current ~= nil
			and not AnimationActionGrantSystem.canReplace(AnimationRegistry.get(current.data.id), grant.def)
		then
			return refuse(`the {grant.layer} layer is held by protected "{current.data.id}"`)
		end
		local result = channel:set(player, grant.layer, grant.data, nowMs(), grant.durationMs)
		if result == "no-body" then
			return refuse(`{player.Name} has no character`)
		end
		counters.granted += 1
		return true, nil
	end,

	--[=[
		Ends a grant early: by layer name ("full" / "upper" / "overlay"), or by action id (only while that id
		holds its layer).
	]=]
	stop = function(_self, player, idOrLayer)
		local channel = actionChannel
		if channel == nil then
			return false, "actions are not ready (the service has not started)"
		end
		local layer: AnimationTypes.AnimationLayer? = AnimationTypes.layerNamed(idOrLayer)
		if layer == nil then
			local def = AnimationRegistry.get(idOrLayer)
			if def == nil or def.layer == nil then
				return false, `"{idOrLayer}" is neither a layer nor a replicable action`
			end
			local current = channel:get(player, def.layer)
			if current == nil or current.data.id ~= idOrLayer then
				return false, `"{idOrLayer}" is not playing on {player.Name}`
			end
			layer = def.layer
		end
		if layer == nil or not channel:clear(player, layer) then
			return false, `nothing is playing on {player.Name}'s {idOrLayer} layer`
		end
		counters.stopped += 1
		return true, nil
	end,

	--[=[
		The stop-attacks verb: ends every grant whose action is `attack`-class. Returns how many ended.
	]=]
	stopAttacks = function(_self, player)
		local channel = actionChannel
		if channel == nil then
			return 0
		end
		local stopped = 0
		for _, layer in AnimationTypes.ANIMATION_LAYERS do
			local current = channel:get(player, layer)
			local def = if current ~= nil then AnimationRegistry.get(current.data.id) else nil
			if def ~= nil and def.interruption == "attack" and channel:clear(player, layer) then
				stopped += 1
			end
		end
		counters.stopped += stopped
		return stopped
	end,

	--[=[
		Ends EVERY action grant on `player`'s character, whatever its class. The hook a death or ragdoll
		system calls when it takes the character over. Returns how many ended.
	]=]
	stopAll = function(_self, player)
		local channel = actionChannel
		if channel == nil then
			return 0
		end
		local stopped = 0
		for _, layer in AnimationTypes.ANIMATION_LAYERS do
			if channel:clear(player, layer) then
				stopped += 1
			end
		end
		counters.stopped += stopped
		return stopped
	end,

	--[=[
		Whether `class` is bulk-stoppable. Only `attack` is: `protected` is protected by definition, and
		`ambient` dying to a combat verb is the old bug class the declared model exists to kill.
	]=]
	validateStopClass = function(_self, class)
		return AnimationTypes.isInterruptionClass(class) and class == "attack"
	end,

	--[=[
		Asks the client to log its live animation bookkeeping (playback state lives on the client).
	]=]
	requestTrackReport = function(_self, player)
		AnimationEvents.packets.ReportTracks.sendTo(true, player)
	end,

	--[=[
		Asks the client to probe every registry asset id and log failures (PreloadAsync only means
		anything on a client).
	]=]
	requestAssetProbe = function(_self, player)
		AnimationEvents.packets.ProbeAssets.sendTo(true, player)
	end,

	--[=[
		Plays on a server-owned rig (NPC/world model) through the shared runtime. The NPC phase's
		entry point; nothing else should grow a second server playback path.
	]=]
	playOnRig = function(_self, rig, id, opts)
		local player = AnimationPlayerEngineSystem.forCharacter(rig)
		if player == nil then
			log:warn(`playOnRig: no Animator found on "{rig.Name}"`)
			return nil, "no-animator"
		end
		return player:play(id, opts)
	end,

	-- Grant counters for the F4 Services tab.
	getState = function(_self)
		return table.clone(counters)
	end,

	-- Returns the channel it replaced, so a spec can restore it.
	_setActionChannel = function(_self, channel)
		local previous = actionChannel
		actionChannel = channel
		return previous
	end,

	_setRoll = function(_self, nextRoll)
		roll = nextRoll or defaultRoll
	end,
}

return AnimationServiceServer
