--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local BankService = require(ServerScriptService.Features.Bank.BankServiceServer)
local CurrencyConstants = require(ReplicatedStorage.Shared.Features.Currency.Data.CurrencyConstants)

-- `currencyType` is a custom Cmdr arg type (see AdminServiceServer), so Cmdr only ever passes a
-- validated currency — the param is a real CurrencyType, no cast needed (same as AddCurrencyServer).
return function(_context, target: Player, currencyType: CurrencyConstants.CurrencyType, amount: number)
	local success, reason = BankService:withdrawCurrency(target.UserId, currencyType, amount)
	if success then
		return `Withdrew {amount} {currencyType} from {target.Name}'s bank.`
	else
		return `Failed to withdraw currency for {target.Name}: {reason or "unknown reason"}.`
	end
end
