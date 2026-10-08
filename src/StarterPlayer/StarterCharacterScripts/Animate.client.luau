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

local character = script.Parent
assert(character ~= nil and character:IsA("Model"), "[Animate] script must be a direct child of a character Model")

-- The Humanoid may replicate a frame after this script starts.
character:WaitForChild("Humanoid")

local unbind = AnimationLocomotionHumanoidSystem.bind(character)
if unbind ~= nil then
	local release = unbind
	character.Destroying:Connect(release)
	script.Destroying:Connect(release)
end
