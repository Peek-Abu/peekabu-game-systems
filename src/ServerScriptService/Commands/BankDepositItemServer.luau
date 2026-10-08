--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BankService = require(ServerScriptService.Features.Bank.BankServiceServer)
local ItemRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemRegistry)

-- A registered itemType routes to the `{ itemType }` arm — the service moves a stackable's whole
-- holding, or refuses a UNIQUE itemType with clear "move it by uid" guidance (routing a unique itemType
-- to `{ uid }` would instead surface a cryptic "no item with uid" error). Anything else is a real uid.
-- uids and itemType keys never collide, so this disambiguates the service's spec for one admin string.
local function specFor(item: string): { uid: string } | { itemType: string }
	if ItemRegistry.isValidItemType(item) then
		return { itemType = item }
	end
	return { uid = item }
end

return function(_context, target: Player, item: string)
	local success, reason = BankService:depositItem(target.UserId, specFor(item))
	if success then
		return `Deposited "{item}" into {target.Name}'s bank.`
	else
		return `Failed to deposit for {target.Name}: {reason or "unknown reason"}.`
	end
end
