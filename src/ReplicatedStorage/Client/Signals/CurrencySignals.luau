--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)

local CurrencySignals = {}

--[=[
	Fired when any currency value changes.
	@param currencyType string -- The currency type that changed
	@param newAmount number -- The new amount
	@param delta number -- The change amount (positive = gained, negative = spent)
]=]
CurrencySignals.Changed = Signal() :: Signal.Signal<string, number, number>

return CurrencySignals
