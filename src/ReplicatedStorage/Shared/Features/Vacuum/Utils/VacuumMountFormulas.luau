--!strict
--[=[
	VacuumMountFormulas: where a back-worn vacuum meets its wearer's back. Pure.

	Two attachment points are joined: the wearer's back (VacuumMountSystem.BACK_NAME on the UpperTorso, on the
	surface of whatever the body wears there: torso, hoodie, coat) and the pack's mount plate
	(VacuumMountSystem.PLATE_NAME, the middle of the harness pad's front face). The pack is placed so the plate
	sits exactly on the back, so any vacuum skin fits any employee with no gap and nothing sunk in, whatever the
	torso's shape. Before this, the pad was put on the back of the torso's bounding box (the registry's or a
	generic fit), which stood off a narrow back (Prickles, ~0.1 stud) and sat inside a hoodie (Cappy, ~0.25).

	Torso space: +Y up, +Z back, +X the wearer's right. Pack space: the pack's pivot, the same axes.

	@class VacuumMountFormulas
]=]

local VacuumMountFormulas = {}

--[=[
	Ray origins in torso space: a `cols` x `rows` grid over the pad's footprint (half-extents `half`) centred on
	the mount's `centre` (x, y), each `from` studs behind the torso's centre. The grid stays inside the pad (cell
	centres), so the body's curve past the pad's edge is never read.
]=]
function VacuumMountFormulas.rays(centre: Vector2, half: Vector2, cols: number, rows: number, from: number): { Vector3 }
	local origins: { Vector3 } = {}
	for i = 1, cols do
		local x = centre.X + half.X * ((2 * i - 1) / cols - 1)
		for j = 1, rows do
			local y = centre.Y + half.Y * ((2 * j - 1) / rows - 1)
			table.insert(origins, Vector3.new(x, y, from))
		end
	end
	return origins
end

--[=[
	The back's depth (torso-space Z of its surface under the pad): the outermost of `hits` (so the flat plate never
	sinks into any of them), `fallback` with none, kept within [`minDepth`, `maxDepth`].
]=]
function VacuumMountFormulas.backDepth(hits: { number }, fallback: number, minDepth: number, maxDepth: number): number
	local depth: number? = nil
	for _, hit in hits do
		depth = if depth == nil then hit else math.max(depth, hit)
	end
	return math.clamp(depth or fallback, minDepth, maxDepth)
end

--[=[
	The plane a flat plate lies on against `points` (torso-space hits on the back): its lean back from upright (the
	back's slope fitted through the hits, at most `maxTilt`) and its depth at height `centreY`, as far in as it goes
	with no hit in front of it. Nil with no hits. A back that slopes out toward a hood (Cappy's hoodie) gets a plate
	that lies along it instead of sinking into the hood or standing off below it.
]=]
function VacuumMountFormulas.backPlane(points: { Vector3 }, centreY: number, maxTilt: number): (number?, number)
	local count = #points
	if count == 0 then
		return nil, 0
	end
	local meanY, meanZ = 0, 0
	for _, p in points do
		meanY += p.Y
		meanZ += p.Z
	end
	meanY /= count
	meanZ /= count
	local syy, syz = 0, 0
	for _, p in points do
		syy += (p.Y - meanY) ^ 2
		syz += (p.Y - meanY) * (p.Z - meanZ)
	end
	local limit = math.tan(maxTilt)
	local slope = if syy > 1e-9 then math.clamp(syz / syy, -limit, limit) else 0
	local depth = -math.huge
	for _, p in points do
		depth = math.max(depth, p.Z - slope * (p.Y - centreY))
	end
	return depth, math.atan(slope)
end

--[=[
	The back attachment's frame in torso space: the mount's height, side and turn, at `depth`, leaning back by
	`tilt` (radians; its up axis toward +Z) to lie along the back.
]=]
function VacuumMountFormulas.backFrame(mount: CFrame, depth: number, tilt: number?): CFrame
	return CFrame.new(mount.X, mount.Y, depth) * mount.Rotation * CFrame.Angles(tilt or 0, 0, 0)
end

--[=[
	The mount plate in pack space: the middle of the harness pad's front face (the face toward the wearer, the
	pad's -Z), from the pad's frame in pack space and its size.
]=]
function VacuumMountFormulas.plateFrame(pad: CFrame, padSize: Vector3): CFrame
	return pad * CFrame.new(0, 0, -padSize.Z / 2)
end

--[=[
	The pack's pivot (world or any parent space) that puts its `plate` (pack space) exactly on `back` (that same
	space).
]=]
function VacuumMountFormulas.pivotFor(back: CFrame, plate: CFrame): CFrame
	return back * plate:Inverse()
end

--[=[
	How far a plate at depth `plate` stands off a back at depth `back` (torso-space Z); negative: sunk into it.
]=]
function VacuumMountFormulas.gap(plate: number, back: number): number
	return plate - back
end

return VacuumMountFormulas
