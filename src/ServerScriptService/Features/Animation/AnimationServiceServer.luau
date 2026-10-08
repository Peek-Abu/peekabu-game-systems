--!strict
--[=[
	AnimationServiceServer: the server's animation surface (Phase 6 spec, Decision 5; character replication
	R3, decisions 2-7).

	- **Grants: play on a player's body.** `play(player, id, { speed?, variant? })` is THE entry point for a
	  replicated action: Cmdr `animationplay` today; combat, abilities, emotes and NPC-driven player animations
	  later. Those callers decide WHETHER and WHAT (permission, cooldowns); this decides HOW (AnimationActionGrantSystem:
	  replicable only, clamped speed, the server's variant, duration from the declared length, the layer's
	  interruption rule) and hands the grant to ReplicationServiceServer as timed body state of kind
	  "action". The owner's client and every viewer receive the same ActionStarted and play it on their rig
	  of that body: one path, no double plays. `stop` / `stopAttacks` / `stopAll` end grants early (ActionStopped).
	- **Server-owned rigs.** NPCs and world models animate server-side through `playOnRig` — consumers
	  arrive with the NPC phase; the path exists so nothing ever grows a second one.
	- **Diagnostics to one client.** `requestTrackReport` / `requestAssetProbe` (the anim-tracks and
	  anim-report read paths).

	No animation state on the charm-sync spine: grants are timed body state, not queryable state.

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
local ReplicationEvents = require(ReplicatedStorage.Shared.Features.Replication.Net.ReplicationEvents)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local CharacterReplicationServiceServer = require(ServerScriptService.Features.Replication.ReplicationServiceServer)
local ReplicationBodyStateSender = require(ServerScriptService.Features.Replication.Net.ReplicationBodyStateSender)
local AnimationActionGrantSystem = require(ServerScriptService.Features.Animation.Systems.AnimationActionGrantSystem)

type ActionData = AnimationActionGrantSystem.ActionData
type ActionChannel = ReplicationBodyStateSender.Channel<ActionData>

local log = Logger.new("AnimationService")

local actionChannel: ActionChannel? = nil
local function defaultRoll(count: number): number
	return math.random(1, count)
end
local roll: (count: number) -> number = defaultRoll
local counters = { granted = 0, refused = 0, stopped = 0 }

-- The "action" kind's packets: a grant on `key` (a layer name) of `subject`'s body, to `target`.
local actionSenders: ReplicationBodyStateSender.Senders<ActionData> = {
	started = function(target, subject, epoch, key, data, startMs, durationMs)
		local layer = AnimationTypes.layerIndex(key)
		if layer == nil then
			return
		end
		ReplicationEvents.packets.ActionStarted.sendTo({
			userId = subject.UserId,
			epoch = epoch,
			layer = layer,
			wireId = data.wireId,
			variant = data.variant,
			speedMilli = data.speedMilli,
			startMs = startMs,
			durationMs = durationMs,
		}, target)
	end,
	stopped = function(target, subject, epoch, key, startMs)
		local layer = AnimationTypes.layerIndex(key)
		if layer == nil then
			return
		end
		ReplicationEvents.packets.ActionStopped.sendTo({
			userId = subject.UserId,
			epoch = epoch,
			layer = layer,
			startMs = startMs,
		}, target)
	end,
}

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

	-- Test seams (specs only): a fake channel instead of the replication service's, a fixed roll.
	_setActionChannel: (self: AnimationServiceServer, channel: ActionChannel?) -> ActionChannel?,
	_setRoll: (self: AnimationServiceServer, nextRoll: ((count: number) -> number)?) -> (),
}

local AnimationServiceServer: AnimationServiceServer = {
	dependencies = { "ReplicationServiceServer" },

	--[=[
		Defines the "action" body-state kind (a cross-service call, so at start, not init).
	]=]
	start = function(_self)
		if actionChannel == nil then
			actionChannel = CharacterReplicationServiceServer:defineBodyState("action", actionSenders)
		end
	end,

	--[=[
		Grants a replicated action on `player`'s body. False and a reason when refused: unknown or
		non-replicable id, bad speed or variant, a protected action holding the layer, no live body.
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
		local result =
			channel:set(player, grant.layer, grant.data, CharacterReplicationServiceServer:nowMs(), grant.durationMs)
		if result == "no-body" then
			return refuse(`{player.Name} has no body`)
		elseif result == "full" then
			return refuse(`{player.Name} already holds the maximum number of body states`)
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
		Ends EVERY action grant on `player`'s body, whatever its class (Stopped goes to the owner and every
		viewer). The hook Death and Ragdoll call when they take the body over. Returns how many ended.
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

	-- Grant counters for the F4 Services tab (body-state counts live on the replication service).
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
