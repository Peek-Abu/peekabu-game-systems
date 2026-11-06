--!strict
--[=[
	FilmPathFormulas: the film camera's glide through saved marks (FilmCameraSystem). Pure.

	The position, the look direction and the FOV each follow a Catmull-Rom spline through the marks, so the camera
	passes through every mark without stopping or snapping, and progress is by distance along the path (an even speed),
	eased in and out over the whole glide. The camera never rolls: it looks along the spline's look with world up.

	@class FilmPathFormulas
]=]

export type Mark = {
	position: Vector3,
	-- Unit look direction.
	look: Vector3,
	fov: number,
}

export type Path = {
	marks: { Mark },
	-- The path's length up to each mark (lengths[1] = 0), measured along the spline.
	lengths: { number },
	total: number,
}

-- Samples per segment when measuring the spline's length.
local MEASURE_STEPS = 24

local FilmPathFormulas = {}

--[=[
	Cubic ease in and out on [0, 1] (clamped).
]=]
function FilmPathFormulas.ease(t: number): number
	local x = math.clamp(t, 0, 1)
	if x < 0.5 then
		return 4 * x * x * x
	end
	return 1 - ((-2 * x + 2) ^ 3) / 2
end

-- Uniform Catmull-Rom between b and c (a and d its neighbours) at u in [0, 1].
local function spline(a: Vector3, b: Vector3, c: Vector3, d: Vector3, u: number): Vector3
	local u2 = u * u
	local u3 = u2 * u
	return 0.5 * ((2 * b) + (c - a) * u + (2 * a - 5 * b + 4 * c - d) * u2 + (3 * b - a - 3 * c + d) * u3)
end

local function splineNumber(a: number, b: number, c: number, d: number, u: number): number
	local u2 = u * u
	local u3 = u2 * u
	return 0.5 * ((2 * b) + (c - a) * u + (2 * a - 5 * b + 4 * c - d) * u2 + (3 * b - a - 3 * c + d) * u3)
end

-- The four marks around segment `index` (index → index + 1), the ends repeated.
local function around(marks: { Mark }, index: number): (Mark, Mark, Mark, Mark)
	local count = #marks
	return marks[math.max(index - 1, 1)],
		marks[index],
		marks[math.min(index + 1, count)],
		marks[math.min(index + 2, count)]
end

local function positionAt(marks: { Mark }, index: number, u: number): Vector3
	local a, b, c, d = around(marks, index)
	return spline(a.position, b.position, c.position, d.position, u)
end

--[=[
	A path through `marks` (at least one), measured for even speed.
]=]
function FilmPathFormulas.build(marks: { Mark }): Path
	local lengths = { 0 }
	local total = 0
	for index = 1, #marks - 1 do
		local previous = marks[index].position
		for step = 1, MEASURE_STEPS do
			local point = positionAt(marks, index, step / MEASURE_STEPS)
			total += (point - previous).Magnitude
			previous = point
		end
		lengths[index + 1] = total
	end
	return { marks = marks, lengths = lengths, total = total }
end

-- The segment and the spline parameter inside it for a distance along the path (linear within the segment's
-- measured samples, close enough to even speed for a camera).
local function locate(path: Path, distance: number): (number, number)
	local marks, lengths = path.marks, path.lengths
	for index = 1, #marks - 1 do
		local startAt, endAt = lengths[index], lengths[index + 1]
		if distance <= endAt or index == #marks - 1 then
			local segment = endAt - startAt
			if segment <= 1e-6 then
				return index, 1
			end
			-- Walk the segment's samples to find the parameter at this distance.
			local walked = startAt
			local previous = marks[index].position
			for step = 1, MEASURE_STEPS do
				local point = positionAt(marks, index, step / MEASURE_STEPS)
				local piece = (point - previous).Magnitude
				if walked + piece >= distance and piece > 0 then
					return index, (step - 1 + (distance - walked) / piece) / MEASURE_STEPS
				end
				walked += piece
				previous = point
			end
			return index, 1
		end
	end
	return 1, 0
end

--[=[
	The camera at eased progress `t` (0 = the first mark, 1 = the last) and its FOV.
]=]
function FilmPathFormulas.sample(path: Path, t: number): (CFrame, number)
	local marks = path.marks
	if #marks == 1 or path.total <= 1e-6 then
		local only = if #marks == 1 or t < 0.5 then marks[1] else marks[#marks]
		return CFrame.lookAt(only.position, only.position + only.look), only.fov
	end
	local index, u = locate(path, FilmPathFormulas.ease(t) * path.total)
	local a, b, c, d = around(marks, index)
	local position = spline(a.position, b.position, c.position, d.position, u)
	local look = spline(a.look, b.look, c.look, d.look, u)
	if look.Magnitude < 1e-4 then
		look = if u < 0.5 then b.look else c.look
	end
	local flat = Vector3.new(look.X, 0, look.Z)
	-- Straight up or down: keep a level right-hand side by nudging the look off vertical.
	if flat.Magnitude < 1e-3 then
		look = Vector3.new(1e-3, math.sign(look.Y), 0)
	end
	local fov = splineNumber(a.fov, b.fov, c.fov, d.fov, u)
	return CFrame.lookAt(position, position + look.Unit), fov
end

return FilmPathFormulas
