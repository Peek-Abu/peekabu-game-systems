--!strict
--[=[
	DepotTruckPopFormulas: the hub truck's pop-in and fade-out (DepotTruckPopConstants). Pure.

	- `scale(t)`: START_SCALE at 0, an ease-out-back overshoot (BACK), exactly 1 from POP_SECONDS on.
	- `transparency(t, arriving)`: arriving, from the ghost to solid over POP_SECONDS (front-loaded, so the truck is
	  mostly there by the overshoot); leaving, from solid back to the ghost over LEAVE_SECONDS.

	@class DepotTruckPopFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotTruckPopConstants = require(ReplicatedStorage.Client.Features.Depot.Data.DepotTruckPopConstants)

local C = DepotTruckPopConstants

local DepotTruckPopFormulas = {}

function DepotTruckPopFormulas.scale(t: number): number
	if t <= 0 then
		return C.START_SCALE
	end
	if t >= C.POP_SECONDS then
		return 1
	end
	local x = t / C.POP_SECONDS
	-- Ease-out-back (BACK = 3 peaks 25% past 1 at x = 0.5, back to 1 at x = 1): from START_SCALE 0.7 that is a peak
	-- of about 1.075.
	local u = x - 1
	local eased = 1 + (C.BACK + 1) * u ^ 3 + C.BACK * u ^ 2
	return C.START_SCALE + (1 - C.START_SCALE) * eased
end

function DepotTruckPopFormulas.transparency(t: number, arriving: boolean): number
	local ghost = C.GHOST_TRANSPARENCY
	if arriving then
		local x = math.clamp(t / C.POP_SECONDS, 0, 1)
		return ghost * (1 - x) ^ 2
	end
	local x = math.clamp(t / C.LEAVE_SECONDS, 0, 1)
	return ghost * x
end

return DepotTruckPopFormulas
