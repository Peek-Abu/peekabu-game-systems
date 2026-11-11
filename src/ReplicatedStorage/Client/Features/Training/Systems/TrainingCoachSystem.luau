--!strict
--[=[
	TrainingCoachSystem: the coach at the hub's Training pad on this client (owner 11-11: an NPC with a purpose; it
	replaces the floating "New here?" sign). While this player still needs training, Pippa stands beside each Training
	pad on the side facing the hub, waving (EmployeePoseRegistry's `wave`: a portrait pose, never a per-character
	animation). She carries no billboard: what she says is the on-screen coach card (TrainingHubSystem's spotlight
	step, "New here? Start training!", with the edge arrow and the gold floor trail leading to the pad), because text
	floating in the world swings around as the camera moves (owner 11-11). Once they have trained she is gone for them
	(the pad keeps its plain TRAINING tag, so anyone can play it again). Built locally (EmployeePortraitSystem.build: an
	anchored, inert posed copy), so nothing replicates and nobody else sees another player's coach.

	Spec-exempt shell (Instances, the portrait build); the decision is the specced TrainingRules.isNew.

	@class TrainingCoachSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local EmployeePoseRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeePoseRegistry)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local EmployeePortraitSystem = require(ReplicatedStorage.Client.Features.Employee.Systems.EmployeePortraitSystem)

local COACH = TrainingConstants.HUB_COACH

-- The coach built beside each pad (this client only).
local coaches: { [BasePart]: Model? } = {}

local function characterSource(): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local crew = if assets ~= nil then assets:FindFirstChild("CleanupCrew") else nil
	local characters = if crew ~= nil then crew:FindFirstChild("Characters") else nil
	local source = if characters ~= nil then characters:FindFirstChild(COACH.EMPLOYEE) else nil
	return if source ~= nil and source:IsA("Model") then source else nil
end

local function build(pad: BasePart): Model?
	local source = characterSource()
	local set = EmployeePoseRegistry.get(COACH.EMPLOYEE)
	if source == nil or set == nil then
		return nil
	end
	local coach = EmployeePortraitSystem.build(source, set.poses[COACH.POSE], false)
	if coach == nil then
		return nil
	end
	coach.Name = "TrainingCoach"
	-- Beside the pad on the side the hub is on (COACH.SIDE in the pad's space), facing out of the bay.
	local base = pad.CFrame * CFrame.new(COACH.SIDE)
	local feet = Vector3.new(base.Position.X, pad.Position.Y - pad.Size.Y / 2, base.Position.Z)
	local facing = pad.CFrame:VectorToWorldSpace(COACH.FACING)
	coach:PivotTo(CFrame.lookAt(feet, feet + Vector3.new(facing.X, 0, facing.Z)))
	local frame, size = coach:GetBoundingBox()
	coach:PivotTo(coach:GetPivot() + Vector3.new(0, feet.Y - (frame.Position.Y - size.Y / 2), 0))
	coach.Parent = Workspace
	return coach
end

local TrainingCoachSystem = {}

-- Shows (or removes) the coach at `pad` for a player who still needs training (`isNew`).
function TrainingCoachSystem.set(pad: BasePart, isNew: boolean)
	if not isNew then
		TrainingCoachSystem.remove(pad)
		return
	end
	if coaches[pad] == nil then
		local coach = build(pad)
		if coach ~= nil then
			coaches[pad] = coach
		end
	end
end

-- Takes the coach at `pad` away (the pad left, or the player trained).
function TrainingCoachSystem.remove(pad: BasePart)
	local coach: Model? = coaches[pad]
	if coach == nil then
		return
	end
	coaches[pad] = nil
	coach:Destroy()
end

-- Whether a coach stands at `pad`.
function TrainingCoachSystem.has(pad: BasePart): boolean
	return coaches[pad] ~= nil
end

return TrainingCoachSystem
