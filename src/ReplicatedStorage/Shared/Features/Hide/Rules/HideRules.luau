--!strict
--[=[
	HideRules: who may go into a hiding spot, and how long they may stay (docs/superpowers/specs/
	2026-10-15-cleanup-crew-chase-kit-design.md §4). In: alive, not being caught, not already hidden, the spot free and
	not cooling off for them, rested since their last stay (REENTER_SECONDS), within the prompt's range (plus
	RANGE_TOLERANCE), and empty-handed or holding a small (tiny or light) item. Out: not before MIN_STAY_SECONDS (a tap in and
	out cannot spam). Stay: fine until CAMP_WARN_SECONDS, cramped until CAMP_SECONDS, then pushed out. Shared: the
	client's chip counts down with the same rule. Pure.

	@class HideRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)
local HideTypes = require(ReplicatedStorage.Shared.Features.Hide.Data.HideTypes)

export type Camp = "ok" | "cramped" | "out"

local HideRules = {}

function HideRules.canEnter(input: HideTypes.EnterInput): (boolean, string?)
	if not input.alive then
		return false, "not alive"
	end
	if input.catching then
		return false, "caught"
	end
	if input.hidden then
		return false, "already hidden"
	end
	local held = input.heldSize
	if held ~= nil and HideConstants.POCKETABLE_SIZES[held] ~= true then
		return false, "hands full"
	end
	if input.occupied then
		return false, "taken"
	end
	if input.cooling then
		return false, "cramped"
	end
	if not input.rested then
		return false, "too soon"
	end
	if not (input.distance <= HideConstants.ENTER_RANGE + HideConstants.RANGE_TOLERANCE) then
		return false, "too far"
	end
	return true, nil
end

--[=[
	Whether a player who went in `stayed` seconds ago may come out on their own (a rule may always force them out).
]=]
function HideRules.canLeave(stayed: number): boolean
	return stayed >= HideConstants.MIN_STAY_SECONDS
end

--[=[
	How a stay of `elapsed` seconds in one spot is going.
]=]
function HideRules.camp(elapsed: number): Camp
	if elapsed >= HideConstants.CAMP_SECONDS then
		return "out"
	end
	if elapsed >= HideConstants.CAMP_WARN_SECONDS then
		return "cramped"
	end
	return "ok"
end

--[=[
	Whole seconds (rounded up) before a stay of `elapsed` seconds is pushed out; never below 0.
]=]
function HideRules.secondsLeft(elapsed: number): number
	return math.max(0, math.ceil(HideConstants.CAMP_SECONDS - elapsed))
end

return HideRules
