--!strict
--[=[
	ToonFaceSystem: shows the server's chosen expression on a toon character, on this client.

	The face is a SurfaceAppearance on the character's FacePlate (named "Face"; AlphaMode Transparency is
	what lets the plate's empty areas show through: a MeshPart TextureID renders them black). Each toon
	carries its expressions as SurfaceAppearances in a `Faces` folder (not rendered there); showing one
	clones it onto the plate in place of the current face. The swap is client-local: the server only
	replicates the ToonFace attribute (ToonExpressionSystem), never instances.

	@class ToonFaceSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToonConstants = require(ReplicatedStorage.Shared.Features.Toon.Data.ToonConstants)
local ToonRegistry = require(ReplicatedStorage.Shared.Features.Toon.Data.ToonRegistry)

-- How long `bind` waits for a streamed-in character's face parts.
local PART_WAIT = 5

local ToonFaceSystem = {}

--[=[
	Puts `face` on the character's FacePlate. False when the plate or that face is missing.
]=]
function ToonFaceSystem.apply(character: Model, face: ToonRegistry.Face): boolean
	local plate = character:FindFirstChild(ToonConstants.FACE_PLATE)
	local faces = character:FindFirstChild(ToonConstants.FACES_FOLDER)
	if plate == nil or not plate:IsA("BasePart") or faces == nil then
		return false
	end
	local source = faces:FindFirstChild(face)
	if source == nil or not source:IsA("SurfaceAppearance") then
		return false
	end
	local current = plate:FindFirstChild(ToonConstants.FACE_APPEARANCE)
	if current ~= nil and current:GetAttribute(ToonConstants.FACE_ATTRIBUTE) == face then
		return true
	end
	local copy = source:Clone()
	copy.Name = ToonConstants.FACE_APPEARANCE
	copy:SetAttribute(ToonConstants.FACE_ATTRIBUTE, face)
	-- A part renders one SurfaceAppearance: clear every other one before the new face goes on.
	for _, child in plate:GetChildren() do
		if child:IsA("SurfaceAppearance") then
			child:Destroy()
		end
	end
	copy.Parent = plate
	return true
end

--[=[
	Shows the character's ToonFace attribute now and whenever it changes. Unknown values are ignored
	(the authored face stays).
	@return () -> () -- stops following
]=]
function ToonFaceSystem.bind(character: Model): () -> ()
	local released = false
	local function refresh()
		if released then
			return
		end
		local face: ToonRegistry.Face? = ToonRegistry.toFace(character:GetAttribute(ToonConstants.FACE_ATTRIBUTE))
		if face ~= nil then
			ToonFaceSystem.apply(character, face)
		end
	end
	local connection = character:GetAttributeChangedSignal(ToonConstants.FACE_ATTRIBUTE):Connect(refresh)
	if
		character:FindFirstChild(ToonConstants.FACE_PLATE) ~= nil
		and character:FindFirstChild(ToonConstants.FACES_FOLDER) ~= nil
	then
		refresh()
	else
		-- A streamed character can arrive before its face parts.
		task.spawn(function()
			character:WaitForChild(ToonConstants.FACE_PLATE, PART_WAIT)
			character:WaitForChild(ToonConstants.FACES_FOLDER, PART_WAIT)
			refresh()
		end)
	end
	return function()
		released = true
		connection:Disconnect()
	end
end

return ToonFaceSystem
