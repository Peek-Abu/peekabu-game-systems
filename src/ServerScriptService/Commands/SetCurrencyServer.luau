--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CurrencyService = require(ServerScriptService.Services.CurrencyService.CurrencyServiceServer)
local CurrencyConstants = require(ReplicatedStorage.Shared.Modules.Constants.CurrencyConstants)

-- `currencyType` is a custom Cmdr arg type (see AdminServiceServer), so Cmdr only ever passes a
-- validated currency — the param is a real CurrencyType, no cast needed.
return function(_context, target: Player, currencyType: CurrencyConstants.CurrencyType, amount: number)
	-- Report on the OBSERVED result, not setCurrency's boolean: that boolean is `false` both when the
	-- profile isn't loaded AND when the value was already the target (a no-op), so it can't tell the
	-- two apart. Reading the stored value back distinguishes them — and reports the clamped value, not
	-- the raw input.
	CurrencyService:setCurrency(target.UserId, currencyType, amount)

	local currency = CurrencyService:getCurrency(target.UserId)
	if currency == nil then
		return `Failed to set currency — {target.Name}'s profile isn't loaded.`
	end
	return `Set {target.Name}'s {currencyType} to {currency[currencyType] or 0}.`
end
