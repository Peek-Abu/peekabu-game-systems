--!strict
--[=[
	Guard: small runtime validators for the argument checks repeated across services.

	These exist for the RUNTIME boundary — callers who reach a service through an `any` cast (tests,
	networked payloads, Cmdr args) and bypass the static types. Inside typed code the parameter is
	already the right type from the service interface, so these add no static value there; they add
	the runtime assertion (and its message) in ONE place instead of copy-pasted at every method.

	Each takes `unknown` (not `any`, so nothing type-unsafe leaks) and RETURNS the value narrowed to
	its checked type, so a caller may write `local id = Guard.userId(x)` if it wants the narrowing.

	@class Guard
]=]

local RunService = game:GetService("RunService")

local Guard = {}

--[=[
	Pure userId check for a given session. A real Roblox UserId is a positive integer; Studio's local
	"Clients and Servers" test players are -1, -2, … so in Studio a negative integer is valid too. Zero
	and fractions are never valid. Split out (like `AdminRules.isAdminForSession`) so both sessions are
	testable: the TestEZ suite runs in Studio AND on Open Cloud, where `IsStudio()` differs.
	@param value unknown -- The value to check
	@param isStudio boolean -- Whether the session is a Studio session
	@return number -- The same value, narrowed to number
]=]
function Guard.userIdForSession(value: unknown, isStudio: boolean): number
	assert(type(value) == "number", `userId must be a number, got {type(value)}`)
	assert(value == math.floor(value), `userId must be an integer, got {value}`)
	assert(
		value >= 1 or (isStudio and value <= -1),
		`userId must be a positive integer (or a negative Studio test id), got {value}`
	)
	return value
end

--[=[
	Asserts a value is a UserId: a positive integer, or in Studio also a negative test-player id.
	Throws otherwise.
	@param value unknown -- The value to check
	@return number -- The same value, narrowed to number
]=]
function Guard.userId(value: unknown): number
	return Guard.userIdForSession(value, RunService:IsStudio())
end

--[=[
	Asserts a value is a number greater than zero. Throws otherwise.
	@param value unknown -- The value to check
	@return number -- The same value, narrowed to number
]=]
function Guard.positiveAmount(value: unknown): number
	assert(
		type(value) == "number" and value > 0,
		`amount must be a positive number, got {type(value)}: {tostring(value)}`
	)
	return value
end

--[=[
	Asserts a value is a number greater than or equal to zero. Throws otherwise.
	@param value unknown -- The value to check
	@return number -- The same value, narrowed to number
]=]
function Guard.nonNegativeAmount(value: unknown): number
	assert(
		type(value) == "number" and value >= 0,
		`amount must be a non-negative number, got {type(value)}: {tostring(value)}`
	)
	return value
end

--[=[
	Validates a character slot index at the runtime boundary (a networked payload, a Cmdr arg).
	A slot index addresses a table in the profile's `slots` array, so a non-integer or out-of-range
	value must be rejected HERE — `PlayerDataPathUtils.forSlot` would otherwise build a path
	(`slots.2.5.currency`) that silently resolves to nothing.

	`maxSlots` is passed in rather than imported: Guard is shared-realm and must not depend on the
	server-only PlayerDataConstants. Callers pass `PlayerDataConstants.MAX_SLOTS`.

	@param value unknown -- The untrusted value
	@param maxSlots number -- The number of slots a profile carries
	@return number -- The validated slot index
]=]
function Guard.slotIndex(value: unknown, maxSlots: number): number
	assert(type(value) == "number", `slotIndex must be a number, got {type(value)}`)
	assert(value == math.floor(value), `slotIndex must be an integer, got {value}`)
	assert(value >= 1 and value <= maxSlots, `slotIndex must be between 1 and {maxSlots}, got {value}`)
	return value
end

return Guard
