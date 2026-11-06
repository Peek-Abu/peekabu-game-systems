--!strict
--[=[
	OccupantStageRules: a filmmaker staging Mr. Harlow for a shot (the admin-only `harlow` command). Pure.

	- `freeze`: he stands where he is and thinks nothing (no sight, no hearing, no catches) until `free`.
	- `come` / `rush`: he walks / runs to where the caller stood, then freezes there.
	- `here`: he is moved to the caller and frozen (the service moves him).
	- `calm`: everyone in the shift gets CALM_SECONDS of grace, and a chase ends (he walks his route again).
	- `chase`: he starts a real chase of one player at once (`chase`), with every rule of a normal chase after.

	While staged (`intent` returns his intent) his brain is skipped. `chase` and `calm` change his mind instead and
	leave him unstaged.

	@class OccupantStageRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local NpcTypes = require(ServerScriptService.Features.Npc.Data.NpcTypes)
local OccupantMindUtils = require(ServerScriptService.Features.Occupant.Utils.OccupantMindUtils)

type Mind = OccupantTypes.Mind
type Senses = OccupantTypes.Senses

export type Action = "freeze" | "free" | "come" | "rush" | "here" | "calm" | "chase"
export type Stage = { kind: "freeze" } | { kind: "goTo", position: Vector3, run: boolean }

-- Within this many studs (flat) of a staged spot he has arrived.
local ARRIVE_DISTANCE = 3

local OccupantStageRules = {}

-- Seconds of grace `calm` gives every player.
OccupantStageRules.CALM_SECONDS = 20
OccupantStageRules.ACTION_NAMES = { "freeze", "free", "come", "rush", "here", "calm", "chase" }

function OccupantStageRules.parse(action: string): Action?
	local name = string.lower(action)
	if name == "freeze" then
		return "freeze"
	elseif name == "free" then
		return "free"
	elseif name == "come" then
		return "come"
	elseif name == "rush" then
		return "rush"
	elseif name == "here" then
		return "here"
	elseif name == "calm" then
		return "calm"
	elseif name == "chase" then
		return "chase"
	end
	return nil
end

function OccupantStageRules.needsTarget(action: Action): boolean
	return action == "chase"
end

--[=[
	His intent while staged at `position`, and the stage after it (a walk ends frozen at its spot).
]=]
function OccupantStageRules.intent(stage: Stage, position: Vector3): (NpcTypes.Intent, Stage)
	if stage.kind == "goTo" then
		local offset = stage.position - position
		if Vector3.new(offset.X, 0, offset.Z).Magnitude > ARRIVE_DISTANCE then
			return { kind = "goTo", position = stage.position, run = stage.run }, stage
		end
		return { kind = "idle" }, { kind = "freeze" }
	end
	return { kind = "idle" }, stage
end

--[=[
	Where `here` puts him: at the caller's spot on their floor (`callerFeetY`), his root `rootHeight` above it, facing the
	caller's flat look (straight ahead -Z when they look straight up or down).
]=]
function OccupantStageRules.standIn(caller: CFrame, callerFeetY: number, rootHeight: number): CFrame
	local spot = Vector3.new(caller.Position.X, callerFeetY + rootHeight, caller.Position.Z)
	local flat = caller.LookVector * Vector3.new(1, 0, 1)
	local facing = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	return CFrame.lookAt(spot, spot + facing)
end

--[=[
	Into a chase of `userId` now, wherever they are in the shift (seen or not). The mind unchanged and false when they
	are not among the players he senses, or during a catch.
]=]
function OccupantStageRules.chase(mind: Mind, senses: Senses, userId: number): (Mind, boolean)
	if mind.mode == "catch" then
		return mind, false
	end
	for _, glimpse in senses.players do
		if glimpse.userId == userId then
			return OccupantMindUtils.chase(mind, senses, glimpse, false).mind, true
		end
	end
	return mind, false
end

--[=[
	Every one of `userIds` gets CALM_SECONDS of grace from `now`; a chase or search ends on his route.
]=]
function OccupantStageRules.calm(mind: Mind, userIds: { number }, now: number): Mind
	local nextMind: Mind
	if mind.mode == "chase" or mind.mode == "search" then
		nextMind = OccupantMindUtils.enter(mind, "patrol", now)
		OccupantMindUtils.forget(nextMind)
	else
		nextMind = table.clone(mind)
	end
	local grace = table.clone(mind.grace)
	for _, userId in userIds do
		grace[userId] = now + OccupantStageRules.CALM_SECONDS
	end
	nextMind.grace = grace
	return nextMind
end

return OccupantStageRules
