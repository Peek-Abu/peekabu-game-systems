--!strict
local Utils = {}
function Utils.target(value: number): number
	return if value ~= value or math.abs(value) == math.huge then 0 else math.clamp(value, 0, 1)
end
function Utils.snap(current: number, target: number, reduced: boolean, reset: boolean, snapDecrease: boolean): boolean
	return reduced or reset or current == target or (snapDecrease and target < current)
end
return Utils
