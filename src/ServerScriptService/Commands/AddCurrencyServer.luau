--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CurrencyService = require(ServerScriptService.Services.CurrencyService.CurrencyServiceServer)
local CurrencyConstants = require(ReplicatedStorage.Shared.Modules.Constants.CurrencyConstants)

-- `currencyType` is a custom Cmdr arg type (see AdminServiceServer), so Cmdr only ever passes a
-- validated currency — the param is a real CurrencyType, no cast needed.
return function(_context, target: Player, currencyType: CurrencyConstants.CurrencyType, amount: number)
	local success = CurrencyService:addCurrency(target.UserId, currencyType, amount)

	if success then
		return `Successfully added {amount} {currencyType} to {target.Name}.`
	else
		return `Failed to add currency to {target.Name}. Ensure currency type is valid.`
	end
end
