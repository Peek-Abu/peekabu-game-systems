--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SignalTyped = require(ReplicatedStorage.Shared.Modules.SignalTyped)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)

--[=[
	@prop Changed SignalTyped.Signal<string, PlayerDataTypes.InventoryItem>
	Fired when inventory changes — (action, item), where action is "add", "update", or "remove".
]=]
local InventorySignals: { Changed: SignalTyped.Signal<string, PlayerDataTypes.InventoryItem> } = {
	Changed = SignalTyped.new(),
}

return InventorySignals
