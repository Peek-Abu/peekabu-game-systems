--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local CurrencyEvents = require(ReplicatedStorage.Shared.Events.CurrencyEvents)
local CurrencyUtils = require(ReplicatedStorage.Shared.Modules.Utils.CurrencyUtils)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService.PlayerDataServiceServer)
local CurrencyConstants = require(ReplicatedStorage.Shared.Modules.Constants.CurrencyConstants)
local PlayerDataConstants = require(ServerScriptService.Modules.Constants.PlayerDataConstants)

PlayerDataConstants.registerProfilePath("currency", {
	gold = 100,
	gems = 10,
})

local log = Logger.new("CurrencyServiceServer")

local CurrencyServiceServer = {}
CurrencyServiceServer.dependencies = { "PlayerDataServiceServer" } :: { string }

--[=[
	Initializes the CurrencyServiceServer and validates type synchronization.
	@param self CurrencyServiceServer -- The service instance
]=]
function CurrencyServiceServer.init(_self: CurrencyServiceServer)
	-- Validate CurrencyType union matches CURRENCIES table
	local validTypes = CurrencyConstants.getValidCurrencies()
	local expectedTypes = {"gold", "gems"} -- Must match CurrencyType union in CurrencyConstants.luau

	assert(
		#validTypes == #expectedTypes,
		`[CurrencyServiceServer] CurrencyType union is out of sync with CURRENCIES table. ` ..
		`CURRENCIES has {#validTypes} type(s), CurrencyType union has {#expectedTypes}. ` ..
		`Update CurrencyType in CurrencyConstants.luau to match.`
	)

	for _, currencyType in validTypes do
		local found = false
		for _, expectedType in expectedTypes do
			if currencyType == expectedType then
				found = true
				break
			end
		end
		if not found then
			error(
				`[CurrencyServiceServer] Currency "{currencyType}" exists in CURRENCIES ` ..
				`but is missing from CurrencyType union in CurrencyConstants.luau.`
			)
		end
	end

	log:debug("CurrencyType validation passed")
end

--[=[
	Gets the currency data for a specified user.
	@param userId number -- The user ID to get currency for
	@return PlayerDataTypes.Currency? -- The currency data or nil if not found
]=]
function CurrencyServiceServer:getCurrency(userId: number): PlayerDataTypes.Currency?
	assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)

	local profile = PlayerDataService:getProfile(userId)
	return profile and profile.currency
end

--[=[
	Gets a specific currency amount for a user.
	@param userId number -- The user ID
	@param currencyType CurrencyConstants.CurrencyType -- The currency type ("gold", etc.)
	@return number -- The amount of that currency
]=]
function CurrencyServiceServer:getCurrencyAmount(userId: number, currencyType: CurrencyConstants.CurrencyType): number
	assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)
	assert(CurrencyConstants.isValidCurrencyType(currencyType), `invalid currency type: "{currencyType}"`)

	return CurrencyUtils.getCurrencyAmount(self:getCurrency(userId), currencyType)
end

--[=[
	Checks if a player has enough of a specific currency.
	@param userId number -- The user ID
	@param currencyType CurrencyConstants.CurrencyType -- The currency type ("gold", etc.)
	@param amount number -- The amount to check for
	@return boolean -- True if the player has enough, false otherwise
]=]
function CurrencyServiceServer:hasCurrency(
	userId: number,
	currencyType: CurrencyConstants.CurrencyType,
	amount: number
): boolean
	assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)
	assert(CurrencyConstants.isValidCurrencyType(currencyType), `invalid currency type: "{currencyType}"`)
	assert(type(amount) == "number" and amount > 0, `amount must be a positive number, got {type(amount)}: {amount}`)

	return CurrencyUtils.hasEnoughCurrency(self:getCurrency(userId), currencyType, amount)
end

--[=[
	Adds currency to a player's account.
	@param userId number -- The user ID
	@param currencyType CurrencyConstants.CurrencyType -- The currency type ("gold", etc.)
	@param amount number -- The amount to add
	@return boolean -- True if successful, false otherwise
]=]
function CurrencyServiceServer:addCurrency(
	userId: number,
	currencyType: CurrencyConstants.CurrencyType,
	amount: number
): boolean
	assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)
	assert(CurrencyConstants.isValidCurrencyType(currencyType), `invalid currency type: "{currencyType}"`)
	assert(type(amount) == "number" and amount > 0, `amount must be a positive number, got {type(amount)}: {amount}`)

	local newAmount = 0
	local mutated = PlayerDataService:mutate(userId, "currency", function(currency: PlayerDataTypes.Currency)
		local oldAmount = currency[currencyType] or 0
		newAmount = math.min(oldAmount + amount, CurrencyConstants.MAX_CURRENCY)
		
		if newAmount == oldAmount then
			return false -- No change due to cap
		end
		
		currency[currencyType] = newAmount
		return true
	end)

	if not mutated then
		return false
	end

	-- Broadcast the change
	self:broadcastCurrencyUpdate(userId, currencyType, newAmount, amount)

	return true
