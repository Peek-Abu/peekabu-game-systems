--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local CurrencyService = require(ServerScriptService.Services.CurrencyService.CurrencyServiceServer)

return function(context, target: Player, currencyType: string, amount: number)
	local success = CurrencyService:addCurrency(target.UserId, currencyType :: any, amount)
	
	if success then
		return `Successfully added {amount} {currencyType} to {target.Name}.`
	else
		return `Failed to add currency to {target.Name}. Ensure currency type is valid.`
	end
end
