--!strict
--[=[
	Animate: the character's locomotion entry point.

	⚠ THE NAME IS LOAD-BEARING. The engine auto-inserts its default Animate script into any character
	that lacks a script named "Animate" — this script existing under that exact name is what suppresses
	the stock one. Rename it and every character grows a second, engine-owned animator.

	Thin by design: every decision (pose selection, fades, speed scales, the kill switch) lives in the
	specced AnimationLocomotionSystem core, bound to this character's Humanoid by
	AnimationLocomotionHumanoidSystem. This script only owns the lifetime: StarterCharacterScripts runs a
	fresh copy per character, and the binding is released when the character goes.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationLocomotionHumanoidSystem =
	require(ReplicatedStorage.Client.Features.Animation.Systems.AnimationLocomotionHumanoidSystem)
local CrouchConstants = require(ReplicatedStorage.Shared.Features.Crouch.Data.CrouchConstants)
local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeLocomotionUtils = require(ReplicatedStorage.Client.Features.Employee.Utils.EmployeeLocomotionUtils)

local character = script.Parent
assert(character ~= nil and character:IsA("Model"), "[Animate] script must be a direct child of a character Model")

-- The Humanoid may replicate a frame after this script starts.
character:WaitForChild("Humanoid")

-- An employee character (Cleanup Crew) plays its own idle/walk/run when its EmployeeRegistry entry has
-- them; the server stamps the attribute on the StarterCharacter template, so it is here at spawn.
local config = EmployeeLocomotionUtils.forName(character:GetAttribute(EmployeeConstants.NAME_ATTRIBUTE))
-- Crouched (the server's Crouching attribute): the employee's crouch idle / walk.
local unbind =
	AnimationLocomotionHumanoidSystem.bind(character, config, { crouchAttribute = CrouchConstants.CROUCHING_ATTRIBUTE })
if unbind ~= nil then
	local release = unbind
	character.Destroying:Connect(release)
	script.Destroying:Connect(release)
end
