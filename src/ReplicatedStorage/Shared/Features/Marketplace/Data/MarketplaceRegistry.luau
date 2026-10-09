--!strict
--[=[
	MarketplaceRegistry: developer products and gamepasses by game key (the ItemRegistry contract:
	validated, loud at boot, no re-registration). Shared so the client prompts by the same key the server
	grants by — gameplay code never pastes a numeric id.

	@class MarketplaceRegistry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MarketplaceTypes = require(ReplicatedStorage.Shared.Features.Marketplace.Data.MarketplaceTypes)

type ProductDef = MarketplaceTypes.ProductDef
type PassDef = MarketplaceTypes.PassDef

local products: { [string]: ProductDef } = {}
local productKeys: { [number]: string } = {}
local passes: { [string]: PassDef } = {}
local passKeysById: { [number]: string } = {}

local function assertId(label: string, key: string, id: number)
	assert(key ~= "", `{label} key must not be empty`)
	assert(id >= 1 and id == math.floor(id), `{label} "{key}": id must be a positive whole number`)
end

local MarketplaceRegistry = {}

function MarketplaceRegistry.registerProduct(key: string, def: ProductDef)
	assertId("product", key, def.productId)
	assert(products[key] == nil, `product "{key}" is already registered`)
	assert(productKeys[def.productId] == nil, `product id {def.productId} is already registered`)
	products[key] = table.freeze(table.clone(def))
	productKeys[def.productId] = key
end

function MarketplaceRegistry.registerPass(key: string, def: PassDef)
	assertId("pass", key, def.passId)
	assert(passes[key] == nil, `pass "{key}" is already registered`)
	assert(passKeysById[def.passId] == nil, `pass id {def.passId} is already registered`)
	passes[key] = table.freeze(table.clone(def))
	passKeysById[def.passId] = key
end

function MarketplaceRegistry.product(key: string): ProductDef?
	return products[key]
end

function MarketplaceRegistry.productKeyFor(productId: number): string?
	return productKeys[productId]
end

function MarketplaceRegistry.pass(key: string): PassDef?
	return passes[key]
end

function MarketplaceRegistry.passKeyFor(passId: number): string?
	return passKeysById[passId]
end

function MarketplaceRegistry.passKeys(): { string }
	local keys: { string } = {}
	for key in passes do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

return MarketplaceRegistry
