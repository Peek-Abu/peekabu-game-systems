--!strict
--[=[
	AbilityStore: the local player's ability as the HUD sees it: when it is ready again (server time, 0 = ready), the
	effect running on their character, and which ability their employee has, copied from the server's attributes by
	AbilityServiceClient (`apply`, which reads anything it is given defensively). Nothing here is sent back.
	Client-only UI state.

	@class AbilityStore
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local AbilityRegistry = require(ReplicatedStorage.Shared.Features.Ability.Data.AbilityRegistry)

local none: string? = nil
local readyAt = Charm.atom(0)
local active = Charm.atom(none)
local abilityId = Charm.atom(none)

local AbilityStore = {
	readyAt = readyAt,
	active = active,
	abilityId = abilityId,
}

--[=[
	Copies the server's attributes in: a ready time that is not a number reads ready (0); an effect or employee name
	that is not a string reads none; an employee without an ability has none.
]=]
function AbilityStore.apply(rawReadyAt: unknown, rawActive: unknown, rawEmployee: unknown)
	readyAt(if type(rawReadyAt) == "number" and rawReadyAt == rawReadyAt then rawReadyAt else 0)
	active(if type(rawActive) == "string" then rawActive else nil)
	local def = if type(rawEmployee) == "string" then AbilityRegistry.forEmployee(rawEmployee) else nil
	abilityId(if def ~= nil then def.id else nil)
end

--[=[
	Whole seconds until `ready` at server time `now` (rounded up), never below 0.
]=]
function AbilityStore.secondsLeft(ready: number, now: number): number
	return math.max(0, math.ceil(ready - now))
end

--[=[
	How much of a `cooldown` is still to go at `now`, 1 (just used) to 0 (ready): the HUD's sweep.
]=]
function AbilityStore.remaining(ready: number, now: number, cooldown: number): number
	if cooldown <= 0 then
		return 0
	end
	return math.clamp((ready - now) / cooldown, 0, 1)
end

return AbilityStore
