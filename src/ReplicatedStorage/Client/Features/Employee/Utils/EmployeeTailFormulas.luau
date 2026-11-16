--!strict
--[=[
	EmployeeTailFormulas: the maths of an outfit's swinging coat tails (EmployeeTailSystem drives the Bones).

	A tail is a chain of links hanging from an anchor (the first Bone's rest position on LowerTorso). Each link end is
	a damped Verlet point: it keeps its own momentum, is pulled toward where the coat hangs at rest, falls a little,
	is pushed out of the leg capsules and kept above the floor, and is then put back at its link's length from the
	end before it. `transform` turns a link's new head and end into the Bone's Transform. The constants
	(EmployeeConstants.TAIL_*) were tuned offline on Prickles' clips (characters/skins/release/gloom_carnival/
	showstopper_tails/ss_pose.py runs the same rule).

	@class EmployeeTailFormulas
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)

export type Capsule = { a: Vector3, b: Vector3, radius: number }

-- One step's world: where the chain hangs from and would hang at rest, its link lengths, the leg capsules, the floor
-- height and the character's scale.
export type World = {
	anchor: Vector3,
	targets: { Vector3 },
	lengths: { number },
	capsules: { Capsule },
	floor: number,
	scale: number,
}

local EmployeeTailFormulas = {}

--[=[
	`p` moved out to the surface of the capsule from `a` to `b` (radius `radius`) when it is inside, else `p`.
]=]
function EmployeeTailFormulas.pushOut(p: Vector3, a: Vector3, b: Vector3, radius: number): Vector3
	local ab = b - a
	local lengthSquared = ab:Dot(ab)
	local t = if lengthSquared > 1e-9 then math.clamp((p - a):Dot(ab) / lengthSquared, 0, 1) else 0
	local closest = a + ab * t
	local away = p - closest
	local distance = away.Magnitude
	if distance >= radius then
		return p
	end
	local direction = if distance > 1e-6 then away / distance else Vector3.new(0, 0, 1)
	return closest + direction * radius
end

--[=[
	`x` (an end `length` from `head`) kept at or above `floor`: an end that would sink below it lies on the floor at the
	link's length, out from `head` the way it already leaned (straight back along +Z when it hung straight down). A
	head already below the floor leaves `x` alone.
]=]
function EmployeeTailFormulas.aboveFloor(x: Vector3, head: Vector3, length: number, floor: number): Vector3
	if x.Y >= floor or head.Y < floor then
		return x
	end
	local drop = head.Y - floor
	local reach = math.sqrt(math.max(length * length - drop * drop, 0))
	local flat = Vector3.new(x.X - head.X, 0, x.Z - head.Z)
	local direction = if flat.Magnitude > 1e-6 then flat.Unit else Vector3.new(0, 0, 1)
	return Vector3.new(head.X, floor, head.Z) + direction * reach
end

--[=[
	How far an end falls per step (studs) at the character's `scale`.
]=]
function EmployeeTailFormulas.gravityStep(scale: number): number
	return EmployeeConstants.TAIL_GRAVITY * scale
end

--[=[
	One TAIL_STEP of the chain: returns the new ends and the ends to remember as "previous" for the next step.
]=]
function EmployeeTailFormulas.step(points: { Vector3 }, previous: { Vector3 }, world: World): ({ Vector3 }, { Vector3 })
	local nextPoints: { Vector3 } = {}
	local fall = Vector3.new(0, -EmployeeTailFormulas.gravityStep(world.scale), 0)
	local head = world.anchor
	for i, p in points do
		local before = previous[i] or p
		local target = world.targets[i] or p
		local x = p
			+ (p - before) * (1 - EmployeeConstants.TAIL_DAMPING)
			+ (target - p) * EmployeeConstants.TAIL_STIFFNESS
			+ fall
		for _, capsule in world.capsules do
			x = EmployeeTailFormulas.pushOut(x, capsule.a, capsule.b, capsule.radius)
		end
		if x.Y < world.floor then
			x = Vector3.new(x.X, world.floor, x.Z)
		end
		local link = x - head
		local length = world.lengths[i] or link.Magnitude
		x = if link.Magnitude > 1e-6 then head + link.Unit * length else target
		x = EmployeeTailFormulas.aboveFloor(x, head, length, world.floor)
		nextPoints[i] = x
		head = x
	end
	return nextPoints, points
end

--[=[
	The Bone.Transform that carries a link from rest (the Bone's rest world CFrame `rest`, its rest end `restEnd`) to
	start at `head` and point at `tip`.
]=]
function EmployeeTailFormulas.transform(rest: CFrame, restEnd: Vector3, head: Vector3, tip: Vector3): CFrame
	local from = restEnd - rest.Position
	local to = tip - head
	local turn = CFrame.identity
	if from.Magnitude > 1e-6 and to.Magnitude > 1e-6 then
		local a, b = from.Unit, to.Unit
		local axis = a:Cross(b)
		local sine = axis.Magnitude
		if sine > 1e-6 then
			turn = CFrame.fromAxisAngle(axis / sine, math.atan2(sine, a:Dot(b)))
		elseif a:Dot(b) < 0 then
			-- straight back: any axis across the link
			local across = if math.abs(a.Y) < 0.9 then a:Cross(Vector3.yAxis).Unit else a:Cross(Vector3.xAxis).Unit
			turn = CFrame.fromAxisAngle(across, math.pi)
		end
	end
	local posed = CFrame.new(head) * turn * rest.Rotation
	return rest:Inverse() * posed
end

return EmployeeTailFormulas
