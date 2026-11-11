--!strict
--[=[
	OccupantKindRegistry: every monster kind the Occupant feature can run (the map-agnostic roster, plan
	docs/superpowers/plans/2026-11-11-odd-hours-monster-roster-bramble.md). A kind is data: its rig template under
	ReplicatedStorage, whether it has painted faces, its speeds, which behaviour blocks it uses, its twist, and the
	player-facing words a run with it uses (`wordsOf`: its name in "Caught by ...", its first-catch and overtime tips),
	its voice (`voiceOf`; Bramble has none) and its own sounds (`soundsOf`, `footstepSetOf`; Bramble plays none of
	Harlow's).

	- `harlow`: today's manager, unchanged (his template, faces and speeds; every block; no twist).
	- `bramble`: the School's owl mascot. No painted face swap (its buttons and stitched smile are the model), never
	  sits at desks, chases at 21 (a sprint at 23 outruns it) and has the freeze twist: it cannot move while a crew
	  member watches it, its head turns to the kid it is after and swaps target after HEAD_SWAP_SECONDS of non-stop
	  watching, and it leaves a feather trail where it moved unwatched.

	A rig names its kind in the KIND_ATTRIBUTE attribute (`kindOf`); a rig without it is Harlow.

	@class OccupantKindRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantAssets = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantAssets)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)

export type KindId = "harlow" | "bramble"

-- The behaviour blocks a kind may switch off (the shared ones, patrol, hear, chase, search and catch, always run):
-- work breaks, sit-ins and ambushes at desks, and stares at hiding spots (the brain reads them as Senses.blocks).
export type Blocks = OccupantTypes.Blocks

-- The "freezes while watched" twist: the owl head (and how long non-stop watching lasts before it swaps target) and
-- the trail where it moved unwatched.
export type FreezeTwist = {
	headTurn: boolean,
	headSwapSeconds: number,
	trail: boolean,
}

-- The player-facing words a run with this kind uses (kid reading level): its name in a sentence ("Caught by <caughtBy>")
-- and the TipRegistry ids of its one-time tips for a first catch and for the overtime offer.
export type Words = {
	caughtBy: string,
	catchTip: string,
	overtimeTip: string,
}

-- A kind's voice: its lines per cue (OccupantTypes.Cue; the server picks one, OccupantFeedbackUtils.pickLine), the
-- fallback line per cue, and the clips the client voices a line with (OccupantFeedbackUtils.clipFor). A kind with no
-- voice never says a line.
export type Voice = {
	lines: { [string]: { string } },
	fallback: { [string]: string },
	clips: { string },
}

-- A kind's own sounds: OccupantAssets.SOUNDS ids per slot (nil: that moment is silent for this kind), and its
-- footsteps' FootstepAssets set (nil: its steps are silent). The chase music, the "spotted" sting, the heartbeat,
-- the dread, the desk swivel and the Rehired punch are every kind's (the roster plan reuses them).
export type Sounds = {
	-- A loop on its head while it is out (Harlow's pen tapping).
	mutter: string?,
	-- It heard something, and the far warning's click.
	curious: string?,
	-- It gave up a search.
	sigh: string?,
	-- At a desk: the typing loop, sitting down, the ambush (and the alert turn).
	typing: string?,
	sit: string?,
	ambush: string?,
	-- The slow turn's creak and the jerk's crack.
	creak: string?,
	crack: string?,
	-- The catch: the caught player's sting, the throw's stamp, and for everyone near its grab and the power-down.
	catchSting: string?,
	catchStamp: string?,
	grab: string?,
	powerDown: string?,
	-- A freeze kind moving again.
	unfreeze: string?,
	footsteps: string?,
}

export type Kind = {
	id: KindId,
	-- The art-owned rig Model under ReplicatedStorage (never in the source tree).
	templatePath: { string },
	-- Painted faces on a face plate (Harlow's Faces folder, OccupantFaceUtils).
	faces: boolean,
	patrolSpeed: number,
	chaseSpeed: number,
	blocks: Blocks,
	freeze: FreezeTwist?,
	words: Words,
	voice: Voice?,
	sounds: Sounds,
}

local HARLOW: Kind = {
	id = "harlow",
	templatePath = OccupantAssets.TEMPLATE_PATH,
	faces = true,
	patrolSpeed = OccupantConstants.PATROL_SPEED,
	chaseSpeed = OccupantConstants.CHASE_SPEED,
	blocks = { desks = true, stares = true },
	freeze = nil,
	words = { caughtBy = "the Manager", catchTip = "firstCatch", overtimeTip = "overtime" },
	voice = {
		lines = OccupantConstants.LINE_VARIANTS,
		fallback = OccupantConstants.LINES,
		clips = OccupantAssets.GIBBERISH,
	},
	sounds = {
		mutter = "harlowMutter",
		curious = "harlowCurious",
		sigh = "harlowSigh",
		typing = "harlowTyping",
		sit = "harlowSit",
		ambush = "harlowAmbush",
		creak = "harlowCreak",
		crack = "harlowCrack",
		catchSting = "harlowCatchSting",
		catchStamp = "catchFired",
		grab = "harlowGrab",
		powerDown = "harlowPowerDown",
		unfreeze = nil,
		footsteps = "harlow",
	},
}

local BRAMBLE: Kind = {
	id = "bramble",
	templatePath = { "Assets", "CleanupCrew", "Characters", "Bramble" },
	faces = false,
	patrolSpeed = 10,
	chaseSpeed = 21,
	blocks = { desks = false, stares = true },
	freeze = {
		headTurn = true,
		headSwapSeconds = OccupantConstants.HEAD_SWAP_SECONDS,
		trail = true,
	},
	words = { caughtBy = "Bramble", catchTip = "firstCatchBramble", overtimeTip = "overtimeBramble" },
	-- No voice: Bramble never speaks (none of Harlow's lines, no barks).
	voice = nil,
	-- None of Harlow's sounds. Its catch and unfreeze are its own empty slots (PENDING in OccupantAssets, silent) until
	-- the owner-approved Bramble sound round; its footsteps (the plan's soft foam thump) wait for a `bramble`
	-- FootstepAssets set, so its steps are silent until then.
	sounds = {
		mutter = nil,
		curious = nil,
		sigh = nil,
		typing = nil,
		sit = nil,
		ambush = nil,
		creak = nil,
		crack = nil,
		catchSting = "brambleCatch",
		catchStamp = nil,
		grab = nil,
		powerDown = nil,
		unfreeze = "brambleUnfreeze",
		footsteps = nil,
	},
}

local IDS: { KindId } = { "bramble", "harlow" }

local DEFAULT: KindId = "harlow"

local OccupantKindRegistry = {
	DEFAULT = DEFAULT,
}

--[=[
	`value` as a kind id when it names a registered kind, else nil.
]=]
function OccupantKindRegistry.parse(value: unknown): KindId?
	if value == "harlow" then
		return "harlow"
	elseif value == "bramble" then
		return "bramble"
	end
	return nil
end

function OccupantKindRegistry.get(id: string): Kind?
	if id == "harlow" then
		return HARLOW
	elseif id == "bramble" then
		return BRAMBLE
	end
	return nil
end

function OccupantKindRegistry.has(id: string): boolean
	return OccupantKindRegistry.parse(id) ~= nil
end

-- Every kind id, sorted.
function OccupantKindRegistry.ids(): { KindId }
	return table.clone(IDS)
end

--[=[
	Kind `id`'s player-facing words (Harlow's for an unknown id).
]=]
function OccupantKindRegistry.wordsOf(id: string): Words
	local kind = OccupantKindRegistry.get(id)
	return if kind ~= nil then kind.words else HARLOW.words
end

--[=[
	Kind `id`'s voice (nil: it never speaks); Harlow's for an unknown id.
]=]
function OccupantKindRegistry.voiceOf(id: string): Voice?
	local kind = OccupantKindRegistry.get(id)
	return if kind ~= nil then kind.voice else HARLOW.voice
end

--[=[
	Kind `id`'s own sounds; Harlow's for an unknown id.
]=]
function OccupantKindRegistry.soundsOf(id: string): Sounds
	local kind = OccupantKindRegistry.get(id)
	return if kind ~= nil then kind.sounds else HARLOW.sounds
end

--[=[
	The footstep set of a rig (its kind's; nil: its steps are silent). Footstep's TAG_SETS resolver for the Occupant tag.
]=]
function OccupantKindRegistry.footstepSetOf(model: Instance): string?
	return OccupantKindRegistry.soundsOf(OccupantKindRegistry.kindOf(model)).footsteps
end

--[=[
	Whether kind `id` has the freeze twist (false for an unknown id).
]=]
function OccupantKindRegistry.freezes(id: string): boolean
	local kind = OccupantKindRegistry.get(id)
	return kind ~= nil and kind.freeze ~= nil
end

--[=[
	The rig templates to try for kind `id`, in order: its own, then Harlow's as a stand-in (so a kind whose model is not
	built in the place yet still runs, with its own behaviour, in Harlow's body). Harlow (and an unknown id) has only
	his own.
]=]
function OccupantKindRegistry.templatePaths(id: string): { { string } }
	local kind = OccupantKindRegistry.get(id)
	if kind == nil or kind.templatePath == HARLOW.templatePath then
		return { HARLOW.templatePath }
	end
	return { kind.templatePath, HARLOW.templatePath }
end

--[=[
	The kind a rig names in its KIND_ATTRIBUTE attribute; Harlow when it names none (or an unknown one).
]=]
function OccupantKindRegistry.kindOf(model: Instance): KindId
	return OccupantKindRegistry.parse(model:GetAttribute(OccupantConstants.KIND_ATTRIBUTE)) or DEFAULT
end

return OccupantKindRegistry
