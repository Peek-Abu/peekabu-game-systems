--!strict
-- Pure visual targets; the TextButton hit area never moves.
local VM = {}
function VM.ink(hovered: boolean, pressed: boolean, focused: boolean, disabled: boolean): number
	if disabled then
		return 0
	end
	if pressed then
		return 0.18
	end
	if hovered or focused then
		return 0.08
	end
	return 0
end
export type Pose = { scale: number, tilt: number }
function VM.pose(hovered: boolean, pressed: boolean, focused: boolean, disabled: boolean, reduced: boolean): Pose
	if disabled or reduced then
		return { scale = 1, tilt = 0 }
	elseif pressed then
		return { scale = 0.965, tilt = 0.8 }
	elseif hovered or focused then
		return { scale = 1.035, tilt = -1.2 }
	end
	return { scale = 1, tilt = 0 }
end
return VM
