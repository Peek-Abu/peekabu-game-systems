--!strict
--[=[
	FootstepGaitFormulas: how a step sounds for how the character moves. `gaitFor` picks the gait from what the
	character is doing (hidden > crouching > sprinting > walking); `scale` is that gait's volume and pitch multipliers
	from the character's footstep set. A walk blends toward the sprint with speed, from the set's walkSpeed (x the walk)
	to its runSpeed (x the sprint), so a character with no sprint flag (the Manager's chase run) still lands louder as
	it speeds up; the sprint flag is the full sprint at any speed. Pure.

	@class FootstepGaitFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FootstepTypes = require(ReplicatedStorage.Client.Features.Footstep.Data.FootstepTypes)

type Gait = FootstepTypes.Gait
type GaitScale = FootstepTypes.GaitScale

export type GaitInput = {
	hidden: boolean,
	crouching: boolean,
	sprinting: boolean,
}

export type GaitSet = {
	walkSpeed: number,
	runSpeed: number,
	gaits: FootstepTypes.GaitScales,
}

local FootstepGaitFormulas = {}

function FootstepGaitFormulas.gaitFor(input: GaitInput): Gait
	if input.hidden then
		return "hidden"
	elseif input.crouching then
		return "crouch"
	elseif input.sprinting then
		return "sprint"
	end
	return "walk"
end

--[=[
	The volume and pitch multipliers for a step in `gait` at `speed` (studs/s) from `set`.
]=]
function FootstepGaitFormulas.scale(set: GaitSet, gait: Gait, speed: number): GaitScale
	if gait == "crouch" then
		return set.gaits.crouch
	elseif gait == "hidden" then
		return set.gaits.hidden
	end
	local walk, sprint = set.gaits.walk, set.gaits.sprint
	local t = 1
	if gait == "walk" then
		local span = set.runSpeed - set.walkSpeed
		t = if span > 0 then math.clamp((speed - set.walkSpeed) / span, 0, 1) else 0
	end
	return {
		volume = walk.volume + (sprint.volume - walk.volume) * t,
		pitch = walk.pitch + (sprint.pitch - walk.pitch) * t,
	}
end

return FootstepGaitFormulas
