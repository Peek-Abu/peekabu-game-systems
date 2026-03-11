--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CurrencyService = require(ServerScriptService.Services.CurrencyService.CurrencyServiceServer)
local CurrencyConstants = require(ReplicatedStorage.Shared.Modules.Constants.CurrencyConstants)

-- `currencyType` is a custom Cmdr arg type (see AdminServiceServer), so Cmdr only ever passes a
-- validated currency — the param is a real CurrencyType, no cast needed.
return function(_context, target: Player, currencyType: CurrencyConstants.CurrencyType, amount: number)
	-- Report what actually happened by observing before/after, not addCurrency's boolean (which is
	-- `false` both when the profile isn't loaded AND when the add was fully absorbed by the
	-- MAX_CURRENCY cap — the old "ensure currency type is valid" message was misleading since Cmdr
	-- already validated the type).
	local loaded = CurrencyService:getCurrency(target.UserId) ~= nil
	local before = CurrencyService:getCurrencyAmount(target.UserId, currencyType)
	CurrencyService:addCurrency(target.UserId, currencyType, amount)

	if not loaded then
		return `Failed to add currency — {target.Name}'s profile isn't loaded.`
	end
	local after = CurrencyService:getCurrencyAmount(target.UserId, currencyType)
	if after == before then
		return `{target.Name} is already at the {currencyType} cap ({after}); nothing added.`
	end
	return `Added {after - before} {currencyType} to {target.Name} (now {after}).`
end
