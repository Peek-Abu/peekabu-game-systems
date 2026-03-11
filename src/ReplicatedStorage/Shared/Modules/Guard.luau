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

local Guard = {}

--[=[
	Asserts a value is a number (a UserId). Throws otherwise.
	@param value unknown -- The value to check
	@return number -- The same value, narrowed to number
]=]
function Guard.userId(value: unknown): number
	assert(type(value) == "number", `userId must be a number, got {type(value)}`)
	return value
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

return Guard
