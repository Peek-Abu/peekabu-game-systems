--!strict
--[=[
	ShiftClockOutViewModel: the clock-out board under the Gloom meter (ShiftClockOutBoard), from the shift snapshot
	(ShiftClockOutRules on the server: each crew member punches their own card, half of the crew still in starts the
	truck's countdown, all of them end the shift). Shown while a run has a punch or a countdown: the tally ("2/4 CLOCKED
	OUT", punches of crew members still in the server out of the crew still in), one card per crew member still in
	(punched first; the local player's own card first and selected once they punched), the headline over the countdown
	and the hint under it. The countdown itself ticks on its own from `leavesAt` (ShiftCountdown). Pure.

	@class ShiftClockOutViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

export type BoardView = {
	-- "2/4 CLOCKED OUT".
	tally: string,
	punched: number,
	total: number,
	-- One card per crew member still in: true when punched (punched first).
	cards: { boolean },
	-- The card drawn selected (the local player's own, once they punched).
	selected: number?,
	-- When the truck leaves (server time), while its countdown runs.
	leavesAt: number?,
	headline: string,
	hint: string,
	-- The local player has punched (they wait in the truck).
	mine: boolean,
}

local ShiftClockOutViewModel = {}

--[=[
	The board for `snapshot` as `myId` sees it; nil outside a run, and until someone punches or the truck's countdown runs.
]=]
function ShiftClockOutViewModel.board(snapshot: ShiftTypes.ShiftSnapshot?, myId: number): BoardView?
	if snapshot == nil or snapshot.phase ~= "running" then
		return nil
	end
	local counting = snapshot.sub == "clockout" and snapshot.clockOutAt ~= nil
	local punched = 0
	for _, userId in snapshot.punched do
		if table.find(snapshot.crew, userId) then
			punched += 1
		end
	end
	if punched == 0 and not counting then
		return nil
	end
	local total = math.max(snapshot.crewIn, punched)
	local cards: { boolean } = {}
	for index = 1, total do
		cards[index] = index <= punched
	end
	local mine = table.find(snapshot.punched, myId) ~= nil
	local hint = if mine
		then "You're on the truck"
		elseif counting then "Clock out at the truck to ride along"
		else `At half the crew, the truck leaves in {ShiftConstants.TRUCK_LEAVES_SECONDS} s`
	return {
		tally = `{punched}/{total} CLOCKED OUT`,
		punched = punched,
		total = total,
		cards = cards,
		selected = if mine then 1 else nil,
		leavesAt = if counting then snapshot.clockOutAt else nil,
		headline = if counting then "TRUCK LEAVES IN" else "CLOCKING OUT",
		hint = hint,
		mine = mine,
	}
end

--[=[
	Whether the countdown reads urgent (coral, pulsing) with `seconds` left: its ticking last seconds.
]=]
function ShiftClockOutViewModel.urgent(seconds: number): boolean
	return seconds <= ShiftConstants.COUNTDOWN_TICKS
end

return ShiftClockOutViewModel
