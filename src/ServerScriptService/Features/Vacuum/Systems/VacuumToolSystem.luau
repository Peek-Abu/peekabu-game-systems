--!strict
-- Owns a shift's server-created Tool (the hand wand). The canister backpack is not its own: every employee wears
-- one all the time (VacuumServiceServer); the Tool takes the wand off the wearer's pack while it is held and
-- clips it back when stowed or gone. Refresh tolerates delayed characters/backpacks and preserves manual stow.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local Rules = require(ReplicatedStorage.Shared.Features.Vacuum.Rules.VacuumEquipmentRules)
local ServerScriptService = game:GetService("ServerScriptService")
local Visual = require(script.Parent.VacuumVisualSystem)
local AnimationVacuumHoldSystem = require(ServerScriptService.Features.Animation.Systems.AnimationVacuumHoldSystem)
local VacuumToolSystem = {}

-- `holder` is the character it is made for: the wand is fitted to its arms (VacuumVisualSystem.build). While
-- equipped, AnimationVacuumHoldSystem holds the arms on it and `backpack` (the holder's worn canister) runs the
-- hose to it; stowed, the wand clips back onto the backpack.
function VacuumToolSystem.create(holder: Model?, backpack: Visual.WornBackpack?): Tool
	local tool = Instance.new("Tool")
	tool.Name = Constants.TOOL_NAME
	tool.ToolTip = "Hold to vacuum. Your canister stays on your back when stowed."
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute(Constants.TOOL_ATTRIBUTE, true)
	-- The wand comes off `backpack`, so it is in the pack's skin.
	local handle, plan = Visual.build(tool, holder, if backpack ~= nil then backpack.skin else nil)
	local inlet = handle:FindFirstChild("HoseInlet")
	local hold: AnimationVacuumHoldSystem.Controller? = nil
	tool:GetPropertyChangedSignal("Parent"):Connect(function()
		if hold ~= nil then
			hold.destroy()
			hold = nil
		end
		local parent = tool.Parent
		local character: Model? = if parent ~= nil
				and parent:IsA("Model")
				and parent:FindFirstChildOfClass("Humanoid") ~= nil
			then parent
			else nil
		if character ~= nil and plan ~= nil then
			hold = AnimationVacuumHoldSystem.hold(character, plan)
		end
		if backpack ~= nil then
			backpack.setHeld(if character ~= nil and inlet ~= nil and inlet:IsA("Attachment") then inlet else nil)
		end
	end)
	tool.Destroying:Connect(function()
		if hold ~= nil then
			hold.destroy()
			hold = nil
		end
		if backpack ~= nil then
			backpack.setHeld(nil)
		end
	end)
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

-- `wornFor` gives the canister backpack a character wears (putting it on if it has none yet; nil when it cannot
-- wear one). The pack outlives this controller: clearing it only puts the wand back.
function VacuumToolSystem.new(player: Player, wornFor: (character: Model) -> Visual.WornBackpack?): Controller
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
				local created = VacuumToolSystem.create(current, wornFor(current))
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
