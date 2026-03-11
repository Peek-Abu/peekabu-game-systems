--!strict
--[=[
	RequestHandler: Middleware for rate limiting and request validation.
	
	Wraps ByteNet packet handlers with:
	- Per-player rate limiting
	- Request validation
	- Audit logging (optional)
	
	Usage:
	```lua
	local RequestHandler = require(path.to.RequestHandler)
	
	-- Instead of:
	MyEvents.packets.BuyItem.listen(function(data, player)
		ShopService:buyItem(player.UserId, data.itemId)
	end)
	
	-- Use:
	MyEvents.packets.BuyItem.listen(RequestHandler.wrap({
		name = "BuyItem",
		rateLimit = { maxRequests = 5, windowSeconds = 10 },
		handler = function(data, player)
			return ShopService:buyItem(player.UserId, data.itemId)
		end,
	}))
	```
	
	@class RequestHandler
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Modules.Logger)

local log = Logger.new("RequestHandler")

local RequestHandler = {}

--[=[
	Rate limit tracking per player per action.
	Structure: { [userId]: { [actionName]: { timestamps } } }
]=]
local rateLimitData: { [number]: { [string]: { number } } } = {}

--[=[
	Configuration for rate limiting.
]=]
export type RateLimitConfig = {
	maxRequests: number, -- Max requests allowed in window
	windowSeconds: number, -- Time window in seconds
}

--[=[
	Configuration for a wrapped request handler.
]=]
export type HandlerConfig<T> = {
	name: string, -- Action name for logging/rate limiting
	rateLimit: RateLimitConfig?, -- Optional rate limit config
	validate: ((data: T, player: Player) -> (boolean, string?))?, -- Optional validator
	handler: (data: T, player: Player) -> any, -- The actual handler
	audit: boolean?, -- Enable audit logging (default: false)
}

--[=[
	Cleans up rate limit data for a player when they leave.
]=]
local function onPlayerRemoving(player: Player)
	rateLimitData[player.UserId] = nil
end

Players.PlayerRemoving:Connect(onPlayerRemoving)

--[=[
	Checks if a request is within rate limits.
	@param userId number -- The player's user ID
	@param actionName string -- The action being rate limited
	@param config RateLimitConfig -- Rate limit configuration
	@return boolean -- True if allowed, false if rate limited
]=]
local function checkRateLimit(userId: number, actionName: string, config: RateLimitConfig): boolean
	local now = os.clock()
	local windowStart = now - config.windowSeconds

	-- Initialize tracking tables
	if not rateLimitData[userId] then
		rateLimitData[userId] = {}
	end
	if not rateLimitData[userId][actionName] then
		rateLimitData[userId][actionName] = {}
	end

	local timestamps = rateLimitData[userId][actionName]

	-- Remove expired timestamps
	local validTimestamps = {}
	for _, timestamp in timestamps do
		if timestamp > windowStart then
			table.insert(validTimestamps, timestamp)
		end
	end
	rateLimitData[userId][actionName] = validTimestamps

	-- Check if under limit
	if #validTimestamps >= config.maxRequests then
		return false
	end

	-- Record this request
	table.insert(validTimestamps, now)
	return true
end

--[=[
	Wraps a handler with rate limiting, validation, and audit logging.
	
	**Preventing Type Erasure:**
	Because this wrapper passes data from ByteNet into your function dynamically, Luau may lose type inference. 
	To preserve full autocomplete and strict typing, manually cast the `data` parameter in your handler:
	```lua
	MyEvents.packets.BuyItem.listen(RequestHandler.wrap({
		name = "BuyItem",
		handler = function(data: typeof(MyEvents.packets.BuyItem.struct), player: Player)
			-- 'data' is now fully typed!
		end
	}))
	```
	
	@param config HandlerConfig<T> -- Handler configuration
	@return (data: T, player: Player) -> any -- Wrapped handler function
]=]
function RequestHandler.wrap<T>(config: HandlerConfig<T>): (data: T, player: Player) -> any
	return function(data: T, player: Player)
		local userId = player.UserId

		-- Rate limiting
		if config.rateLimit then
			if not checkRateLimit(userId, config.name, config.rateLimit) then
				log:warn("Rate limited:", config.name, "userId:", userId)
				return nil -- Silently drop rate-limited requests
			end
		end

		-- Validation
		if config.validate then
			local isValid, errorMsg = config.validate(data, player)
			if not isValid then
				log:warn("Validation failed:", config.name, "userId:", userId, "error:", errorMsg or "unknown")
				return nil
			end
		end

		-- Audit logging
		if config.audit then
			log:info("Audit:", config.name, "userId:", userId, "data:", data)
		end

		-- Execute handler
		local success, result = xpcall(function()
			return config.handler(data, player)
		end, debug.traceback)

		if not success then
			log:error("Handler error:", config.name, "userId:", userId, "error:", result)
			return nil
		end

		return result
	end
end

--[=[
	Creates a rate limiter for a specific action without the full wrap.
	Useful for manual rate limit checks in services.
	
	@param actionName string -- The action name
	@param config RateLimitConfig -- Rate limit configuration
	@return (userId: number) -> boolean -- Function that returns true if allowed
]=]
function RequestHandler.createRateLimiter(actionName: string, config: RateLimitConfig): (userId: number) -> boolean
	return function(userId: number): boolean
		return checkRateLimit(userId, actionName, config)
	end
end

--[=[
	Manually resets rate limit data for a player/action.
	Useful for testing or admin commands.
	
	@param userId number -- The player's user ID
	@param actionName string? -- Optional action name (resets all if nil)
]=]
function RequestHandler.resetRateLimit(userId: number, actionName: string?)
	if actionName then
		if rateLimitData[userId] then
			rateLimitData[userId][actionName] = nil
		end
	else
		rateLimitData[userId] = nil
	end
end

--[=[
	Gets current rate limit status for debugging.
	
	@param userId number -- The player's user ID
	@param actionName string -- The action name
	@return { requestsInWindow: number, windowSeconds: number }?
]=]
function RequestHandler.getRateLimitStatus(userId: number, actionName: string): { requestsInWindow: number }?
	if not rateLimitData[userId] or not rateLimitData[userId][actionName] then
		return { requestsInWindow = 0 }
	end
	return { requestsInWindow = #rateLimitData[userId][actionName] }
end

return RequestHandler
