--!strict
--[=[
	OccupantKindRegistry: every monster kind the Occupant feature can run (the map-agnostic roster, plan
	docs/superpowers/plans/2026-11-11-odd-hours-monster-roster-bramble.md). A kind is data: its rig template under
	ReplicatedStorage, whether it has painted faces, its speeds, which behaviour blocks it uses and its twist.

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

export type KindId = "harlow" | "bramble"

-- The behaviour blocks a kind may switch off (the shared ones, patrol, hear, chase, search and catch, always run):
-- work breaks and sit-ins at desks, and stares at hiding spots.
export type Blocks = {
	desks: boolean,
	stares: boolean,
}

-- The "freezes while watched" twist: the owl head (and how long non-stop watching lasts before it swaps target) and
-- the trail where it moved unwatched.
export type FreezeTwist = {
	headTurn: boolean,
	headSwapSeconds: number,
	trail: boolean,
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
}

local HARLOW: Kind = {
	id = "harlow",
	templatePath = OccupantAssets.TEMPLATE_PATH,
	faces = true,
	patrolSpeed = OccupantConstants.PATROL_SPEED,
	chaseSpeed = OccupantConstants.CHASE_SPEED,
	blocks = { desks = true, stares = true },
	freeze = nil,
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
