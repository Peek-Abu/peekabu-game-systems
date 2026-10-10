--!strict
--[=[
	QueueRegistry: the place-role table. Which PlaceId plays which role (a game's "depot" and "shift",
	any strings). A game registers its roles at load, from server code; the base registers none.

	A role whose place does not exist yet registers QueueConstants.PLACEHOLDER_PLACE_ID (0): it is
	reached by a local move until the real PlaceId is filled in. Example, in a game's server Data:

		QueueRegistry.register("depot", 1234567890)
		QueueRegistry.register("shift", QueueConstants.PLACEHOLDER_PLACE_ID) -- PLACEHOLDER: create the place, then fill in its PlaceId

	@class QueueRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QueueConstants = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueConstants)

local places: { [string]: number } = {}

local QueueRegistry = {}

--[=[
	Registers `role` as played by `placeId`. Errors on an empty or duplicate role, a PlaceId that is not a
	whole number >= 0, or a real PlaceId already playing another role.
]=]
function QueueRegistry.register(role: string, placeId: number)
	assert(role ~= "", "queue role must not be empty")
	assert(places[role] == nil, `queue role "{role}" is already registered`)
	assert(
		placeId >= 0 and placeId == math.floor(placeId),
		`queue role "{role}": PlaceId must be a whole number >= 0, got {placeId}`
	)
	if placeId ~= QueueConstants.PLACEHOLDER_PLACE_ID then
		for other, id in places do
			assert(id ~= placeId, `PlaceId {placeId} already plays role "{other}"`)
		end
	end
	places[role] = placeId
end

function QueueRegistry.has(role: string): boolean
	return places[role] ~= nil
end

function QueueRegistry.placeOf(role: string): number?
	return places[role]
end

-- A frozen copy of the whole table, for the pure QueuePlaceRules.
function QueueRegistry.roles(): { [string]: number }
	return table.freeze(table.clone(places))
end

return QueueRegistry
