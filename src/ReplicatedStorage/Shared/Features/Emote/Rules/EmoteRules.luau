--!strict
--[=[
	EmoteRules: pure emote logic, shared by both realms.

	- `clipKey(id)`: the AnimationRegistry key of an emote item's clip (`emote:<id>`).
	- `inSlot(look, slot)`: the emote on the employee's wheel in that slot (nil = empty).
	- `check(state)`: whether the body may start an emote now. Refusal reasons: "empty slot", "no clip yet",
	  "down" (dead or knocked down), "hiding", "carrying", "too soon" (EmoteConstants.COOLDOWN).

	@class EmoteRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local EmoteConstants = require(ReplicatedStorage.Shared.Features.Emote.Data.EmoteConstants)

-- What the server knows about the body when an emote is asked for.
export type State = {
	-- The emote in the asked slot (nil = empty).
	emote: string?,
	-- Whether its clip is in the AnimationRegistry yet.
	hasClip: boolean,
	alive: boolean,
	knocked: boolean,
	hiding: boolean,
	carrying: boolean,
	now: number,
	-- When this player's last emote started (nil = never).
	last: number?,
}

local EmoteRules = {}

function EmoteRules.clipKey(id: string): string
	return `emote:{id}`
end

function EmoteRules.inSlot(look: CosmeticTypes.Look, slot: number): string?
	local id = look.wheel[slot]
	return if id ~= nil and id ~= "" then id else nil
end

function EmoteRules.check(state: State): (boolean, string?)
	if state.emote == nil then
		return false, "empty slot"
	end
	if not state.hasClip then
		return false, "no clip yet"
	end
	if not state.alive or state.knocked then
		return false, "down"
	end
	if state.hiding then
		return false, "hiding"
	end
	if state.carrying then
		return false, "carrying"
	end
	local last = state.last
	if last ~= nil and state.now - last < EmoteConstants.COOLDOWN then
		return false, "too soon"
	end
	return true, nil
end

return EmoteRules
