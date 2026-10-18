--!strict
--[=[
	CameraFadeSystem: fades the camera subject's character from the camera's FINAL position (CameraServiceClient runs it
	each frame, after the occlusion pass, while the engine drives a third-person view).

	Why the engine's fade is not enough: the PlayerModule's TransparencyController runs inside the engine's camera update
	and measures where the engine put the camera. The occlusion pass (CameraOcclusionSystem) moves the camera afterwards,
	often to well under a stud from the head against a wall, and the engine never sees it: the character stays opaque
	and fills the screen. This writes the character's LocalTransparencyModifier from the final distance instead, on every
	BasePart and Decal under the character: its body, accessories such as the ears, and what it holds, such as the
	vacuum (the engine's fade skips anything inside a Tool).

	It writes every frame while it has something to fade (the engine's own write, which happens earlier in the frame,
	is overwritten before the frame draws, and parts added meanwhile are covered), writes 0 once when the fade ends,
	and otherwise leaves the modifier alone: another owner (a hiding spot hiding the body from its peek camera) keeps
	what it set. A faded character that stops being the subject is shown again.

	@class CameraFadeSystem
]=]

export type Fader = {
	-- The character the fade last applied to.
	character: Model?,
	-- What it last wrote (0 = nothing held).
	written: number,
}

local CameraFadeSystem = {}

local function write(character: Model, amount: number)
	for _, piece in character:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.LocalTransparencyModifier = amount
		elseif piece:IsA("Decal") then
			piece.LocalTransparencyModifier = amount
		end
	end
end

--[=[
	A fader holding nothing.
]=]
function CameraFadeSystem.new(): Fader
	return { character = nil, written = 0 }
end

--[=[
	Fades `character` (nil = no character subject) to `amount` (0 opaque .. 1 hidden) this frame.
]=]
function CameraFadeSystem.apply(fader: Fader, character: Model?, amount: number)
	local previous = fader.character
	if previous ~= character then
		if previous ~= nil and fader.written > 0 then
			write(previous, 0)
		end
		fader.character = character
		fader.written = 0
	end
	if character == nil then
		return
	end
	if amount > 0 or fader.written > 0 then
		write(character, amount)
		fader.written = amount
	end
end

--[=[
	Shows a faded character again and forgets it.
]=]
function CameraFadeSystem.release(fader: Fader)
	CameraFadeSystem.apply(fader, nil, 0)
end

return CameraFadeSystem
