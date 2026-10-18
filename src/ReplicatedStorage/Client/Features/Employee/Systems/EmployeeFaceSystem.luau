--!strict
--[=[
	EmployeeFaceSystem: shows the server's chosen expression on an employee character, on this client.

	The face is a SurfaceAppearance on the character's FacePlate (named "Face"; AlphaMode Transparency is
	what lets the plate's empty areas show through: a MeshPart TextureID renders them black). Each employee
	carries its expressions as SurfaceAppearances in a `Faces` folder (not rendered there); showing one
	clones it onto the plate in place of the current face. The swap is client-local: the server only
	replicates the EmployeeFace attribute (EmployeeExpressionSystem), never instances, so `bind` re-applies
	it whenever the engine re-replicates the plate (streaming) or the face set.

	@class EmployeeFaceSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeRegistry)

local EmployeeFaceSystem = {}

--[=[
	Puts `face` on the character's FacePlate. False when the plate or that face is missing.
	@param force Rebuild even when that face is already showing (the face set changed under it).
]=]
function EmployeeFaceSystem.apply(character: Model, face: EmployeeRegistry.Face, force: boolean?): boolean
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
	if force ~= true and current ~= nil and current:GetAttribute(EmployeeConstants.FACE_ATTRIBUTE) == face then
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
	Shows the character's EmployeeFace attribute now and whenever it changes, and puts it back whenever the
	engine re-replicates what the face sits on:
	- a `Faces` folder arrives (a skin swapped the set, EmployeeSkinSystem; or it streamed in late);
	- a SurfaceAppearance this system did not make lands on the FacePlate. The swap is client-local, so the
	  server's plate still wears the authored face: with StreamingEnabled another player's FacePlate streams
	  out and back in as a fresh copy of it (the authored face, not the one the attribute names), and a
	  character can arrive before its plate. Nothing changes the attribute then, so without this the client
	  keeps showing the authored face while the owner, whose character never streams out, sees the real one.
	Unknown values are ignored (the authored face stays).
	@return () -> () -- stops following
]=]
function EmployeeFaceSystem.bind(character: Model): () -> ()
	local released = false
	local function show(force: boolean)
		if released then
			return
		end
		local face: EmployeeRegistry.Face? =
			EmployeeRegistry.toFace(character:GetAttribute(EmployeeConstants.FACE_ATTRIBUTE))
		if face ~= nil then
			EmployeeFaceSystem.apply(character, face, force)
		end
	end
	local connection = character:GetAttributeChangedSignal(EmployeeConstants.FACE_ATTRIBUTE):Connect(function()
		show(false)
	end)
	local arrived = character.DescendantAdded:Connect(function(descendant: Instance)
		local parent = descendant.Parent
		local isFaces = descendant.Name == EmployeeConstants.FACES_FOLDER and parent == character
		local isForeignFace = descendant:IsA("SurfaceAppearance")
			and parent ~= nil
			and parent.Name == EmployeeConstants.FACE_PLATE
			and parent.Parent == character
			and descendant:GetAttribute(EmployeeConstants.FACE_ATTRIBUTE) == nil
		if isFaces or isForeignFace then
			-- Deferred: the swap destroys the arriving appearance, which must not happen inside its own
			-- arrival, and the rest of a streamed-in subtree lands first.
			task.defer(show, true)
		end
	end)
	show(false)
	return function()
		released = true
		connection:Disconnect()
		arrived:Disconnect()
	end
end

return EmployeeFaceSystem