end

--[=[
	Removes currency from a player's account.
	@param userId number -- The user ID
	@param currencyType CurrencyConstants.CurrencyType -- The currency type ("gold", etc.)
	@param amount number -- The amount to remove
	@return boolean -- True if successful, false otherwise
]=]
function CurrencyServiceServer:removeCurrency(
	userId: number,
	currencyType: CurrencyConstants.CurrencyType,
	amount: number
): boolean
	assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)
	assert(CurrencyConstants.isValidCurrencyType(currencyType), `invalid currency type: "{currencyType}"`)
	assert(type(amount) == "number" and amount > 0, `amount must be a positive number, got {type(amount)}: {amount}`)

	local newAmount = 0
	local mutated = PlayerDataService:mutate(userId, "currency", function(currency: PlayerDataTypes.Currency)
		local oldAmount = currency[currencyType] or 0
		if oldAmount < amount then
			return false
		end
		newAmount = oldAmount - amount
		currency[currencyType] = newAmount
		return true
	end)

	if not mutated then
		return false
	end

	-- Broadcast the change
	self:broadcastCurrencyUpdate(userId, currencyType, newAmount, -amount)

	return true
end

--[=[
	Sets a specific currency amount for a player.
	@param userId number -- The user ID
	@param currencyType CurrencyConstants.CurrencyType -- The currency type ("gold", etc.)
	@param amount number -- The amount to set
	@return boolean -- True if successful, false otherwise
]=]
function CurrencyServiceServer:setCurrency(
	userId: number,
	currencyType: CurrencyConstants.CurrencyType,
	amount: number
): boolean
	assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)
	assert(CurrencyConstants.isValidCurrencyType(currencyType), `invalid currency type: "{currencyType}"`)
	assert(
		type(amount) == "number" and amount >= 0,
		`amount must be a non-negative number, got {type(amount)}: {amount}`
	)

	local delta = 0
	local mutated = PlayerDataService:mutate(userId, "currency", function(currency: PlayerDataTypes.Currency)
		local oldAmount = currency[currencyType] or 0
		if oldAmount == amount then
			return false -- No change needed
		end
		delta = amount - oldAmount
		currency[currencyType] = amount
		return true
	end)

	if not mutated then
		return false
	end

	-- Broadcast the change
	self:broadcastCurrencyUpdate(userId, currencyType, amount, delta)
	return true
end

--[=[
	Broadcasts currency changes to the specified player.
	@param userId number -- The user ID of the player
	@param currencyType CurrencyConstants.CurrencyType -- The type of currency that changed
	@param newAmount number -- The new total amount
	@param delta number -- The change amount (positive for add, negative for remove)
]=]
function CurrencyServiceServer:broadcastCurrencyUpdate(
	userId: number,
	currencyType: CurrencyConstants.CurrencyType,
	newAmount: number,
	delta: number
)
	assert(type(userId) == "number", `userId must be a number, got {type(userId)}`)
	assert(CurrencyConstants.isValidCurrencyType(currencyType), `invalid currency type: "{currencyType}"`)
	assert(type(newAmount) == "number", `newAmount must be a number, got {type(newAmount)}`)
	assert(type(delta) == "number", `delta must be a number, got {type(delta)}`)

	local player = Players:GetPlayerByUserId(userId)
	if player then
		CurrencyEvents.packets.CurrencyUpdate.sendTo({
			currencyType = currencyType,
			newAmount = newAmount,
			delta = delta,
		}, player)
	end
end

--[=[
	Returns the current state of the service for debugging.
	@return { [string]: any } -- Service state
]=]
function CurrencyServiceServer:getState(): { [string]: any }
	return {
		note = "Currency data is stored in PlayerDataServiceServer profiles. Use PlayerDataServiceServer:getState() to inspect.",
	}
end

type CurrencyServiceServer = typeof(CurrencyServiceServer)

return CurrencyServiceServer :: CurrencyServiceServer
