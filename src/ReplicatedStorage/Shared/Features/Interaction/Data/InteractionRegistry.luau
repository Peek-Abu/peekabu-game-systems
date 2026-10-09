--!strict
--[=[
	InteractionRegistry: the interaction kinds by id (the ItemRegistry contract: validated, loud at boot,
	no re-registration). The kind a tagged object names through its InteractionKind attribute.

	@class InteractionRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InteractionTypes = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionTypes)

type InteractionDef = InteractionTypes.InteractionDef

local kinds: { [string]: InteractionDef } = {}

local InteractionRegistry = {}

--[=[
	Registers a kind. Asserts: the id is new; actionText is non-empty; holdDuration and cooldown are not
	negative; maxDistance is positive.
]=]
function InteractionRegistry.register(id: string, def: InteractionDef)
	assert(kinds[id] == nil, `interaction kind "{id}" is already registered`)
	assert(type(def.actionText) == "string" and def.actionText ~= "", `interaction "{id}": actionText is required`)
	local hold = def.holdDuration
	if hold ~= nil then
		assert(hold >= 0, `interaction "{id}": holdDuration must not be negative`)
	end
	local distance = def.maxDistance
	if distance ~= nil then
		assert(distance > 0, `interaction "{id}": maxDistance must be positive`)
	end
	local cooldown = def.cooldown
	if cooldown ~= nil then
		assert(cooldown >= 0, `interaction "{id}": cooldown must not be negative`)
	end
	kinds[id] = def
end

function InteractionRegistry.get(id: string): InteractionDef?
	return kinds[id]
end

function InteractionRegistry.has(id: string): boolean
	return kinds[id] ~= nil
end

return InteractionRegistry
