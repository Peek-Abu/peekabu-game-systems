--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)

local InventorySignals = {}

--[=[
	Fired when inventory changes.
	@param action string -- "add", "update", or "remove"
	@param item PlayerDataTypes.InventoryItem -- The item that changed
]=]
InventorySignals.Changed = Signal() :: Signal.Signal<string, PlayerDataTypes.InventoryItem>

return InventorySignals
