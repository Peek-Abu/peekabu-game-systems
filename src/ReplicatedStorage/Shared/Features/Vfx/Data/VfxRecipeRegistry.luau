--!strict
--[=[
	VfxRecipeRegistry: the catalog of effect recipes by id (the ItemRegistry contract: validated, loud at
	boot, no re-registration). Shared, because the server validates ids before sending them. A recipe's
	`sound` is checked against SoundRegistry when it plays, not here, so registration order between the
	two registries never matters.

	@class VfxRecipeRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VfxTypes = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxTypes)

type Recipe = VfxTypes.Recipe

local recipes: { [string]: Recipe } = {}

local VfxRecipeRegistry = {}

--[=[
	Registers a recipe. Asserts: the id is new; the template is a non-empty name; the lifetime is
	positive; trauma is within 0..1 and comes with a positive shakeRadius; a sound id is non-empty.
]=]
function VfxRecipeRegistry.register(id: string, recipe: Recipe)
	assert(recipes[id] == nil, `vfx recipe "{id}" is already registered`)
	assert(type(recipe.template) == "string" and recipe.template ~= "", `vfx recipe "{id}": template is required`)
	assert(recipe.lifetime > 0, `vfx recipe "{id}": lifetime must be positive`)
	local trauma = recipe.trauma
	if trauma ~= nil then
		assert(trauma >= 0 and trauma <= 1, `vfx recipe "{id}": trauma must be within 0..1`)
		local radius = recipe.shakeRadius
		assert(radius ~= nil and radius > 0, `vfx recipe "{id}": trauma needs a positive shakeRadius`)
	end
	local sound = recipe.sound
	if sound ~= nil then
		assert(sound ~= "", `vfx recipe "{id}": sound must be a non-empty id`)
	end
	recipes[id] = recipe
end

function VfxRecipeRegistry.get(id: string): Recipe?
	return recipes[id]
end

function VfxRecipeRegistry.has(id: string): boolean
	return recipes[id] ~= nil
end

function VfxRecipeRegistry.ids(): { string }
	local ids: { string } = {}
	for id in recipes do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

return VfxRecipeRegistry
