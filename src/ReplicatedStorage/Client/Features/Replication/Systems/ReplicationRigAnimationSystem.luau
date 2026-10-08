--!strict
--[=[
	ReplicationRigAnimationSystem: animates the rigs this client shows (character replication R3). The owner's rig and every
	puppet go through the same per-Animator AnimationPlayerSystem the rest of the game uses.

	- Actions: server-granted, through ReplicationActionTracker, on the owner rig and every puppet alike.
	- Puppet locomotion: each puppet gets its own AnimationLocomotionSystem (the owner's code path, with the §6.8
	  stride-rate clamp), fed by ReplicationPuppetLocomotionSystem from the movement state ReplicationRemoteBodyTracker interpolated for the
	  frame. The owner's own locomotion stays with AnimationLocomotionHumanoidSystem (Humanoid signals). The
	  `LocomotionEnabled` kill switch reaches puppets too.
	- Puppet LOD (ReplicationAnimationRules): a puppet off screen or far away is FROZEN: its tracks are held (pause mode
	  "speed": every track at speed 0; "detach": its Animator unparented, chosen by the R3 Task 9
	  measurement) and its locomotion is not stepped; its position still updates. Unfreezing resumes
	  locomotion and re-plays running actions at their current point. The Workspace attribute
	  `PuppetLodEnabled = false` keeps every puppet full (the LOD-off measurement).

	- `start` connects `ActionStarted` / `ActionStopped` (ByteNet listeners cannot be disconnected, so they
	  route through `active`).
	- The client service reports what it learns about bodies: slot-table rows (`slotEntry`: the epoch of
	  every body, the owner's included; a released slot), a body leaving range (`bodyLeft`), a puppet
	  acquired or released (`attachPuppet` / `detachPuppet`), the owner rig built or dropped
	  (`attachOwner` / `detachOwner`).
	- `frame` runs in the client service's PreRender pass, right after puppet placement: each placed puppet's
	  locomotion is stepped from the same interpolated moment its placement came from, pending actions
	  start, finished ones drop, length-check warnings reach the log, and drift is sampled at 4 Hz.

	Clocks: the owner plays at the session clock; a puppet at its render time (session clock minus the
	render delay), so its actions line up with the motion the viewer draws.

	Spec-exempt shell (ByteNet, Instances, the camera); the rules live in ReplicationActionTracker, ReplicationPuppetLocomotionSystem,
	AnimationLocomotionSystem and ReplicationAnimationRules.

	@class ReplicationRigAnimationSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AnimationShared = ReplicatedStorage.Shared.Features.Animation
local ReplicationClient = ReplicatedStorage.Client.Features.Replication
local AnimationPlayerSystem = require(AnimationShared.Systems.AnimationPlayerSystem)
local AnimationPlayerEngineSystem = require(AnimationShared.Systems.AnimationPlayerEngineSystem)
local AnimationRegistry = require(AnimationShared.Data.AnimationRegistry)
local AnimationTypes = require(AnimationShared.Data.AnimationTypes)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local ReplicationEvents = require(ReplicatedStorage.Shared.Features.Replication.Net.ReplicationEvents)
local AnimationLocomotionSystem = require(ReplicatedStorage.Client.Features.Animation.Systems.AnimationLocomotionSystem)
local ReplicationActionTracker = require(ReplicationClient.State.ReplicationActionTracker)
local ReplicationPuppetLocomotionSystem = require(ReplicationClient.Systems.ReplicationPuppetLocomotionSystem)
local ReplicationAnimationRules = require(ReplicationClient.Rules.ReplicationAnimationRules)
local ReplicationPuppetPool = require(ReplicationClient.State.ReplicationPuppetPool)
local ReplicationRemoteBodyTracker = require(ReplicationClient.State.ReplicationRemoteBodyTracker)

local DRIFT_SAMPLE_SECONDS = 0.25
local LOCOMOTION_ENABLED_ATTRIBUTE = "LocomotionEnabled"
local LOD_ENABLED_ATTRIBUTE = "PuppetLodEnabled"
-- How a frozen puppet holds its pose, chosen by the R3 Task 9 measurement (40 rigs, animation step median:
-- playing 0.331 ms, speed 0 0.325 ms, Animator detached 0.214 ms = all tracks stopped 0.220 ms; both held the
-- pose): "speed" = every track at speed 0 (AnimationPlayerSystem:setPaused); "detach" = the puppet's Animator
-- unparented while frozen. Speed 0 saves nothing (the engine still evaluates paused tracks), so "detach".
local LOD_PAUSE_MODE: "speed" | "detach" = "detach"
local LOD_CONFIG = ReplicationAnimationRules.DEFAULT_CONFIG

type PuppetRig = {
	puppet: ReplicationPuppetPool.Puppet,
	player: AnimationPlayerSystem.AnimationPlayerSystem,
	slot: number,
	epoch: number,
	locomotion: AnimationLocomotionSystem.AnimationLocomotionSystem,
	tracker: ReplicationPuppetLocomotionSystem.Tracker,
	tier: ReplicationAnimationRules.Tier,
	nextLodAt: number,
}

-- What F4 shows (the client service's `getState` composes it under `animation`).
export type State = {
	actionsHeld: number,
	actionsPlaying: number,
	lod: { full: number, frozen: number, pauseMode: string },
	actions: ReplicationActionTracker.Counters,
}

local log = Logger.new("ReplicationRigAnimationSystem")

local active = false
local listening = false
local sessionNowMs: () -> number? = function(): number?
	return nil
end
local renderDelayMs: () -> number = function(): number
	return 0
end
local puppets: { [number]: PuppetRig } = {} -- by userId
local ownerSeq = 0
local nextDriftAt = 0
local killSwitchConnection: RBXScriptConnection? = nil

local function locomotionEnabled(): boolean
	return Workspace:GetAttribute(LOCOMOTION_ENABLED_ATTRIBUTE) ~= false
end

local function newLocomotion(
	player: AnimationPlayerSystem.AnimationPlayerSystem
): AnimationLocomotionSystem.AnimationLocomotionSystem
	local locomotion = AnimationLocomotionSystem.new(player, {
		minRate = ReplicationPuppetLocomotionSystem.MIN_RATE,
		maxRate = ReplicationPuppetLocomotionSystem.MAX_RATE,
	})
	locomotion:setEnabled(locomotionEnabled())
	return locomotion
end

-- A pose's first play must be a cache hit (Phase 6 decision 6); a pooled puppet keeps its cache.
local function warmLocomotion(player: AnimationPlayerSystem.AnimationPlayerSystem)
	local domain = AnimationRegistry.domain("locomotion")
	if domain == nil then
		return
	end
	for id in domain do
		player:warm(id)
	end
end

local function resolveWire(wireId: number): (string?, AnimationTypes.AnimationDef?)
	local id = AnimationRegistry.idForWire(wireId)
	if id == nil then
		return nil, nil
	end
	return id, AnimationRegistry.get(id)
end

-- The owner plays at the session clock; a puppet at its render time. Before the session: never yet.
local function clockFor(userId: number): number
	local nowMs = sessionNowMs()
	if nowMs == nil then
		return -math.huge
	end
	if userId == Players.LocalPlayer.UserId then
		return nowMs
	end
	return nowMs - renderDelayMs()
end

local actions = ReplicationActionTracker.new(resolveWire, clockFor)

local ReplicationRigAnimationSystem = {}

function ReplicationRigAnimationSystem.start(sessionClock: () -> number?, renderDelay: () -> number)
	sessionNowMs = sessionClock
	renderDelayMs = renderDelay
	active = true
	if killSwitchConnection == nil then
		killSwitchConnection = Workspace:GetAttributeChangedSignal(LOCOMOTION_ENABLED_ATTRIBUTE):Connect(function()
			local enabled = locomotionEnabled()
			for _, rig in puppets do
				-- A frozen puppet's Animator may be unparented: unfreezing rebuilds its locomotion from the
				-- switch's state then.
				if rig.tier ~= "frozen" then
					rig.locomotion:setEnabled(enabled)
					-- Events were swallowed while off but recorded as sent: re-send the current one next frame.
					ReplicationPuppetLocomotionSystem.reset(rig.tracker)
				end
			end
		end)
	end
	if listening then
		return
	end
	listening = true
	local packets = ReplicationEvents.packets
	packets.ActionStarted.listen(function(data)
		if active then
			ReplicationActionTracker.started(actions, data)
		end
	end)
	packets.ActionStopped.listen(function(data)
		if active then
			ReplicationActionTracker.stopped(actions, data)
		end
	end)
end

function ReplicationRigAnimationSystem.stop()
	active = false
	local connection = killSwitchConnection
	if connection ~= nil then
		connection:Disconnect()
		killSwitchConnection = nil
	end
	for userId in puppets do
		ReplicationRigAnimationSystem.detachPuppet(userId)
	end
	ReplicationRigAnimationSystem.detachOwner()
	table.clear(actions.bodies)
end

--[=[
	A slot-table row: every active row carries its body's epoch (the owner's own row included, so its
	actions for a new epoch are accepted even before its rig is rebuilt); a released or replaced slot
	forgets the body that held it.
]=]
function ReplicationRigAnimationSystem.slotEntry(
	entry: ReplicationRemoteBodyTracker.SlotEntry,
	change: ReplicationRemoteBodyTracker.SlotChange?,
	previous: ReplicationRemoteBodyTracker.Body?
)
	if (change == "released" or change == "replaced") and previous ~= nil then
		ReplicationActionTracker.remove(actions, previous.userId)
	end
	if entry.active then
		ReplicationActionTracker.resetBody(actions, entry.userId, entry.epoch)
	end
end

-- The body left this viewer's range: the server replays its actions on the next Enter.
function ReplicationRigAnimationSystem.bodyLeft(userId: number)
	ReplicationActionTracker.forget(actions, userId)
end

function ReplicationRigAnimationSystem.attachPuppet(
	userId: number,
	slot: number,
	epoch: number,
	puppet: ReplicationPuppetPool.Puppet
)
	if puppets[userId] ~= nil then
		ReplicationRigAnimationSystem.detachPuppet(userId)
	end
	local player = AnimationPlayerEngineSystem.forAnimator(puppet.animator)
	warmLocomotion(player)
	puppets[userId] = {
		puppet = puppet,
		player = player,
		slot = slot,
		epoch = epoch,
		locomotion = newLocomotion(player),
		tracker = ReplicationPuppetLocomotionSystem.new(),
		tier = "full",
		nextLodAt = ReplicationAnimationRules.nextCheckAt(os.clock(), LOD_CONFIG.rateHz, math.random()),
	}
	ReplicationActionTracker.attach(actions, userId, epoch, player)
end

-- Freeze (hold every track, stop stepping locomotion) or unfreeze (resume, re-send the current locomotion
-- event, re-play running actions at their current point).
local function setFrozen(userId: number, rig: PuppetRig, frozen: boolean)
	rig.tier = if frozen then "frozen" else "full"
	if LOD_PAUSE_MODE == "speed" then
		rig.player:setPaused(frozen)
	else
		rig.puppet.animator.Parent = if frozen then nil else rig.puppet.humanoid
	end
	if not frozen then
		-- A fresh animator re-plays the current pose, whatever the engine did with the held tracks.
		rig.locomotion:destroy()
		rig.locomotion = newLocomotion(rig.player)
		ReplicationPuppetLocomotionSystem.reset(rig.tracker)
	end
	ReplicationActionTracker.setLive(actions, userId, not frozen)
end

-- The puppet goes back to the pool: every track on it stops (a pooled puppet shows nothing).
function ReplicationRigAnimationSystem.detachPuppet(userId: number)
	local rig = puppets[userId]
	if rig == nil then
		return
	end
	puppets[userId] = nil
	if rig.tier == "frozen" then
		-- Undo only the pause (a pooled puppet goes back whole: Animator attached, tracks unpaused): no
		-- re-play of its actions and no locomotion rebuild, both are about to be torn down.
		if LOD_PAUSE_MODE == "speed" then
			rig.player:setPaused(false)
		else
			rig.puppet.animator.Parent = rig.puppet.humanoid
		end
		rig.tier = "full"
	end
	rig.locomotion:destroy()
	rig.player:stopAll(0)
	-- The player is memoised per Animator and reused by the puppet's next body: it must not stay LOD-frozen.
	rig.player:setPaused(false)
	ReplicationActionTracker.detach(actions, userId)
end

-- The owner rig is built. Resolving its Animator may yield, so attach in a thread; a newer rig wins.
function ReplicationRigAnimationSystem.attachOwner(model: Model, epoch: number)
	ownerSeq += 1
	local mine = ownerSeq
	task.spawn(function()
		local player = AnimationPlayerEngineSystem.forCharacter(model)
		if mine ~= ownerSeq then
			return
		end
		if player == nil then
			log:warn("the owner rig has no Animator; actions will not play on it")
			return
		end
		ReplicationActionTracker.attachOwner(actions, Players.LocalPlayer.UserId, epoch, player)
	end)
end

function ReplicationRigAnimationSystem.detachOwner()
	ownerSeq += 1
	ReplicationActionTracker.detach(actions, Players.LocalPlayer.UserId)
end

-- One placed puppet's locomotion for this frame. A new body epoch (a respawn) gets a fresh animator: death
-- latches the old one.
local function stepLocomotion(rig: PuppetRig, body: ReplicationRemoteBodyTracker.Body, now: number)
	if body.epoch ~= rig.epoch then
		rig.locomotion:destroy()
		rig.locomotion = newLocomotion(rig.player)
		ReplicationPuppetLocomotionSystem.reset(rig.tracker)
		rig.epoch = body.epoch
	end
	-- Annotated: Luau widens a singleton-union return to `string` on an unannotated local.
	local event: AnimationLocomotionSystem.LocomotionEvent?, speed =
		ReplicationPuppetLocomotionSystem.step(rig.tracker, body.motionState, body.motionVelocity)
	if event ~= nil then
		rig.locomotion:handleEvent(event, speed, now)
	end
	rig.locomotion:update(now)
end

-- Re-evaluates one puppet's LOD tier when its check is due.
local function updateLod(userId: number, rig: PuppetRig, camera: Camera?, lodOn: boolean, now: number)
	if now < rig.nextLodAt then
		return
	end
	rig.nextLodAt = ReplicationAnimationRules.nextCheckAt(now, LOD_CONFIG.rateHz)
	local tier: ReplicationAnimationRules.Tier = "full"
	if lodOn and camera ~= nil then
		local position = rig.puppet.root.Position
		local viewport = camera:WorldToViewportPoint(position)
		local onScreen = ReplicationAnimationRules.isOnScreen(viewport, camera.ViewportSize, LOD_CONFIG.edgeMarginPx)
		local distance = (camera.CFrame.Position - position).Magnitude
		tier = ReplicationAnimationRules.decide(rig.tier, distance, onScreen, LOD_CONFIG)
	end
	if tier ~= rig.tier then
		setFrozen(userId, rig, tier == "frozen")
	end
end

--[=[
	Once per rendered frame, after puppet placement. `bodies` is ReplicationRemoteBodyTracker' table (by slot); `placed`
	marks the slots placed this frame (a puppet whose buffer a respawn just emptied is not).
]=]
function ReplicationRigAnimationSystem.frame(
	bodies: { [number]: ReplicationRemoteBodyTracker.Body },
	placed: { [number]: boolean }
)
	if not active then
		return
	end
	local now = os.clock()
	local camera = Workspace.CurrentCamera
	local lodOn = Workspace:GetAttribute(LOD_ENABLED_ATTRIBUTE) ~= false
	for userId, rig in puppets do
		local body = bodies[rig.slot]
		if body ~= nil and placed[rig.slot] then
			updateLod(userId, rig, camera, lodOn, now)
			if rig.tier == "full" then
				stepLocomotion(rig, body, now)
			end
		end
	end
	ReplicationActionTracker.step(actions)
	if #actions.warnings > 0 then
		for _, warning in actions.warnings do
			log:warn(`length check: {warning}`)
		end
		table.clear(actions.warnings)
	end
	if now >= nextDriftAt then
		nextDriftAt = now + DRIFT_SAMPLE_SECONDS
		ReplicationActionTracker.sampleDrift(actions)
	end
end

function ReplicationRigAnimationSystem.getState(): State
	local held, playing = ReplicationActionTracker.counts(actions)
	local full, frozen = 0, 0
	for _, rig in puppets do
		if rig.tier == "full" then
			full += 1
		else
			frozen += 1
		end
	end
	return {
		actionsHeld = held,
		actionsPlaying = playing,
		lod = { full = full, frozen = frozen, pauseMode = LOD_PAUSE_MODE },
		actions = table.clone(actions.counters),
	}
end

return ReplicationRigAnimationSystem
