--!strict
--[=[
	CameraFadeFormulas: how see-through the camera subject's character is for a camera `distance` studs from its head
	(CameraFadeSystem, CameraServiceClient).

	Opaque at `far` and beyond, hidden at `near` and inside, linear between. The tuning (CameraConstants.FADE_NEAR /
	FADE_FAR) keeps this at least the engine's own fade at every distance, so the two never disagree visibly.

	@class CameraFadeFormulas
]=]

local CameraFadeFormulas = {}

--[=[
	The LocalTransparencyModifier (0 opaque .. 1 hidden) for a camera `distance` studs from the subject's head.
]=]
function CameraFadeFormulas.transparency(distance: number, near: number, far: number): number
	if distance >= far then
		return 0
	elseif distance <= near then
		return 1
	end
	return (far - distance) / (far - near)
end

return CameraFadeFormulas
