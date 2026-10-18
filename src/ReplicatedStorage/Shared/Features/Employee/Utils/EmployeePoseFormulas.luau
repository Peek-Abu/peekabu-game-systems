--!strict
--[=[
	EmployeePoseFormulas: the maths that poses a rig once, with no Animator and no WorldModel: a pose's joint turn,
	a Motor6D's offset under it, forward kinematics over the rig's joint links from its root, and the bounds of the
	posed parts (for framing a camera on them).

	@class EmployeePoseFormulas
]=]

-- `b`'s frame is `a`'s frame * `offset` (parts by index).
export type Link = { a: number, b: number, offset: CFrame }

export type Box = { cframe: CFrame, size: Vector3 }
export type Bounds = { min: Vector3, max: Vector3 }

local EmployeePoseFormulas = {}

-- A joint turn from degrees about X, Y and Z (CFrame.Angles order).
function EmployeePoseFormulas.turn(degrees: Vector3): CFrame
	return CFrame.Angles(math.rad(degrees.X), math.rad(degrees.Y), math.rad(degrees.Z))
end

-- Part1's frame relative to Part0's for a Motor6D under `transform` (how the engine composes a Motor6D).
function EmployeePoseFormulas.motor(c0: CFrame, c1: CFrame, transform: CFrame): CFrame
	return c0 * transform * c1:Inverse()
end

--[=[
	Every part reachable from `root` through `links`, placed: breadth first, each link walked forwards (a -> b) or
	backwards (b -> a). A part is placed once (the first link that reaches it wins); unreachable parts are absent.
]=]
function EmployeePoseFormulas.solve(root: number, rootFrame: CFrame, links: { Link }): { [number]: CFrame }
	local placed: { [number]: CFrame } = { [root] = rootFrame }
	local seen: { [number]: boolean } = { [root] = true }
	local byPart: { [number]: { Link } } = {}
	for _, link in links do
		byPart[link.a] = byPart[link.a] or {}
		table.insert(byPart[link.a], link)
		byPart[link.b] = byPart[link.b] or {}
		table.insert(byPart[link.b], link)
	end
	local queue = { root }
	local head = 1
	while head <= #queue do
		local part = queue[head]
		head += 1
		local frame = placed[part]
		local touching = byPart[part]
		if touching ~= nil then
			for _, link in touching do
				if link.a == part and not seen[link.b] then
					seen[link.b] = true
					placed[link.b] = frame * link.offset
					table.insert(queue, link.b)
				elseif link.b == part and not seen[link.a] then
					seen[link.a] = true
					placed[link.a] = frame * link.offset:Inverse()
					table.insert(queue, link.a)
				end
			end
		end
	end
	return placed
end

-- The world-axis box around every corner of `boxes`; nil for none.
function EmployeePoseFormulas.bounds(boxes: { Box }): Bounds?
	local low: Vector3? = nil
	local high: Vector3? = nil
	for _, box in boxes do
		local half = box.size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local corner = box.cframe:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
					low = if low == nil then corner else low:Min(corner)
					high = if high == nil then corner else high:Max(corner)
				end
			end
		end
	end
	if low == nil or high == nil then
		return nil
	end
	return { min = low, max = high }
end

return EmployeePoseFormulas
