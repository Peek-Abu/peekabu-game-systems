--!strict
--[=[
	RequestHandler: middleware for inbound client requests.

	Wraps ByteNet packet handlers with:
	- a per-player TOKEN BUCKET per action: `maxRequests` is the bucket size, refilled at
	  `maxRequests / windowSeconds` tokens per second. Constant time and allocation-free per call (one
	  bucket per (player, action), created on first use).
	- validation that may also DECODE: a validator's optional third return is passed to the handler as
	  its third argument, so a packet is decoded once.
	- an optional custom `clock` (seconds) the bucket refills by. The character uplink uses the send time
	  written in each packet, so a backlog released after a stall pays for itself instead of reading as a
	  flood. Elapsed time is never negative: a clock that moves backwards (or reads NaN) refills nothing.
	  A clock that throws rejects the packet.
	- `onReject = "count"` for high-rate packets: drops are counted per (player, action) for the Debugger
	  instead of logging a warning each. The default, "warn", logs one warning per drop.
	- audit logging (optional) and `xpcall` isolation of the handler.

	Order: rate limit, then validate — a flood of invalid requests is capped before validation runs.
	EXCEPT with a custom `clock`: the clock reads the packet, which only validation proves well-formed,
	so validation runs first and an invalid packet costs no token.

	Typing: `HandlerConfig<T, D>` accepts the existing two-return validators unchanged (D is then
	unconstrained and the handler's third argument is nil). Luau's inference does NOT check that a
	validator's third return and the handler's third parameter agree, so a decoding caller annotates both
	against one named type (see ReplicationUplinkReceiver).

	Usage:
	```lua
	MyEvents.packets.BuyItem.listen(function(data, player)
		if player then onBuyItem(data, player) end
	end)
	local onBuyItem = RequestHandler.wrap({
		name = "BuyItem",
		rateLimit = { maxRequests = 5, windowSeconds = 10 },
		handler = function(data, player)
			return ShopService:buyItem(player.UserId, data.itemId)
		end,
	})
	```

	CONTRACT — fire-and-forget events ONLY. On a rate-limit hit or validation failure the wrapped
	handler silently returns nil to the caller; the sender is never told. That is correct for
	one-way RemoteEvent/ByteNet event handlers (all current consumers), but it must NOT back a
	request/response (query) endpoint — the client would hang on, or misread, the silent nil.
	A query wrapper needs a typed rejection channel; add a `wrapQuery` variant if that need arises.

	@class RequestHandler
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)

local log = Logger.new("RequestHandler")

local RequestHandler = {}

export type RateLimitConfig = {
	maxRequests: number, -- bucket size (the largest burst)
	windowSeconds: number, -- the bucket refills maxRequests tokens per windowSeconds
}

export type RejectMode = "warn" | "count"

export type HandlerConfig<T, D> = {
	name: string, -- action name for logging / rate limiting
	rateLimit: RateLimitConfig?,
	-- The bucket the limit is counted in, defaulting to `name`. Handlers that are ONE player action
	-- spread over several packets share a key, so the configured number is the real number: six bank
	-- packets at 20/5s each were 120/5s to a client that alternated between them.
	rateLimitKey: string?,
	-- Returns ok, an error message, and optionally the decoded request handed to `handler`.
	validate: ((data: T, player: Player) -> (boolean, string?, D?))?,
	handler: (data: T, player: Player, decoded: D?) -> ...any,
	-- Seconds the bucket refills by (default os.clock). Requires `rateLimit`. Validation runs first.
	clock: ((data: T, player: Player) -> number)?,
	onReject: RejectMode?, -- "warn" (default) logs each drop; "count" counts it for the Debugger
	audit: boolean?, -- audit-log every accepted request (default false)
}

type Bucket = {
	tokens: number,
	lastClock: number,
	capacity: number,
	refillPerSecond: number,
	customClock: boolean,
}

type Entry = {
	bucket: Bucket?,
	rejected: number,
}

-- { [userId]: { [action]: Entry } }, created on first use, dropped when the player leaves.
local entries: { [number]: { [string]: Entry } } = {}

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

Players.PlayerRemoving:Connect(function(player: Player)
	entries[player.UserId] = nil
end)

local function entryFor(userId: number, action: string): Entry
	local actions = entries[userId]
	if actions == nil then
		actions = {}
		entries[userId] = actions
	end
	local entry = actions[action]
	if entry == nil then
		entry = { bucket = nil, rejected = 0 }
		actions[action] = entry
	end
	return entry
end

-- The (user, action) bucket, created full on first use.
local function bucketFor(entry: Entry, config: RateLimitConfig, now: number, customClock: boolean): Bucket
	local existing = entry.bucket
	if existing ~= nil then
		return existing
	end
	local created: Bucket = {
		tokens = config.maxRequests,
		lastClock = now,
		capacity = config.maxRequests,
		refillPerSecond = config.maxRequests / config.windowSeconds,
		customClock = customClock,
	}
	entry.bucket = created
	return created
end

--[=[
	Takes one token at `now` (seconds on the bucket's clock). Elapsed time is only ever added when positive,
	so a clock that steps back (or is NaN) refills nothing and the last reading is kept.
]=]
local function takeToken(entry: Entry, config: RateLimitConfig, now: number, customClock: boolean): boolean
	local bucket = bucketFor(entry, config, now, customClock)
	local elapsed = now - bucket.lastClock
	if elapsed > 0 then
		bucket.tokens = math.min(bucket.capacity, bucket.tokens + elapsed * bucket.refillPerSecond)
		bucket.lastClock = now
	end
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

--[=[
	Wraps a handler with rate limiting, validation (and decoding), audit logging and isolation.
	@param config HandlerConfig<T, D>
	@return (data: T, player: Player) -> any -- the wrapped handler
]=]
function RequestHandler.wrap<T, D>(config: HandlerConfig<T, D>): (data: T, player: Player) -> any
	assert(type(config) == "table", `config must be a table, got {type(config)}`)
	assert(type(config.name) == "string", `config.name must be a string, got {type(config.name)}`)
	assert(type(config.handler) == "function", `config.handler must be a function, got {type(config.handler)}`)
	if config.validate ~= nil then
		assert(type(config.validate) == "function", `config.validate must be a function, got {type(config.validate)}`)
	end
	if config.rateLimit then
		assertRateLimitConfig(config.rateLimit)
	end
	if config.clock ~= nil then
		assert(type(config.clock) == "function", `config.clock must be a function, got {type(config.clock)}`)
		assert(config.rateLimit ~= nil, "config.clock needs config.rateLimit (it only drives the bucket)")
	end
	assert(
		config.onReject == nil or config.onReject == "warn" or config.onReject == "count",
		`config.onReject must be "warn" or "count", got {tostring(config.onReject)}`
	)

	local name = config.name
	local bucketKey = config.rateLimitKey or name
	local rateLimit = config.rateLimit
	local validate = config.validate
	local clock = config.clock
	local handler = config.handler
	local counting = config.onReject == "count"
	local audit = config.audit == true

	-- One closure per wrap (not per call): the reject path for both drop kinds.
	local function reject(userId: number, rateLimited: boolean, message: string?)
		if counting then
			entryFor(userId, name).rejected += 1
		elseif rateLimited then
			log:warn("Rate limited:", name, "userId:", userId)
		else
			log:warn("Validation failed:", name, "userId:", userId, "error:", message or "unknown")
		end
	end

	return function(data: T, player: Player)
		local userId = player.UserId
		local decoded: D? = nil

		if clock ~= nil and rateLimit ~= nil then
			-- The clock reads packet bytes: validate first, so it only ever sees a well-formed packet.
			if validate ~= nil then
				local ok, message, value = validate(data, player)
				if not ok then
					reject(userId, false, message)
					return nil
				end
				decoded = value
			end
			-- #32: the clock reads packet bytes, so it can throw on a packet only validation vouched for. A throw
			-- rejects THIS packet (counted like a validation reject) instead of escaping the ByteNet listener.
			local clockOk, clockNow = pcall(clock, data, player)
			if not clockOk then
				reject(userId, false, `clock error: {clockNow}`)
				return nil
			end
			if not takeToken(entryFor(userId, bucketKey), rateLimit, clockNow, true) then
				reject(userId, true, nil)
				return nil
			end
		else
			if rateLimit ~= nil and not takeToken(entryFor(userId, bucketKey), rateLimit, os.clock(), false) then
				reject(userId, true, nil)
				return nil
			end
			if validate ~= nil then
				local ok, message, value = validate(data, player)
				if not ok then
					reject(userId, false, message)
					return nil
				end
				decoded = value
			end
		end

		-- Audit logging: the dedicated audit level, payload serialized so the line shows its contents.
		if audit then
			local ok, encoded = pcall(function()
				return HttpService:JSONEncode(data)
			end)
			log:audit("Audit:", name, "userId:", userId, "data:", ok and encoded or tostring(data))
		end

		-- The handler and its arguments go straight to xpcall: no closure per call.
		local success, result = xpcall(handler, debug.traceback, data, player, decoded)
		if not success then
			log:error("Handler error:", name, "userId:", userId, "error:", result)
			return nil
		end
		return result
	end
end

--[=[
	A standalone limiter for services that check a rate manually (same token bucket, os.clock).
	Check-AND-consume: each call that returns true takes a token. Call it once per logical request.
	@param actionName string
	@param config RateLimitConfig
	@return (userId: number) -> boolean
]=]
function RequestHandler.createRateLimiter(actionName: string, config: RateLimitConfig): (userId: number) -> boolean
	assert(type(actionName) == "string", `actionName must be a string, got {type(actionName)}`)
	assertRateLimitConfig(config)
	return function(userId: number): boolean
		return takeToken(entryFor(userId, actionName), config, os.clock(), false)
	end
end

--[=[
	One row of the rate-limit dump. `tokensRemaining` / `capacity` are nil for an action that has no
	rate limit and only counts drops (`onReject = "count"`).
]=]
export type RateLimitEntry = {
	userId: number,
	action: string,
	tokensRemaining: number?,
	capacity: number?,
	rejected: number,
}

-- Tokens as of now. A custom-clock bucket reports what it holds (this dump cannot read its clock).
local function tokensNow(bucket: Bucket): number
	if bucket.customClock then
		return bucket.tokens
	end
	local elapsed = os.clock() - bucket.lastClock
	if elapsed <= 0 then
		return bucket.tokens
	end
	return math.min(bucket.capacity, bucket.tokens + elapsed * bucket.refillPerSecond)
end

--[=[
	Every tracked (user, action): tokens left, bucket size, drops. Read-only introspection for the F4
	debugger's rate-limit rows.
	@return { RateLimitEntry }
]=]
function RequestHandler.getAllRateLimitStatus(): { RateLimitEntry }
	local result: { RateLimitEntry } = {}
	for userId, actions in entries do
		for action, entry in actions do
			local bucket = entry.bucket
			table.insert(result, {
				userId = userId,
				action = action,
				tokensRemaining = if bucket ~= nil then tokensNow(bucket) else nil,
				capacity = if bucket ~= nil then bucket.capacity else nil,
				rejected = entry.rejected,
			})
		end
	end
	return result
end

--[=[
	Resets one action's state for a player, or all of the player's state when `actionName` is nil.
	@param userId number
	@param actionName string?
]=]
function RequestHandler.resetRateLimit(userId: number, actionName: string?)
	if actionName then
		local actions = entries[userId]
		if actions then
			actions[actionName] = nil
		end
	else
		entries[userId] = nil
	end
end

--[=[
	One (user, action)'s bucket for debugging. Always returns a table.
	@param userId number
	@param actionName string
	@return { tokensRemaining: number?, capacity: number?, rejected: number }
]=]
function RequestHandler.getRateLimitStatus(
	userId: number,
	actionName: string
): { tokensRemaining: number?, capacity: number?, rejected: number }
	local actions = entries[userId]
	local entry = actions and actions[actionName]
	if entry == nil then
		return { tokensRemaining = nil, capacity = nil, rejected = 0 }
	end
	local bucket = entry.bucket
	return {
		tokensRemaining = if bucket ~= nil then tokensNow(bucket) else nil,
		capacity = if bucket ~= nil then bucket.capacity else nil,
		rejected = entry.rejected,
	}
end

return RequestHandler
