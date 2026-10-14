--!strict
--[=[
	VacuumHoldFormulas: how a holder holds the full-size vacuum so it rests on the floor instead of sinking
	through it. The vacuum is the same size for everyone.

	Its corners are given in grip space (+Y up, -Z front, the grip at the origin). A holder whose hanging hand is
	high enough (a stock avatar) holds it upright. A shorter one first angles it about the grip, front up, like a
	person tipping an upright vacuum back when their hand is lower, as little as clears the floor; past
	`maxTilt` it would stop reading as held, so the rest is made up by lifting the hand (an arm pose, see
	AnimationVacuumHoldSystem): a chibi's arm is far shorter than the canister is tall.

	@class VacuumHoldFormulas
]=]

local VacuumHoldFormulas = {}

-- The tilt search resolution.
local TILT_STEP = math.rad(0.25)
-- Never plan the lifted grip at the arm's full stretch.
local REACH_USE = 0.95

--[=[
	How far (studs) the lowest of `corners` sits below the grip once the vacuum is tilted `tilt` radians about
	the grip's X axis (positive: front up).
]=]
function VacuumHoldFormulas.depth(corners: { Vector3 }, tilt: number): number
	local rotation = CFrame.Angles(tilt, 0, 0)
	local low = 0
	for _, corner in corners do
		low = math.min(low, (rotation * corner).Y)
	end
	return -low
end

--[=[
	The tilt (radians, front up) and hand lift (studs) for a holder whose hanging hand holds the grip `hang`
	studs above the floor: (0, 0) when it already clears the floor by `clearance` (or `hang` is unknown); else
	the smallest tilt up to `maxTilt` that clears it; else the tilt that leaves the least to lift, and that lift.
]=]
function VacuumHoldFormulas.fit(
	corners: { Vector3 },
	hang: number?,
	clearance: number,
	maxTilt: number
): (number, number)
	if hang == nil or VacuumHoldFormulas.depth(corners, 0) + clearance <= hang then
		return 0, 0
	end
	local best, bestDepth = 0, VacuumHoldFormulas.depth(corners, 0)
	local tilt = 0
	while tilt <= maxTilt + 1e-9 do
		local depth = VacuumHoldFormulas.depth(corners, tilt)
		if depth + clearance <= hang then
			return tilt, 0
		end
		if depth < bestDepth then
			best, bestDepth = tilt, depth
		end
		tilt += TILT_STEP
	end
	return best, bestDepth + clearance - hang
end

--[=[
	Where (HumanoidRootPart space) the grip goes when the hand is lifted `lift` studs above its hang: for a
	shoulder at `shoulder` and an arm `armLength` long to the grip, beside the torso by `sideClear` (so the
	vacuum's body misses it) as far as the arm reaches, the rest of the reach out in front.
]=]
function VacuumHoldFormulas.liftTarget(shoulder: Vector3, armLength: number, lift: number, sideClear: number): Vector3
	local reach = armLength * REACH_USE
	local dy = math.clamp(lift - armLength, -reach, 0)
	local dx = math.max(0, sideClear - shoulder.X)
	local across = reach * reach - dy * dy
	if dx * dx > across then
		dx = math.sqrt(math.max(0, across))
	end
	local forward = math.sqrt(math.max(0, across - dx * dx))
	return shoulder + Vector3.new(dx, dy, -forward)
end

return VacuumHoldFormulas
