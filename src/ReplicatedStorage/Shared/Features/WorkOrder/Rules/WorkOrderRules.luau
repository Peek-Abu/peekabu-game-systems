--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local Registry = require(ReplicatedStorage.Shared.Features.WorkOrder.Data.WorkOrderRegistry)
local Rules = {}
local function whole(value: number): boolean
	return type(value) == "number" and value >= 0 and value < math.huge and value == math.floor(value)
end
function Rules.validate(state: PlayerDataTypes.WorkOrder): (boolean, string?)
	if not whole(state.day) or not whole(state.progress) or type(state.claimed) ~= "boolean" then
		return false, "work order requires a finite day, progress and claimed flag"
	end
	local target = Registry.orderFor(state.day * 86400).target
	if state.progress > target or (state.claimed and state.progress ~= target) then
		return false, "work order progress must match its target before claiming"
	end
	return true, nil
end
function Rules.roll(state: PlayerDataTypes.WorkOrder, now: number): PlayerDataTypes.WorkOrder
	local day = Registry.dayIndex(now)
	if state.day ~= day then
		return { day = day, progress = 0, claimed = false }
	end
	return table.clone(state)
end
function Rules.feedback(before: number, after: number, claimed: boolean, order: Registry.WorkOrder): string?
	if after <= before then
		return nil
	end
	if claimed then
		return `TODAY'S JOB DONE • +{Registry.REWARD_CREDITS} Credits`
	end
	local halfway = math.ceil(order.target / 2)
	if before == 0 or (before < halfway and after >= halfway) then
		return `Today's job: {after}/{order.target}`
	end
	return nil
end
return Rules
