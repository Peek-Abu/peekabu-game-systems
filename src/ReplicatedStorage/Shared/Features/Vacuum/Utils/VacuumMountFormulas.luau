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
	The back attachment's frame in torso space: the mount's height, side and turn, at `depth`.
]=]
function VacuumMountFormulas.backFrame(mount: CFrame, depth: number): CFrame
	return CFrame.new(mount.X, mount.Y, depth) * mount.Rotation
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
