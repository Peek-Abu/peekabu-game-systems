--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SignalTyped = require(ReplicatedStorage.Shared.Modules.SignalTyped)

--[=[
	@prop Changed SignalTyped.Signal<string, number, number>
	Fired when any currency value changes — (currencyType, newAmount, delta), where delta is
	positive for a gain and negative for a spend.
]=]
local CurrencySignals: { Changed: SignalTyped.Signal<string, number, number> } = {
	Changed = SignalTyped.new(),
}

return CurrencySignals
