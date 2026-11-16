--!strict
--[=[
	OccupantBrainSystem: the monster's brain shell (split out of OccupantServiceServer, which keeps his life and the
	developer seams; both share OccupantRunTracker.run). Each think it gathers his senses (OccupantSenseSystem: the crew
	with one line-of-sight ray each, the noise he heard, the world, the pacing and the random rolls), opens the doors on
	his line of travel first (the door beat), hands everything to the pure OccupantBrainRules, stores the mind, shows his
	tells and a speech bubble per cue (`show`), carries out the effects (OccupantEffectSystem), fires `escaped` for a
	hider he stopped tracking, and returns the NPC intent (`brain`). Also: his speeds and hearing for the tier and crew
	(`applyTuning`), Hide's witness (`witness`), the catch (`onCatch`, the brain's catch effect:
	OccupantCatchSystem.attempt), the per-frame watch during a slow turn (`watch`) and the noises he hears (`onNoise`).

	Spec-exempt shell (Instances, raycasts, Players, signals); the decisions are the specced OccupantBrainRules,
	OccupantCatchRules, OccupantTuningFormulas and OccupantTellRules.

	@class OccupantBrainSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantShared = ReplicatedStorage.Shared.Features.Occupant
local OccupantServer = ServerScriptService.Features.Occupant
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local NoiseRules = require(ReplicatedStorage.Shared.Features.Noise.Rules.NoiseRules)
local NoiseTypes = require(ReplicatedStorage.Shared.Features.Noise.Data.NoiseTypes)
local OccupantConstants = require(OccupantShared.Data.OccupantConstants)
local OccupantKindRegistry = require(OccupantShared.Data.OccupantKindRegistry)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local OccupantTypes = require(OccupantShared.Data.OccupantTypes)
local OccupantTellRules = require(OccupantShared.Rules.OccupantTellRules)
local OccupantFeedbackUtils = require(OccupantShared.Utils.OccupantFeedbackUtils)
local NpcRegistry = require(ServerScriptService.Features.Npc.Data.NpcRegistry)
local NpcTypes = require(ServerScriptService.Features.Npc.Data.NpcTypes)
local OccupantAlertRules = require(OccupantServer.Rules.OccupantAlertRules)
local OccupantBrainRules = require(OccupantServer.Rules.OccupantBrainRules)
local OccupantDoorRules = require(OccupantServer.Rules.OccupantDoorRules)
local OccupantEscapeRules = require(OccupantServer.Rules.OccupantEscapeRules)
local OccupantTurnRules = require(OccupantServer.Rules.OccupantTurnRules)
local OccupantStageRules = require(OccupantServer.Rules.OccupantStageRules)
local OccupantRunTracker = require(OccupantServer.State.OccupantRunTracker)
local OccupantStageSystem = require(OccupantServer.Systems.OccupantStageSystem)
local Sense = require(OccupantServer.Systems.OccupantSenseSystem)
local OccupantTuningFormulas = require(OccupantServer.Utils.OccupantTuningFormulas)
local OccupantRigSystem = require(OccupantServer.Systems.OccupantRigSystem)
local OccupantCatchSystem = require(OccupantServer.Systems.OccupantCatchSystem)
local OccupantEffectSystem = require(OccupantServer.Systems.OccupantEffectSystem)
local OccupantSeatSystem = require(OccupantServer.Systems.OccupantSeatSystem)
local OccupantWatchSystem = require(OccupantServer.Systems.OccupantWatchSystem)
local DeathServiceServer = require(ServerScriptService.Features.Death.DeathServiceServer)
local HideServiceServer = require(ServerScriptService.Features.Hide.HideServiceServer)
local NoiseServiceServer = require(ServerScriptService.Features.Noise.NoiseServiceServer)
local NpcServiceServer = require(ServerScriptService.Features.Npc.NpcServiceServer)
local OfficeServiceServer = require(ServerScriptService.Features.Office.OfficeServiceServer)
local RoundServiceServer = require(ServerScriptService.Features.Round.RoundServiceServer)
local ShiftServiceServer = require(ServerScriptService.Features.Shift.ShiftServiceServer)

-- The service's own log name, so its lines read as before the split.
local log = Logger.new("OccupantServiceServer")

