--!strict
--[=[
	EmployeeHeadLookFormulas: the head look (owner note 2026-11-08; cosmetic): every employee's head turns a little
	toward where its player looks, layered on the animations (EmployeeHeadLookSystem). Pure; the tuning is
	EmployeeConstants.HEAD_LOOK.

	- `target`: the look (its heading off the body and its pitch) to the head's turn and tip, within their most; a look
	  behind eases back to straight ahead (no snap across the back).
	- `ease`: one frame of the head's smoothing.
	- `transform`: the turn and tip as the Neck joint's extra rotation.
	- `owned`: whether an emote or action (Action priority and above) owns the head now.

	@class EmployeeHeadLookFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)

-- What `owned` reads of a playing animation track.
export type TrackLike = { IsPlaying: boolean, Priority: Enum.AnimationPriority, WeightCurrent: number }

-- The priorities that own the head (emotes, fidgets, abilities, actions).
local OWNING: { [Enum.AnimationPriority]: boolean } = {
	[Enum.AnimationPriority.Action] = true,
	[Enum.AnimationPriority.Action2] = true,
	[Enum.AnimationPriority.Action3] = true,
	[Enum.AnimationPriority.Action4] = true,
}
-- A track fading out under this weight no longer owns the head.
local OWNING_WEIGHT = 0.1

local EmployeeHeadLookFormulas = {}

--[=[
	The head's turn (radians, left positive) and tip (up positive) for a look `relative` radians off the body at
	`pitch` (radians, up positive).
]=]
function EmployeeHeadLookFormulas.target(relative: number, pitch: number): (number, number)
	local tuning = EmployeeConstants.HEAD_LOOK
	local turn = (relative + math.pi) % (2 * math.pi) - math.pi
	local size = math.abs(turn)
	local yaw = if size <= math.pi / 2
		then math.clamp(turn, -tuning.maxYaw, tuning.maxYaw)
		else (if turn >= 0 then 1 else -1) * tuning.maxYaw * (math.pi - size) / (math.pi / 2)
	local tip = math.clamp((pitch - tuning.neutral) * tuning.pitchShare, -tuning.maxPitch, tuning.maxPitch)
	return yaw, tip
end

--[=[
	One frame (`dt`) of the head easing from `current` toward `target` (time constant HEAD_LOOK.ease).
]=]
function EmployeeHeadLookFormulas.ease(current: number, target: number, dt: number): number
	if dt <= 0 then
		return current
	end
	return current + (target - current) * (1 - math.exp(-math.min(dt, 0.1) / EmployeeConstants.HEAD_LOOK.ease))
end

--[=[
	The Neck joint's extra rotation for a turn `yaw` and a tip `pitch` (the face turns, then tips).
]=]
function EmployeeHeadLookFormulas.transform(yaw: number, pitch: number): CFrame
	if yaw == 0 and pitch == 0 then
		return CFrame.identity
	end
	return CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
end

--[=[
	Whether an emote or action owns the head: a playing track at Action priority or above, not faded out.
]=]
function EmployeeHeadLookFormulas.owned(tracks: { TrackLike }): boolean
	for _, track in tracks do
		if track.IsPlaying and OWNING[track.Priority] and track.WeightCurrent >= OWNING_WEIGHT then
			return true
		end
	end
	return false
end

return EmployeeHeadLookFormulas
