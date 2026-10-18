--!strict
--[=[
	QueuePlaceRules: which mode this server runs in, which role it plays, and how a party reaches a role.
	Pure: the role table comes in as an argument (QueueRegistry.roles()).

	Studio, or a PlaceId the table does not know, is "local": every role runs in this one server and a
	teleport becomes a move, so the whole loop plays through rojo serve. A destination whose PlaceId is
	still the placeholder is reached by a local move even from a live server.

	@class QueuePlaceRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QueueConstants = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueConstants)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)

type Roles = { [string]: number }

local QueuePlaceRules = {}

-- The role `placeId` plays, or nil (unknown, or an unpublished place's 0).
function QueuePlaceRules.roleOf(placeId: number, roles: Roles): string?
	if placeId == QueueConstants.PLACEHOLDER_PLACE_ID then
		return nil
	end
	for role, id in roles do
		if id == placeId then
			return role
		end
	end
	return nil
end

function QueuePlaceRules.mode(placeId: number, isStudio: boolean, forceLive: boolean, roles: Roles): QueueTypes.Mode
	if forceLive then
		return "live"
	end
	if isStudio or QueuePlaceRules.roleOf(placeId, roles) == nil then
		return "local"
	end
	return "live"
end

-- How a party reaches `destination`, or nil and why.
function QueuePlaceRules.route(mode: QueueTypes.Mode, destination: string, roles: Roles): (QueueTypes.Route?, string?)
	local placeId = roles[destination]
	if placeId == nil then
		return nil, `role "{destination}" is not registered`
	end
	if mode == "local" or placeId == QueueConstants.PLACEHOLDER_PLACE_ID then
		return { kind = "local" }, nil
	end
	return { kind = "teleport", placeId = placeId }, nil
end

-- Whether this server runs `role` (a game builds that role's world only where this is true).
function QueuePlaceRules.runsRole(mode: QueueTypes.Mode, currentRole: string?, role: string): boolean
	return mode == "local" or currentRole == role
end

-- A server reached through ReserveServer: a private server id and no owner (a VIP server has one).
function QueuePlaceRules.isReservedServer(privateServerId: string, privateServerOwnerId: number): boolean
	return privateServerId ~= "" and privateServerOwnerId == 0
end

return QueuePlaceRules
