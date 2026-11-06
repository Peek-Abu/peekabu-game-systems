--!strict
--[=[
	VacuumFeelFormulas: the vacuum feel pass (2026-11-06; all visual, the suction is untouched). Pure.

	- The pull (VacuumPullSystem): a pile being sucked leans toward the nozzle (`lean`), stretches up toward it and thins
	  (`stretch`, about its volume kept), and wobbles (`wobble`), all growing as it nears done; each tug (a puff of goo)
	  hops it, which stretches it further.
	- The camera (VacuumCameraSystem, the local player only): the view widens a few degrees while sucking (`fov`), a
	  strain shake builds once a pile is well under way (`strain`, trauma per second), and a pop punches (`popTrauma`).

	@class VacuumFeelFormulas
]=]

local VacuumFeelFormulas = {}

VacuumFeelFormulas.MAX_LEAN = math.rad(22)
VacuumFeelFormulas.MAX_WOBBLE = math.rad(7)
VacuumFeelFormulas.MAX_STRAIN = 0.35
-- How far (studs) the nozzle can be and the pile still leans fully; it fades out by FAR_PULL.
local NEAR_PULL = 4
local FAR_PULL = 14
local BASE_LEAN = math.rad(6)
local STRETCH = 0.22
local TUG_STRETCH = 0.25
local WOBBLE_BASE = 0.25
local WOBBLE_HZ = 6.5

--[=[
	The pile's lean toward a nozzle `distance` studs off at `progress` (0..1), radians.
]=]
function VacuumFeelFormulas.lean(distance: number, progress: number): number
	local reach = 1 - math.clamp((distance - NEAR_PULL) / (FAR_PULL - NEAR_PULL), 0, 1)
	local p = math.clamp(progress, 0, 1)
	return math.min(VacuumFeelFormulas.MAX_LEAN, (BASE_LEAN + (VacuumFeelFormulas.MAX_LEAN - BASE_LEAN) * p) * reach)
end

--[=[
	The pile's stretch at `progress` with a tug's hop `hop` (0..1): its scale along its up axis and across, the volume
	about kept.
]=]
function VacuumFeelFormulas.stretch(progress: number, hop: number): (number, number)
	local up = 1 + STRETCH * math.clamp(progress, 0, 1) + TUG_STRETCH * math.max(hop, 0)
	return up, 1 / math.sqrt(up)
end

--[=[
	The pile's wobble (radians) at time `t`, seeded per pile, from WOBBLE_BASE of its most at the start to all of it
	near done.
]=]
function VacuumFeelFormulas.wobble(t: number, seed: number, progress: number): number
	local p = math.clamp(progress, 0, 1)
	local weight = WOBBLE_BASE + (1 - WOBBLE_BASE) * p
	local wave = 0.65 * math.sin(2 * math.pi * WOBBLE_HZ * t + seed)
		+ 0.35 * math.sin(2 * math.pi * WOBBLE_HZ * 1.7 * t + seed * 2.3)
	return VacuumFeelFormulas.MAX_WOBBLE * weight * wave
end

--[=[
	The view's widening (degrees) while sucking at `progress`; 0 when not.
]=]
function VacuumFeelFormulas.fov(active: boolean, progress: number): number
	if not active then
		return 0
	end
	return 2 + 3 * math.clamp(progress, 0, 1)
end

--[=[
	Camera trauma per second while sucking at `progress`: none in a pile's first 40%, then growing to MAX_STRAIN.
]=]
function VacuumFeelFormulas.strain(progress: number): number
	local p = math.clamp((progress - 0.4) / 0.6, 0, 1)
	return VacuumFeelFormulas.MAX_STRAIN * p * p
end

--[=[
	The camera trauma of a pop by the pile's size (studs across).
]=]
function VacuumFeelFormulas.popTrauma(size: number): number
	return math.clamp(0.15 + size * 0.03, 0.15, 0.45)
end

return VacuumFeelFormulas
