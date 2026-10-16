--!strict
--[=[
	CarrySpeedSystem: how fast a carrier walks for what they carry. Carry tells it the weight of each carrier's hands item
	(`setHeld`); a game whose players carry more than that (an inventory) names their whole load (`setLoadSource`), and
	a game that boosts WalkSpeed itself (a sprint) names a carrier's unboosted speed (`setSpeedBase`). `apply` sets the
	walk for the load now: the unloaded speed (the speed base, else the walk as it was when the load began) slowed by
	CarryFormulas.carrierSpeed, and given back once the load is gone (an old body gets its own speed back). Sprint reads
	the same load (`weightFor`), so a sprint is slowed exactly as the walk is.

	Module state, shared by Carry, the game's inventory and Sprint (one source of truth for the load).

	@class CarrySpeedSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarryFormulas = require(ReplicatedStorage.Shared.Features.Carry.Utils.CarryFormulas)

-- A loaded carrier's humanoid and its unloaded walk speed.
type Load = { humanoid: Humanoid, rest: number }

local held: { [number]: number } = {}
local loads: { [number]: Load } = {}
local loadSource: ((player: Player) -> number?)? = nil
local speedBase: ((player: Player) -> number?)? = nil

local CarrySpeedSystem = {}

--[=[
	The weight of `userId`'s hands item (nil with empty hands). Carry calls it on every pick-up and release.
]=]
function CarrySpeedSystem.setHeld(userId: number, weight: number?)
	if weight ~= nil then
		held[userId] = weight
	else
		held[userId] = nil
	end
end

--[=[
	Sets THE source of a carrier's whole load; nil = the hands item's weight. It must not yield.
]=]
function CarrySpeedSystem.setLoadSource(source: ((player: Player) -> number?)?)
	loadSource = source
end

--[=[
	Sets THE source of a carrier's unboosted speed (a sprint); nil = the humanoid's WalkSpeed as it is. It must not
	yield.
]=]
function CarrySpeedSystem.setSpeedBase(source: ((player: Player) -> number?)?)
	speedBase = source
end

--[=[
	The load `player` carries: the load source's answer (never below 0), else the hands item's weight, else 0.
]=]
function CarrySpeedSystem.weightFor(player: Player): number
	local source = loadSource
	local named = if source ~= nil then source(player) else nil
	if named ~= nil then
		return math.max(0, named)
	end
	return held[player.UserId] or 0
end

--[=[
	Sets `humanoid`'s walk for `weight`, starting a load from `base` (else its WalkSpeed now) and giving the unloaded
	speed back when `weight` reaches 0. A load remembered for another humanoid (an old body) is given back to it first.
]=]
function CarrySpeedSystem.applyTo(userId: number, humanoid: Humanoid?, weight: number, base: number?)
	local load: Load? = loads[userId]
	if load ~= nil and load.humanoid ~= humanoid then
		if load.humanoid.Parent ~= nil then
			load.humanoid.WalkSpeed = load.rest
		end
		loads[userId] = nil
		load = nil
	end
	if humanoid == nil then
		return
	end
	if weight <= 0 then
		if load ~= nil then
			humanoid.WalkSpeed = load.rest
			loads[userId] = nil
		end
		return
	end
	local active: Load
	if load ~= nil then
		active = load
	else
		active = { humanoid = humanoid, rest = base or humanoid.WalkSpeed }
		loads[userId] = active
	end
	humanoid.WalkSpeed = CarryFormulas.carrierSpeed(active.rest, weight)
end

--[=[
	Re-applies `player`'s walk for their load now (`applyTo` with their character's humanoid and the speed base).
]=]
function CarrySpeedSystem.apply(player: Player)
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	local weight = CarrySpeedSystem.weightFor(player)
	local base = speedBase
	local current = loads[player.UserId]
	local loaded = current ~= nil and current.humanoid == humanoid
	-- The base is only read when a load begins (it may name a boost's unboosted speed).
	local start = if not loaded and weight > 0 and base ~= nil then base(player) else nil
	CarrySpeedSystem.applyTo(player.UserId, humanoid, weight, start)
end

--[=[
	How many carriers are loaded now (getState).
]=]
function CarrySpeedSystem.count(): number
	local count = 0
	for _ in loads do
		count += 1
	end
	return count
end

--[=[
	Forgets every load and source (specs).
]=]
function CarrySpeedSystem.reset()
	table.clear(held)
	table.clear(loads)
	loadSource = nil
	speedBase = nil
end

return CarrySpeedSystem
