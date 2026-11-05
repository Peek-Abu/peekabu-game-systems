--!strict
--[=[
	FootstepSurfaceUtils: what a step lands on and which sound it plays. `surfaceFor` turns the floor under the foot
	into a surface (carpet, tile, wood, concrete, the outdoor asphalt, grass, gravel and puddle, or default): its
	FootstepSurface attribute when it names one (the hook for a builder whose carpet is a SmoothPlastic part, or the
	yard's puddle discs), else its material (FootstepConstants.MATERIAL_SURFACES; Asphalt and Pavement are asphalt
	only `outside`, concrete inside). `poolFor` is a character's variants for that surface, the default pool when it
	has none (every outdoor surface: each character keeps its own step). `layerFor` is the shared outdoor layer that
	plays under it (yard design Y2), none indoors, and `layerPool` that layer's variants. `pick` chooses one variant
	by a roll, never the one this foot played last when there is a choice. Pure.

	@class FootstepSurfaceUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FootstepConstants = require(ReplicatedStorage.Client.Features.Footstep.Data.FootstepConstants)
local FootstepTypes = require(ReplicatedStorage.Client.Features.Footstep.Data.FootstepTypes)

type Surface = FootstepTypes.Surface
type SurfacePools = FootstepTypes.SurfacePools
type LayerSurface = FootstepTypes.LayerSurface
type LayerPools = FootstepTypes.LayerPools

local FootstepSurfaceUtils = {}

--[=[
	The surface of a floor of `material` whose FootstepSurface attribute is `override` (any attribute value), `outside`
	when the floor is in the yard.
]=]
function FootstepSurfaceUtils.surfaceFor(material: Enum.Material, override: unknown, outside: boolean?): Surface
	if override == "asphalt" then
		return "asphalt"
	elseif override == "grass" then
		return "grass"
	elseif override == "gravel" then
		return "gravel"
	elseif override == "puddle" then
		return "puddle"
	elseif override == "carpet" then
		return "carpet"
	elseif override == "tile" then
		return "tile"
	elseif override == "wood" then
		return "wood"
	elseif override == "concrete" then
		return "concrete"
	elseif override == "default" then
		return "default"
	end
	if outside == true and FootstepConstants.OUTSIDE_ASPHALT[material] == true then
		return "asphalt"
	end
	return FootstepConstants.MATERIAL_SURFACES[material] or "default"
end

--[=[
	The shared outdoor layer that plays under a step on `surface`; nil indoors (nothing changes inside).
]=]
function FootstepSurfaceUtils.layerFor(surface: Surface): LayerSurface?
	if surface == "asphalt" then
		return "asphalt"
	elseif surface == "grass" then
		return "grass"
	elseif surface == "gravel" then
		return "gravel"
	elseif surface == "puddle" then
		return "puddle"
	end
	return nil
end

--[=[
	`layer`'s own list in `layers`.
]=]
function FootstepSurfaceUtils.layerPool(layers: LayerPools, layer: LayerSurface): { string }
	if layer == "asphalt" then
		return layers.asphalt
	elseif layer == "grass" then
		return layers.grass
	elseif layer == "gravel" then
		return layers.gravel
	end
	return layers.puddle
end

--[=[
	The ids to choose from for `surface`: its own pool, else the default one (empty if that is empty too).
]=]
function FootstepSurfaceUtils.poolFor(pools: SurfacePools, surface: Surface): { string }
	local own = FootstepSurfaceUtils.ownPool(pools, surface)
	if #own > 0 then
		return own
	end
	return pools.default
end

--[=[
	`surface`'s own list in `pools` (no fallback).
]=]
function FootstepSurfaceUtils.ownPool(pools: SurfacePools, surface: Surface): { string }
	if surface == "carpet" then
		return pools.carpet
	elseif surface == "tile" then
		return pools.tile
	elseif surface == "wood" then
		return pools.wood
	elseif surface == "concrete" then
		return pools.concrete
	end
	return pools.default
end

--[=[
	A variant index 1..count for `roll` (0..1), skipping `last` when count > 1; nil for an empty pool.
]=]
function FootstepSurfaceUtils.pick(count: number, roll: number, last: number?): number?
	if count <= 0 then
		return nil
	end
	if count == 1 or last == nil or last < 1 or last > count then
		return math.clamp(math.floor(roll * count) + 1, 1, count)
	end
	-- Choose among the others, then step over `last`.
	local index = math.clamp(math.floor(roll * (count - 1)) + 1, 1, count - 1)
	return if index >= last then index + 1 else index
end

return FootstepSurfaceUtils
