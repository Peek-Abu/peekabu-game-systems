--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local CurrencyEvents = require(ReplicatedStorage.Shared.Events.CurrencyEvents)
local CurrencySignals = require(ReplicatedStorage.Client.Signals.CurrencySignals)
local CurrencyUtils = require(ReplicatedStorage.Shared.Modules.Utils.CurrencyUtils)
local CurrencyConstants = require(ReplicatedStorage.Shared.Modules.Constants.CurrencyConstants)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local PlayerDataServiceClient = require(ReplicatedStorage.Client.Services.PlayerDataService.PlayerDataServiceClient)

local log = Logger.new("CurrencyServiceClient")

local CurrencyServiceClient = {}
CurrencyServiceClient.dependencies = { "PlayerDataServiceClient" } :: { string }

local janitor = Janitor.new()

--[=[
	Initializes the CurrencyServiceClient and sets up event listeners.
	@param self CurrencyServiceClient -- The service instance
]=]
function CurrencyServiceClient.init(_self: CurrencyServiceClient)
	-- Listen to network events from server (server is authoritative, no validation needed)
	janitor:Add(CurrencyEvents.packets.CurrencyUpdate.listen(function(data)
		-- Delegate mutation to PlayerDataServiceClient (centralized ownership)
		local mutated = PlayerDataServiceClient:mutate("currency", function(currency: PlayerDataTypes.Currency)
			currency[data.currencyType] = data.newAmount
			return true
		end)

		-- Fire signal if mutation succeeded (UI subscribes to CurrencySignals.Changed)
		if mutated then
			CurrencySignals.Changed:Fire(data.currencyType, data.newAmount, data.delta)
		end

		-- Log the change for debugging
		if data.delta > 0 then
			log:debug(string.format("Gained %d %s (total: %d)", data.delta, data.currencyType, data.newAmount))
		elseif data.delta < 0 then
			log:debug(string.format("Spent %d %s (total: %d)", math.abs(data.delta), data.currencyType, data.newAmount))
		end
	end))
end

--[=[
	Cleans up event listeners when the service is stopped.
	@param self CurrencyServiceClient -- The service instance
]=]
function CurrencyServiceClient.stop(_self: CurrencyServiceClient)
	janitor:Cleanup()
	log:debug("Service stopped, connections cleaned up")
end

--[=[
	Gets the local player's currency data.
	@return PlayerDataTypes.Currency? -- The currency data or nil if not loaded
]=]
function CurrencyServiceClient:getCurrency(): PlayerDataTypes.Currency?
	local profile = PlayerDataServiceClient:getProfile()
	return profile and profile.currency
end

--[=[
	Gets a specific currency amount for the local player.
	@param currencyType string -- The currency type
	@return number -- The amount of that currency
]=]
function CurrencyServiceClient:getCurrencyAmount(currencyType: string): number
	assert(type(currencyType) == "string", `currencyType must be a string, got {type(currencyType)}`)
	assert(CurrencyConstants.isValidCurrencyType(currencyType), `invalid currency type: "{currencyType}"`)
	return CurrencyUtils.getCurrencyAmount(self:getCurrency(), currencyType)
end

--[=[
	Checks if the local player has enough of a specific currency.
	@param currencyType string -- The currency type
	@param amount number -- The amount to check for
	@return boolean -- True if the player has enough, false otherwise
]=]
function CurrencyServiceClient:hasCurrency(currencyType: string, amount: number): boolean
	assert(type(currencyType) == "string", `currencyType must be a string, got {type(currencyType)}`)
	assert(CurrencyConstants.isValidCurrencyType(currencyType), `invalid currency type: "{currencyType}"`)
	assert(type(amount) == "number" and amount > 0, `amount must be a positive number, got {type(amount)}: {amount}`)
	return CurrencyUtils.hasEnoughCurrency(self:getCurrency(), currencyType, amount)
end

--[=[
	Formats a currency amount for display.
	@param amount number -- The amount to format
	@param currencyType string? -- Optional currency type for icon/suffix
	@return string -- The formatted currency string
]=]
function CurrencyServiceClient:formatCurrency(amount: number, currencyType: string?): string
	assert(type(amount) == "number", `amount must be a number, got {type(amount)}`)
	return CurrencyUtils.formatCurrency(amount, currencyType)
end

--[=[
	Returns the current state of the service for debugging.
	@return { [string]: any } -- Service state
]=]
function CurrencyServiceClient:getState(): { [string]: any }
	local currency = self:getCurrency()
	return {
		hasCurrency = currency ~= nil,
		currency = currency,
	}
end

type CurrencyServiceClient = typeof(CurrencyServiceClient)
return CurrencyServiceClient :: CurrencyServiceClient
