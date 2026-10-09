--!strict
--[=[
	CarryRegistry: the carryable kinds by id (the ItemRegistry contract: validated, loud at boot, no
	re-registration). The kind a tagged object names through its CarryKind attribute.

	@class CarryRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarryTypes = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryTypes)

type CarryDef = CarryTypes.CarryDef

local kinds: { [string]: CarryDef } = {}

local CarryRegistry = {}

--[=[
	Registers a kind. Asserts: the id is new; the weight is not negative; a throw speed is positive.
]=]
function CarryRegistry.register(id: string, def: CarryDef)
	assert(kinds[id] == nil, `carry kind "{id}" is already registered`)
	assert(def.weight >= 0, `carry kind "{id}": weight must not be negative`)
	local throwSpeed = def.throwSpeed
	if throwSpeed ~= nil then
		assert(throwSpeed > 0, `carry kind "{id}": throwSpeed must be positive`)
	end
	kinds[id] = def
end

function CarryRegistry.get(id: string): CarryDef?
	return kinds[id]
end

function CarryRegistry.has(id: string): boolean
	return kinds[id] ~= nil
end

return CarryRegistry
