--!strict
local Rules = {}
function Rules.canReach(actor: Vector3, target: Vector3, feetY: number, topY: number, range: number): boolean
	return Vector3.new(actor.X - target.X, 0, actor.Z - target.Z).Magnitude <= range
		and math.abs(target.Y - actor.Y) <= 8
		and feetY <= topY + 2
end
return Rules
