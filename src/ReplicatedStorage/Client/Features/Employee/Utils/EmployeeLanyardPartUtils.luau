--!strict
--[=[
	EmployeeLanyardPartUtils: the small helpers every lanyard piece is built with: number triples to Vector3 / Color3,
	and `quiet` (a worn part that never collides, queries, touches, casts a shadow or weighs anything). Split out of
	EmployeeLanyardSystem.

	@class EmployeeLanyardPartUtils
]=]

local EmployeeLanyardPartUtils = {}

function EmployeeLanyardPartUtils.v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

function EmployeeLanyardPartUtils.rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

function EmployeeLanyardPartUtils.quiet(part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
end

return EmployeeLanyardPartUtils
