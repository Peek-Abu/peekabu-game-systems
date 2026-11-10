--!strict
--[=[
	TrainingFinishViewModel: how the training finish screen's composition fits the window. The screen is laid out in
	px on a design canvas (`canvas`: 1920x1080 desktop, 844x390 phone), but the area the HUD really has is often
	smaller: a laptop held at the HUD's readable minimum scale, Studio's short play pane, or a phone smaller than the
	phone design (owner, 11-10: the employee's feet were cut off at the bottom). `fit` scales the canvas down (never
	up) to fit `area` (the HUD's virtual viewport, design px) and centres it. Pure.

	@class TrainingFinishViewModel
]=]

local DESKTOP = Vector2.new(1920, 1080)
local PHONE = Vector2.new(844, 390)

export type Fit = { scale: number, offset: Vector2 }

local TrainingFinishViewModel = {}

function TrainingFinishViewModel.canvas(phone: boolean): Vector2
	return if phone then PHONE else DESKTOP
end

function TrainingFinishViewModel.fit(area: Vector2, phone: boolean): Fit
	local canvas = TrainingFinishViewModel.canvas(phone)
	if area.X <= 0 or area.Y <= 0 then
		return { scale = 1, offset = Vector2.zero }
	end
	local scale = math.min(1, area.X / canvas.X, area.Y / canvas.Y)
	return { scale = scale, offset = (area - canvas * scale) / 2 }
end

return TrainingFinishViewModel
