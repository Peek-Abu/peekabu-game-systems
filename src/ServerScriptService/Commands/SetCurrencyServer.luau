--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local CurrencyService = require(ServerScriptService.Services.CurrencyService.CurrencyServiceServer)

return function(context, target: Player, currencyType: string, amount: number)
	local success = CurrencyService:setCurrency(target.UserId, currencyType :: any, amount)
	
	if success then
		return `Successfully set {target.Name}'s {currencyType} to {amount}.`
	else
		return `Failed to set currency for {target.Name}.`
	end
end
