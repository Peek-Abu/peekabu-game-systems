--!strict
--[=[
	VacuumBodyUtils: reads the holder's visible chest for the vacuum hold (owner plan A, 2026-11-16: every guard used to
	measure the bare UpperTorso, and Cappy's hoodie is a separate piece round a thin torso part).

	- `wornOn`: the visible pieces worn on a body part: parts jointed or welded to it that are not body parts themselves
	  (those are the character's own children), not the held Tool's and not the vacuum's backpack.
	- `chestBox`: the UpperTorso and everything worn on it, as one box in the UpperTorso's own frame
	  (VacuumBodyFormulas.box).

	@class VacuumBodyUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local VacuumBodyFormulas = require(ReplicatedStorage.Shared.Features.Vacuum.Utils.VacuumBodyFormulas)

local VacuumBodyUtils = {}

function VacuumBodyUtils.wornOn(character: Model, bodyPart: BasePart, tool: Instance?): { BasePart }
	local found: { BasePart } = {}
	local pack = character:FindFirstChild(VacuumConstants.BACKPACK_NAME)
	for _, joint in character:GetDescendants() do
		local a: Instance?, b: Instance? = nil, nil
		if joint:IsA("JointInstance") or joint:IsA("WeldConstraint") then
			a, b = joint.Part0, joint.Part1
		end
		local other = if a == bodyPart then b elseif b == bodyPart then a else nil
		if
			other ~= nil
			and other:IsA("BasePart")
			and other.Transparency < 1
			and other.Parent ~= character
			and (tool == nil or not other:IsDescendantOf(tool))
			and (pack == nil or not other:IsDescendantOf(pack))
			and table.find(found, other) == nil
		then
			table.insert(found, other)
		end
	end
	return found
end

function VacuumBodyUtils.chestBox(character: Model, chest: BasePart, tool: Instance?): VacuumBodyFormulas.Box
	local pieces: { VacuumBodyFormulas.Piece } = { { at = CFrame.identity, size = chest.Size } }
	for _, worn in VacuumBodyUtils.wornOn(character, chest, tool) do
		table.insert(pieces, { at = chest.CFrame:ToObjectSpace(worn.CFrame), size = worn.Size })
	end
	return VacuumBodyFormulas.box(pieces)
end

return VacuumBodyUtils
