--!strict
--[=[
	DepotPlaceSender: the places menu's two requests (p1-places-menu): `pick` sends a truck host's place pick
	(DepotEvents.PickMap) and `buy` a place bought with Credits (DepotEvents.BuyPlace). The server decides both
	(DepotMapSystem, DepotPlaceSystem); the menu sees the result in the synced pick and `places` slice. Its own module
	so the places menu (DepotBoardScreen, under DepotServiceClient's scene) can send without requiring the service.
	Thin ByteNet shell (spec-exempt).

	@class DepotPlaceSender
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotEvents = require(ReplicatedStorage.Shared.Features.Depot.Net.DepotEvents)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)

local DepotPlaceSender = {}

-- The host picks `map` for the truck they are aboard (the server checks they host it and own the place).
function DepotPlaceSender.pick(map: ShiftTypes.MapId)
	DepotEvents.packets.PickMap.send(map)
end

-- Buys `map` with Credits (the server checks the price and the balance).
function DepotPlaceSender.buy(map: ShiftTypes.MapId)
	DepotEvents.packets.BuyPlace.send(map)
end

return DepotPlaceSender
