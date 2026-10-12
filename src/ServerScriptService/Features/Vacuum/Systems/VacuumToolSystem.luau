--!strict
-- Owns a shift's server-created Tool. Refresh tolerates delayed characters/backpacks and preserves manual stow.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local Rules = require(ReplicatedStorage.Shared.Features.Vacuum.Rules.VacuumEquipmentRules)
local Visual = require(script.Parent.VacuumVisualSystem)
local VacuumToolSystem = {}

function VacuumToolSystem.create(): Tool
	local tool = Instance.new("Tool")
	tool.Name = Constants.TOOL_NAME
	tool.ToolTip = "Hold to vacuum. Your canister stays with you when stowed."
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute(Constants.TOOL_ATTRIBUTE, true)
	Visual.build(tool)
	return tool
end

function VacuumToolSystem.isEquipped(character: Model?): boolean
	if character == nil then
		return false
	end
	local tool = character:FindFirstChild(Constants.TOOL_NAME)
	return tool ~= nil and tool:IsA("Tool") and tool:GetAttribute(Constants.TOOL_ATTRIBUTE) == true
end

export type Controller = {
	refresh: (carrying: boolean) -> boolean,
	destroy: () -> (),
}

function VacuumToolSystem.new(player: Player): Controller
	local character: Model? = nil
	local tool: Tool? = nil
	local wasCarrying = false
	local resume = false
	local function clear()
		if tool ~= nil then
			tool:Destroy()
		end
		tool = nil
		character = nil
		wasCarrying = false
		resume = false
	end
	return {
		refresh = function(carrying)
			if player.Character ~= character then
				clear()
				character = player.Character
			end
			local current = character
			local humanoid = if current ~= nil then current:FindFirstChildOfClass("Humanoid") else nil
			local backpack = player:FindFirstChildOfClass("Backpack")
			if current == nil or humanoid == nil or humanoid.Health <= 0 or backpack == nil then
				return false
			end
			local first = tool == nil or tool.Parent == nil
			if first then
				if tool ~= nil then
					tool:Destroy()
				end
				local created = VacuumToolSystem.create()
				tool = created
				created.Parent = backpack
				resume = true
			end
			local owned = tool
			if owned == nil then
				return false
			end
			if carrying and not wasCarrying then
				resume = first or owned.Parent == current
				if owned.Parent == current then
					humanoid:UnequipTools()
				end
			elseif carrying and owned.Parent == current then
				-- An equip request while carrying must not put two objects into the player's hands.
				humanoid:UnequipTools()
			end
			if Rules.shouldEquip(first, wasCarrying, carrying, resume) then
				humanoid:EquipTool(owned)
			end
			wasCarrying = carrying
			return owned.Parent == current
		end,
		destroy = clear,
	}
end
return VacuumToolSystem
