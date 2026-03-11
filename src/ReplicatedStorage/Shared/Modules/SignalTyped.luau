--!strict
--[=[
	SignalTyped: a typed factory for SignalPlus.

	SignalPlus's constructor returns an unparameterized `Signal<>`, so a direct
	`Signal() :: Signal<T...>` cast is rejected by the analyzer as "unrelated". This wraps that
	single boundary cast in a generic `new<T...>()`, so call sites infer the parameter types from
	context and stay fully typed and any-free.

	Usage (the target's type drives inference — no cast needed):
		local Changed: SignalTyped.Signal<string, number> = SignalTyped.new()

	@class SignalTyped
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)

export type Signal<T...> = Signal.Signal<T...>
export type Connection = Signal.Connection

local SignalTyped = {}

--[=[
	Creates a new signal whose fired/listened parameters are `T...`.
	@return Signal<T...>
]=]
function SignalTyped.new<T...>(): Signal<T...>
	-- The one boundary cast: SignalPlus's constructor is typed `() -> Signal<>`, so bridge it to
	-- the requested parameter pack.
	return (Signal() :: any) :: Signal<T...>
end

return SignalTyped
