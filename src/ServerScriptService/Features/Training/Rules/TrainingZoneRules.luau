--!strict
--[=[
	TrainingZoneRules: the hub's Training bay as a zone (owner 11-12: "the entire zone should queue you"). The whole
	bay starts training, and every player in it gets their own training at the same time: the bay keeps a pool of
	one-seat queue pads, each covering the whole bay, so each player boards a different pad and gets their own
	countdown and their own reserved server. Pure: TrainingZoneSystem senses the bay and makes or removes the pads.

	- `plan`: how many pads to add (positive) or empty pads to remove (negative). The pool holds a pad for every
	  player using one, one for every player waiting in the bay, and one spare for the next player, never more than
	  the cap. Only empty pads are removed.
	- `idle`: an empty pad may go once it has been empty for the grace time (a pad whose party just left stays a while,
	  so a teleport that fails puts its party back on the pad it left from).

	@class TrainingZoneRules
]=]

local TrainingZoneRules = {}

--[=[
	Pads to add (> 0) or empty pads to remove (< 0).
	@param busy pads with a player on them, a countdown, or a party that just left
	@param idle empty pads
	@param waiting players in the bay on no pad yet
	@param max the most pads one bay may hold
]=]
function TrainingZoneRules.plan(busy: number, idle: number, waiting: number, max: number): number
	local target = math.min(max, busy + waiting + 1)
	local delta = target - (busy + idle)
	if delta < 0 then
		return -math.min(idle, -delta)
	end
	return delta
end

--[=[
	Whether a pad counts as empty: nobody on it now and nobody for `grace` seconds (`lastBusyAt` nil: never used).
]=]
function TrainingZoneRules.idle(busyNow: boolean, lastBusyAt: number?, now: number, grace: number): boolean
	if busyNow then
		return false
	end
	return lastBusyAt == nil or now - lastBusyAt >= grace
end

return TrainingZoneRules
