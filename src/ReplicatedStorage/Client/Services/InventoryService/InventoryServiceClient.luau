--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Modules.Logger)
local InventoryEvents = require(ReplicatedStorage.Shared.Events.InventoryEvents)
local InventorySignals = require(ReplicatedStorage.Client.Signals.InventorySignals)
local InventoryUtils = require(ReplicatedStorage.Shared.Modules.Utils.InventoryUtils)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Types.PlayerDataTypes)
local PlayerDataServiceClient = require(ReplicatedStorage.Client.Services.PlayerDataService.PlayerDataServiceClient)

local log = Logger.new("InventoryServiceClient")

local InventoryServiceClient = {}
InventoryServiceClient.dependencies = { "PlayerDataServiceClient" } :: { string }

local janitor = Janitor.new()

--[=[
	Initializes the InventoryServiceClient and sets up event listeners.
	@param _self InventoryServiceClient -- The service instance
]=]
function InventoryServiceClient.init(_self: InventoryServiceClient)
	-- Listen to single item delta events from server
	janitor:Add(InventoryEvents.packets.InventoryDelta.listen(function(data)
		local action = data.action
		local item = data.item

		-- Delegate mutation to PlayerDataServiceClient (centralized ownership)
		local mutated = PlayerDataServiceClient:mutate(
			"inventory",
			function(inventory: { PlayerDataTypes.InventoryItem })
				if action == "add" or action == "update" then
					InventoryUtils.add(inventory, item)
				elseif action == "remove" then
					InventoryUtils.remove(inventory, item)
				end
				return true
			end
		)

		-- Fire signal if mutation succeeded (UI subscribes to InventorySignals.Changed)
		if mutated then
			InventorySignals.Changed:Fire(action, item)
		end

		log:debug("Inventory changed:", action, item.itemType)
	end))

	-- Listen to batch delta events from server
	janitor:Add(InventoryEvents.packets.InventoryBatchDelta.listen(function(data)
		local added = data.added
		local removed = data.removed
		local updated = data.updated

		-- Delegate mutation to PlayerDataServiceClient (centralized ownership)
		local mutated = PlayerDataServiceClient:mutate(
			"inventory",
			function(inventory: { PlayerDataTypes.InventoryItem })
				for _, item in added do
					InventoryUtils.add(inventory, item)
				end
				for _, item in removed do
					InventoryUtils.remove(inventory, item)
				end
				for _, item in updated do
					InventoryUtils.add(inventory, item) -- add handles updates for existing items
				end
				return true
			end
		)

		-- Fire signals for each change (UI subscribes to InventorySignals.Changed)
		if mutated then
			for _, item in added do
				InventorySignals.Changed:Fire("add", item)
			end
			for _, item in removed do
				InventorySignals.Changed:Fire("remove", item)
			end
			for _, item in updated do
				InventorySignals.Changed:Fire("update", item)
			end
		end

		log:debug("Inventory batch changed: added", #added, "removed", #removed, "updated", #updated)
	end))
end

--[=[
	Cleans up event listeners when the service is stopped.
	@param self InventoryServiceClient -- The service instance
]=]
function InventoryServiceClient.stop(_self: InventoryServiceClient)
	janitor:Cleanup()
	log:debug("Service stopped, connections cleaned up")
end

--[=[
	Gets the local player's inventory.
	@return {PlayerDataTypes.InventoryItem} -- Array of inventory items
]=]
function InventoryServiceClient:getInventory(): { PlayerDataTypes.InventoryItem }
	local profile = PlayerDataServiceClient:getProfile()
	return (profile and profile.inventory) or {}
end

--[=[
	Returns the current state of the service for debugging.
	@return { [string]: any } -- Service state
]=]
function InventoryServiceClient:getState(): { [string]: any }
	local inventory = self:getInventory()
	return {
		itemCount = #inventory,
		items = inventory,
	}
end

type InventoryServiceClient = typeof(InventoryServiceClient)

return InventoryServiceClient :: InventoryServiceClient
