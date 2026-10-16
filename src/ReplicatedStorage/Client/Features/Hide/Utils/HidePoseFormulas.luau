--!strict
--[=[
	HidePoseFormulas: the tucked huddle a hiding player shows everyone (docs/superpowers/specs/
	2026-10-15-cleanup-crew-chase-kit-design.md §4). `targets` turns HideConstants.TUCK_POSE into each joint's Transform;
	`weight` eases the fold in over TUCK_SECONDS and out over UNTUCK_SECONDS (quad out: quick, then settling); `blend`
	lays the pose over whatever the animation put on the joint. Pure.

	@class HidePoseFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)

local HidePoseFormulas = {}

--[=[
	The tucked pose's Transform for each joint it moves, by Motor6D name.
]=]
function HidePoseFormulas.targets(): { [string]: CFrame }
	local targets: { [string]: CFrame } = {}
	for _, entry in HideConstants.TUCK_POSE do
		local r = entry.rotation
		targets[entry.joint] = CFrame.new(entry.offset) * CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
	end
	return targets
end

--[=[
	How folded the body is `elapsed` seconds after going in (`tucking`) or coming out: 0 standing, 1 tucked.
]=]
function HidePoseFormulas.weight(elapsed: number, tucking: boolean): number
	local duration = if tucking then HideConstants.TUCK_SECONDS else HideConstants.UNTUCK_SECONDS
	local t = if duration > 0 then math.clamp(elapsed / duration, 0, 1) else 1
	local eased = 1 - (1 - t) * (1 - t)
	return if tucking then eased else 1 - eased
end

--[=[
	The joint's Transform with the pose laid over the animated one at `weight`.
]=]
function HidePoseFormulas.blend(animated: CFrame, target: CFrame, weight: number): CFrame
	return animated:Lerp(target, math.clamp(weight, 0, 1))
end

return HidePoseFormulas