local run = OccupantRunTracker.run
-- Random rolls per think (Senses.rolls; 5 and 6 pick the slow turns, behaviours design §11.1).
local ROLLS = 6
local lastLine: string? = nil
-- A player he stopped chasing or staring down while they were still hidden (OccupantEscapeRules): the Hide and
-- Squeak badge.
local escaped: SignalTyped.Signal<Player> = SignalTyped.new()

local OccupantBrainSystem = {}

local function resting(): boolean
	local state = run.shift
	return state ~= nil and state.stage == "break"
end

-- Speeds and hearing for the current tier and crew size.
local function applyTuning()
	local current = run.rig
	local state = run.shift
	if current == nil or state == nil then
		return
	end
	local tuning = OccupantTuningFormulas.tuning(
		state.tier,
		#RoundServiceServer:participants(),
		ShiftServiceServer:isTraining(),
		OccupantKindRegistry.get(run.currentKind)
	)
	NpcServiceServer:setTuning(current.model, { walkSpeed = tuning.walkSpeed, runSpeed = tuning.runSpeed })
	NoiseServiceServer:setHearingScale(tuning.hearing)
end

-- What he shows, and a line for a cue (in the running kind's voice; a kind with none, Bramble, never says one).
local function show(current: OccupantRigSystem.Rig, nextMind: OccupantTypes.Mind, cue: OccupantTypes.Cue?)
	OccupantRigSystem.present(current, OccupantTellRules.view(nextMind, os.clock()))
	local voice = OccupantKindRegistry.voiceOf(run.currentKind)
	if voice == nil or cue == nil then
		return
	end
	local variants = voice.lines[cue]
	local line = if variants ~= nil
		then OccupantFeedbackUtils.pickLine(variants, run.rng:NextNumber(), lastLine)
		else nil
	line = line or voice.fallback[cue]
	if line ~= nil then
		lastLine = line
		OccupantRigSystem.say(current, line)
	end
end

-- Every crew member he could see this think, each with one line-of-sight ray from his head, and whether they hide
-- (and he saw them go in).
local function eligible(player: Player): boolean
	return not DeathServiceServer:isDead(player) and not OccupantCatchSystem.isCatching(player.UserId)
end

-- Whether a crew member is concealed from him (NpcServiceServer's stealth, e.g. a Potted Plant he did not see begin).
local function concealedFrom(current: OccupantRigSystem.Rig): (userId: number) -> boolean
	return function(userId: number): boolean
		local player = Players:GetPlayerByUserId(userId)
		return player ~= nil and NpcServiceServer:isConcealedFrom(player, current.model)
	end
end

local function glimpses(current: OccupantRigSystem.Rig, sightRange: number): { OccupantTypes.Glimpse }
	return Sense.markHidden(
		Sense.glimpses(current, sightRange, RoundServiceServer:participants(), eligible),
		concealedFrom(current)
	)
end

local function world(): Sense.World
	return Sense.world(run.place, resting())
end

-- Hide's witness: whether he sees `player` right now as they go into a spot (or is chasing them). Never yields.
local function witness(player: Player): boolean
	local current, currentMind = run.rig, run.mind
	local def = NpcRegistry.get(OccupantConstants.NPC_KIND)
	return current ~= nil
		and currentMind ~= nil
		and def ~= nil
		and Sense.witness(current, currentMind, def, world(), player)
end

local catchHooks: OccupantCatchSystem.Hooks = {
	stillOn = function(): boolean
		local state = run.shift
		return run.rig ~= nil and state ~= nil and state.phase == "running"
	end,
	spendLife = function(player: Player): boolean
		return ShiftServiceServer:spendLife(player)
	end,
	-- The running kind picks the caught player's first-catch tip.
	onCaught = function(player: Player, knockedOut: boolean)
		OccupantCatchSystem.caught(player, knockedOut, run.currentKind)
	end,
}

-- Catches `player` if the server's re-check allows (OccupantCatchSystem.attempt); `from` is the mind of the think that
-- asked (a catch from a sit-in or a stare keeps its pose); `found`: a hider he found at their spot (the brain's catch
-- effect), not a chase grab. Never yields.
local function catchPlayer(player: Player, from: OccupantTypes.Mind?, found: boolean)
	local current = run.rig
	local before = run.mind
	local state = run.shift
	if current == nil or before == nil or state == nil then
		return
	end
	local now = os.clock()
	local graceUntil = before.grace[player.UserId]
	local sight = glimpses(current, math.huge)
	local ok, reason = OccupantCatchSystem.attempt(current, player, {
		inGrace = graceUntil ~= nil and now < graceUntil,
		resting = state.stage == "break",
		zone = world().zone,
		-- A player he found in a hiding spot is in plain view to him (he knows where they are).
		inView = Sense.inView(sight, player.UserId),
		glassed = Sense.glassed(sight, player.UserId),
		found = found,
	}, catchHooks)
	if not ok then
		log:debug(`catch of {player.Name} refused: {reason or "?"}`)
		return
	end
	-- A training run gives a longer grace, so a caught player is not caught again straight away.
	local grace = if ShiftServiceServer:isTraining() then ShiftConstants.TRAINING_GRACE else nil
	local nextMind = OccupantBrainRules.caught(before, player.UserId, now, from, grace)
	run.mind = nextMind
	run.counters.catches += 1
	-- The catch line comes from OccupantCatchSystem; this clears the "!" and shows the catch (face, tilt).
	show(current, nextMind, nil)
end

-- The kind's attack is the catch. Never yields.
local function onCatch(npc: Model, player: Player)
	local current = run.rig
	if current ~= nil and npc == current.model then
		catchPlayer(player, run.mind, false)
	end
end

-- One think at `now` with him at `position`: senses → OccupantBrainRules.step, the mind stored, his tells shown and
-- the effects carried out. Returns the intent (idle with no Manager or shift). Never yields.
local function think(def: NpcTypes.NpcDef, now: number, position: Vector3): NpcTypes.Intent
	local current, before, state = run.rig, run.mind, run.shift
	if current == nil or before == nil or state == nil then
		return { kind = "idle" }
	end
	-- A freeze kind's freeze (nil for Harlow): frozen, it opens no door.
	local freeze = OccupantWatchSystem.freezeFor(current.model)
	local frozen = freeze ~= nil and freeze.frozen
	-- Doors on his line of travel open first, so an opened leaf no longer blocks this think's sight rays; the beat
	-- follows the same rule (he takes it only when he opened one). No heading: no door opens.
	local heading = OccupantDoorRules.heading(current.root.AssemblyLinearVelocity, position, run.lastGoal)
	if not frozen and OfficeServiceServer:openDoorsNear(position, heading) then
		run.holdUntil = now + OccupantConstants.DOOR_BEAT_SECONDS
	end
	local participants = RoundServiceServer:participants()
	-- Fixed rolls (the QA seam) leave the rest at 0.5, as an absent roll.
	local fixed = run.fixedRolls
	local rolls = if fixed ~= nil then table.clone(fixed) else {}
	for index = #rolls + 1, ROLLS do
		rolls[index] = if fixed ~= nil then 0.5 else run.rng:NextNumber()
	end
	local senses = Sense.gather(current, def, now, position, {
		participants = participants,
		eligible = eligible,
		concealed = concealedFrom(current),
		world = world(),
		heard = run.pendingNoise,
		rolls = rolls,
		pacing = { tier = state.tier, solo = #participants <= 1, overtime = state.stage == "overtime" },
	})
	run.pendingNoise = nil
	-- The kind's behaviour blocks (Bramble: no desks; Harlow: every block).
	local kindDef = OccupantKindRegistry.get(run.currentKind)
	senses.blocks = if kindDef ~= nil then kindDef.blocks else nil
	if freeze ~= nil then
		senses.frozen = freeze.frozen
		senses.frozenAt = freeze.frozenAt
		senses.unfrozenAt = freeze.unfrozenAt
		-- Just unfrozen: the kid its head held becomes its chase target (OccupantWatchRules.lunge).
		senses.lunge = OccupantWatchSystem.takeLunge(current.model)
		-- A perch kind (B4): the map's perches, which a crew camera sees, and when he was last watched.
		if OccupantKindRegistry.perches(run.currentKind) then
			senses.perches = OccupantWatchSystem.perches(current)
			senses.perchHeight = OccupantSeatSystem.perchHeight(current)
			senses.watchedAt = freeze.lastWatchedAt
		end
	end
	local force = run.pendingForce
	if force ~= nil then
		run.pendingForce = nil
		before = OccupantAlertRules.force(before, senses, force.kind, force.userId)
	end
	local chaseId = OccupantStageSystem.takeChase()
	if chaseId ~= nil then
		before = (OccupantStageRules.chase(before, senses, chaseId))
	end
	-- The developer's ForceSlowTurn attribute (Studio only): every head turn that variant while it is set.
	before = OccupantTurnRules.arm(before, Sense.forcedTurn())
	local result = OccupantBrainRules.step(before, senses)
	run.mind = result.mind
	if result.mind.mode == "chase" and before.mode ~= "chase" then
		run.counters.chases += 1
		-- Any chase start (the jerk is one) runs on the NPC's very next frame, not on its next scheduled think.
		NpcServiceServer:wake(current.model)
	end
	show(current, result.mind, result.cue)
	-- After the mind is stored, so a catch builds on it.
	local effects = result.effects
	if effects ~= nil then
		OccupantEffectSystem.apply(current, effects, function(player: Player)
			catchPlayer(player, before, true)
		end)
	end
	-- After the effects, so a catch (which evicts them) is never an escape.
	for _, userId in OccupantEscapeRules.lost(before, run.mind or result.mind) do
		local player = Players:GetPlayerByUserId(userId)
		if player ~= nil and HideServiceServer:isHidden(player) then
			escaped:Fire(player)
		end
	end
	-- His hands type only while he types (never through the sit-in's motion, an ambush or a slow turn from the chair).
	OccupantSeatSystem.typing(current, run.mind or result.mind)
	local intent = result.intent
	run.lastGoal = if intent.kind == "goTo" then intent.position else nil
	return OccupantDoorRules.hold(intent, now, run.holdUntil)
end

-- The `harlow` brain: one think (above) on the NPC's tick. Never yields.
local function brain(def: NpcTypes.NpcDef, context: NpcTypes.BrainContext, npc: Model): NpcTypes.Intent?
	local current = run.rig
	if current == nil or npc ~= current.model then
		return { kind = "idle" }
	end
	local staged = OccupantStageSystem.intent(context.position)
	if staged ~= nil then
		return staged
	end
	return think(def, context.now, context.position)
end

-- While he watches in a slow turn or a stare, his brain thinks every frame too (behaviours design §11.4), so a
-- player's first move is the jerk on that frame rather than on the next 0.15 s NPC think. The intent here is not
-- carried out: the jerk wakes the NPC (`think`), so the run starts on its next frame. Never yields.
local function watch(now: number)
	local current, before = run.rig, run.mind
	local def = NpcRegistry.get(OccupantConstants.NPC_KIND)
	if current == nil or before == nil or def == nil or not OccupantTurnRules.turning(before) then
		return
	end
	run.counters.watchThinks += 1
	think(def, now, current.root.Position)
	local after = run.mind
	if after ~= nil and after.phase == "jerk" then
		run.counters.watchJerks += 1
	end
end

-- A noise: remembered for the next think if he hears it (not while resting or standing over a catch). A noise
-- inside the truck's box is dropped here, before it can replace an earlier valid one: `Senses.heard` carries
-- one point, so the one passed is the latest heard noise OUTSIDE the box.
local function onNoise(noise: NoiseTypes.NoiseEvent)
	local current = run.rig
	local currentMind = run.mind
	if current == nil or currentMind == nil or currentMind.mode == "rest" or currentMind.mode == "catch" then
		return
	end
	if OccupantBrainRules.inZone(noise.position, world().zone) then
		return
	end
	local scale = NoiseServiceServer:getHearingScale()
	if NoiseRules.hears(current.root.Position, noise.position, noise.radius, scale) then
		run.pendingNoise = noise.position
		run.counters.heard += 1
	end
end

OccupantBrainSystem.escaped = escaped
OccupantBrainSystem.applyTuning = applyTuning
OccupantBrainSystem.show = show
OccupantBrainSystem.world = world
OccupantBrainSystem.witness = witness
OccupantBrainSystem.onCatch = onCatch
OccupantBrainSystem.brain = brain
OccupantBrainSystem.watch = watch
OccupantBrainSystem.onNoise = onNoise

return OccupantBrainSystem
