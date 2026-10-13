--!strict
--[=[
	EmployeeFaceSystem: shows the server's chosen expression on an employee character, on this client.

	The face is a SurfaceAppearance on the character's FacePlate (named "Face"; AlphaMode Transparency is
	what lets the plate's empty areas show through: a MeshPart TextureID renders them black). Each employee
	carries its expressions as SurfaceAppearances in a `Faces` folder (not rendered there); showing one
	clones it onto the plate in place of the current face. The swap is client-local: the server only
	replicates the EmployeeFace attribute (EmployeeExpressionSystem), never instances.

	@class EmployeeFaceSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)

-- How long `bind` waits for a streamed-in character's face parts.
local PART_WAIT = 5

local EmployeeFaceSystem = {}

--[=[
	Puts `face` on the character's FacePlate. False when the plate or that face is missing.
]=]
function EmployeeFaceSystem.apply(character: Model, face: EmployeeRegistry.Face): boolean
	local plate = character:FindFirstChild(EmployeeConstants.FACE_PLATE)
	local faces = character:FindFirstChild(EmployeeConstants.FACES_FOLDER)
	if plate == nil or not plate:IsA("BasePart") or faces == nil then
		return false
	end
	local source = faces:FindFirstChild(face)
	if source == nil or not source:IsA("SurfaceAppearance") then
		return false
	end
	local current = plate:FindFirstChild(EmployeeConstants.FACE_APPEARANCE)
	if current ~= nil and current:GetAttribute(EmployeeConstants.FACE_ATTRIBUTE) == face then
		return true
	end
	local copy = source:Clone()
	copy.Name = EmployeeConstants.FACE_APPEARANCE
	copy:SetAttribute(EmployeeConstants.FACE_ATTRIBUTE, face)
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
	Shows the character's EmployeeFace attribute now and whenever it changes. Unknown values are ignored
	(the authored face stays).
	@return () -> () -- stops following
]=]
function EmployeeFaceSystem.bind(character: Model): () -> ()
	local released = false
	local function refresh()
		if released then
			return
		end
		local face: EmployeeRegistry.Face? = EmployeeRegistry.toFace(character:GetAttribute(EmployeeConstants.FACE_ATTRIBUTE))
		if face ~= nil then
			EmployeeFaceSystem.apply(character, face)
		end
	end
	local connection = character:GetAttributeChangedSignal(EmployeeConstants.FACE_ATTRIBUTE):Connect(refresh)
	if
		character:FindFirstChild(EmployeeConstants.FACE_PLATE) ~= nil
		and character:FindFirstChild(EmployeeConstants.FACES_FOLDER) ~= nil
	then
		refresh()
	else
		-- A streamed character can arrive before its face parts.
		task.spawn(function()
			character:WaitForChild(EmployeeConstants.FACE_PLATE, PART_WAIT)
			character:WaitForChild(EmployeeConstants.FACES_FOLDER, PART_WAIT)
			refresh()
		end)
	end
	return function()
		released = true
		connection:Disconnect()
	end
end

return EmployeeFaceSystem
