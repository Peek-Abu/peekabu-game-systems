--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BankService = require(ServerScriptService.Features.Bank.BankServiceServer)
local ItemRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemRegistry)

-- A registered itemType routes to `{ itemType }` (stackable whole-holding, or the service's clear
-- unique-must-be-by-uid refusal); anything else is a real uid — same disambiguation as DepositItemServer.
local function specFor(item: string): { uid: string } | { itemType: string }
	if ItemRegistry.isValidItemType(item) then
		return { itemType = item }
	end
	return { uid = item }
end

return function(_context, target: Player, item: string)
	local success, reason = BankService:withdrawItem(target.UserId, specFor(item))
	if success then
		return `Withdrew "{item}" from {target.Name}'s bank.`
	else
		return `Failed to withdraw for {target.Name}: {reason or "unknown reason"}.`
	end
end
