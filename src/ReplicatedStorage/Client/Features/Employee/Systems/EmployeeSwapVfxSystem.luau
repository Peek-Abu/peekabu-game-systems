--!strict
--[=[
	EmployeeSwapVfxSystem: the goo puff a swapped character steps out of, on every client (EmployeeVfxConstants,
	through VfxBurstSystem). The server marks a character it rebuilt in place (a depot employee or skin change) with
	EmployeeConstants.SWAP_ATTRIBUTE; EmployeeServiceClient calls `play` for each new character carrying it.

	Spec-exempt shell (VfxBurstSystem, live characters); the preset is specced in EmployeeVfxConstants.

	@class EmployeeSwapVfxSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VfxBurstRegistry = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxBurstRegistry)
local EmployeeVfxConstants = require(ReplicatedStorage.Client.Features.Employee.Data.EmployeeVfxConstants)
local VfxBurstSystem = require(ReplicatedStorage.Client.Features.Vfx.Systems.VfxBurstSystem)

-- Registered at load: VfxBurstSystem refuses an unknown burst.
for id, preset in EmployeeVfxConstants.PRESETS do
	if not VfxBurstRegistry.has(id) then
		VfxBurstRegistry.register(id, preset)
	end
end

local EmployeeSwapVfxSystem = {}

local played = 0

-- Plays the puff at the character's feet once it has been placed.
function EmployeeSwapVfxSystem.play(character: Model)
	task.delay(EmployeeVfxConstants.SWAP_SETTLE, function()
		local root = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if character.Parent == nil or root == nil or not root:IsA("BasePart") or humanoid == nil then
			return
		end
		if not VfxBurstSystem.polished() then
			return
		end
		played += 1
		local feet = root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
		VfxBurstSystem.play("employeeSwapGoo", feet)
	end)
end

function EmployeeSwapVfxSystem.played(): number
	return played
end

return EmployeeSwapVfxSystem
