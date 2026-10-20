--!strict
--[=[
	ShiftLivesRules: Gloom lives. A player starts a shift with a few lives (the base, shaped by modifiers); each catch
	spends one, and the last knocks them out for the shift. There is no way to regain a life. Pure.

	@class ShiftLivesRules
]=]

local ShiftLivesRules = {}

--[=[
	Lives at the start of a shift: `base` run through each modifier in order, floored, at least 1.
]=]
function ShiftLivesRules.starting(base: number, modifiers: { (number) -> number }): number
	local lives = base
	for _, modify in modifiers do
		lives = modify(lives)
	end
	return math.max(math.floor(lives), 1)
end

--[=[
	One catch: the lives left (never below 0), and whether that knocks the player out (they have none left).
]=]
function ShiftLivesRules.spend(remaining: number): (number, boolean)
	local left = math.max(remaining - 1, 0)
	return left, left == 0
end

return ShiftLivesRules
