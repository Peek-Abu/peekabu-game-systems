--!strict
--[=[
	DeathKnockdownUtils: the decisions of a knockdown, Death's non-lethal take-down (thrown, down a moment, back
	up). The server marks a downed character with the KNOCKDOWN_ATTRIBUTE (the throw's velocity) and clears it
	when they get up; the owning client turns that into the pose. Pure (reads an attribute, changes nothing).

	- `isDown(character)`: whether the character is held down now (gameplay refuses the vacuum and interaction).
	- `launchOf(value)`: the throw an attribute value carries, nil when it marks no knockdown.
	- `standsUp(latest, mine)`: a knockdown's timer stands the character up only when no later knockdown replaced it.
	- `next(wasDown, value, alive)`: what the owning client does when the attribute changes: "fall" (stand down,
	  take the throw), "rise" (get up), "release" (give the controls back but leave the body: it died) or "none".

	@class DeathKnockdownUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DeathConstants = require(ReplicatedStorage.Shared.Features.Death.Data.DeathConstants)

export type Step = "fall" | "rise" | "release" | "none"

local DeathKnockdownUtils = {}

function DeathKnockdownUtils.launchOf(value: unknown): Vector3?
	if typeof(value) == "Vector3" then
		return value
	end
	return nil
end

function DeathKnockdownUtils.isDown(character: Instance?): boolean
	if character == nil then
		return false
	end
	return DeathKnockdownUtils.launchOf(character:GetAttribute(DeathConstants.KNOCKDOWN_ATTRIBUTE)) ~= nil
end

function DeathKnockdownUtils.standsUp(latest: number?, mine: number): boolean
	return latest == mine
end

function DeathKnockdownUtils.next(wasDown: boolean, value: unknown, alive: boolean): Step
	local down = DeathKnockdownUtils.launchOf(value) ~= nil
	if not alive then
		return if wasDown then "release" else "none"
	end
	if down then
		return "fall"
	end
	return if wasDown then "rise" else "none"
end

return DeathKnockdownUtils
