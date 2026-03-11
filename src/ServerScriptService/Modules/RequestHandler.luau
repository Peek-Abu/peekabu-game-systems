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
local HttpService = game:GetService("HttpService")

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
	handler: (data: T, player: Player) -> ...any, -- The actual handler (may return nothing, as ByteNet event listeners do)
	audit: boolean?, -- Enable audit logging (default: false)
}

--[=[
	Asserts a rate-limit config has sane values. Fails fast on developer error.
	@param config RateLimitConfig -- The rate limit configuration to validate
]=]
local function assertRateLimitConfig(config: RateLimitConfig)
	assert(type(config) == "table", `rateLimit must be a table, got {type(config)}`)
	assert(
		type(config.maxRequests) == "number" and config.maxRequests > 0,
		`rateLimit.maxRequests must be a positive number, got {type(config.maxRequests)}: {tostring(config.maxRequests)}`
	)
	assert(
		type(config.windowSeconds) == "number" and config.windowSeconds > 0,
		`rateLimit.windowSeconds must be a positive number, got {type(config.windowSeconds)}: {tostring(
			config.windowSeconds
		)}`
	)
end

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
	assert(type(config) == "table", `config must be a table, got {type(config)}`)
	assert(type(config.name) == "string", `config.name must be a string, got {type(config.name)}`)
	assert(type(config.handler) == "function", `config.handler must be a function, got {type(config.handler)}`)
	if config.validate ~= nil then
		assert(type(config.validate) == "function", `config.validate must be a function, got {type(config.validate)}`)
	end
	if config.rateLimit then
		assertRateLimitConfig(config.rateLimit)
	end

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

		-- Audit logging. Use the dedicated audit level and serialize the payload so the line
		-- shows its contents rather than a "table: 0x..." address.
		if config.audit then
			local ok, encoded = pcall(function()
				return HttpService:JSONEncode(data)
			end)
			log:audit("Audit:", config.name, "userId:", userId, "data:", ok and encoded or tostring(data))
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

	NOTE: the returned function is check-AND-consume — each call that returns `true` records a
	request against the window. Call it at most once per logical request.

	@param actionName string -- The action name
	@param config RateLimitConfig -- Rate limit configuration
	@return (userId: number) -> boolean -- Returns true (and consumes a slot) if allowed
]=]
function RequestHandler.createRateLimiter(actionName: string, config: RateLimitConfig): (userId: number) -> boolean
	assert(type(actionName) == "string", `actionName must be a string, got {type(actionName)}`)
	assertRateLimitConfig(config)

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
	Gets current rate-limit status for debugging. Always returns a table.

	Pass `windowSeconds` for a live count that excludes expired timestamps; omit it for the raw
	stored count (which may include entries that expired since the last wrapped call, because
	pruning otherwise only happens inside checkRateLimit).

	@param userId number -- The player's user ID
	@param actionName string -- The action name
	@param windowSeconds number? -- Optional window to prune expired timestamps against
	@return { requestsInWindow: number } -- Number of recorded requests
]=]
function RequestHandler.getRateLimitStatus(
	userId: number,
	actionName: string,
	windowSeconds: number?
): { requestsInWindow: number }
	local actions = rateLimitData[userId]
	local timestamps = actions and actions[actionName]
	if not timestamps then
		return { requestsInWindow = 0 }
	end

	if windowSeconds == nil then
		return { requestsInWindow = #timestamps }
	end

	local windowStart = os.clock() - windowSeconds
	local count = 0
	for _, timestamp in timestamps do
		if timestamp > windowStart then
			count += 1
		end
	end
	return { requestsInWindow = count }
end

return RequestHandler
