--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemRegistry)
local PlayerDataType = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

--[=[
	Boot-time seeding of the item registry. Both boot handlers (ServerHandler/ClientHandler) and the
	TestRunner call ItemContentRegistry.init() before anything else touches ItemRegistry, so every consumer
	(InventoryService, InventoryUtils, the Cmdr `itemType` enum) sees a fully-populated registry.

	SAMPLE content: a small catalog that exercises every shape the inventory supports — unique items
	(tool, wearable, misc), a plain stackable, a stackable capped to one stack, and a stackable misc
	material. Each game replaces this catalog with its own; the specs use these keys as fixtures, so
	keep the shapes (or update the specs) when you do.

	init() guards its own re-entry via a module-level `initialized` flag: ItemRegistry.register
	rejects a second registration of the same item type outright (see ItemRegistry), but init()
	itself is called from multiple independent boot paths (both realms, plus the test runner and
	this module's own spec), so it must be safe to call more than once in a single VM.

	@class ItemContentRegistry
]=]
export type ItemContentRegistry = {}

local ItemContentRegistry = {}
local initialized = false

function ItemContentRegistry.init()
	if initialized then
		-- Already seeded in this VM (a second boot path, or a spec that already called init()).
		return
	end
	initialized = true

	-- Every item is built as an explicitly-typed LOCAL rather than an inline table literal passed straight
	-- into register(): the annotation gives the table constructor its expected type directly, so a typo'd
	-- field is caught at the definition site.

	-- Tools (unique: no stackMax, so each copy is minted with its own uid)
	local wrench: PlayerDataType.ItemDefinition = {
		name = "Wrench",
		icon = "rbxassetid://123",
		description = "A sturdy wrench. Fixes most things, eventually.",
		rarity = "common",
		kind = "tool",
	}
	ItemRegistry.register("wrench", wrench)

	local goldenWrench: PlayerDataType.ItemDefinition = {
		name = "Golden Wrench",
		icon = "rbxassetid://456",
		description = "Too shiny to actually use.",
		rarity = "legendary",
		kind = "tool",
	}
	ItemRegistry.register("golden-wrench", goldenWrench)

	-- Wearables
	local hardHat: PlayerDataType.ItemDefinition = {
		name = "Hard Hat",
		icon = "rbxassetid://789",
		description = "Safety first.",
		rarity = "epic",
		kind = "wearable",
	}
	ItemRegistry.register("hard-hat", hardHat)

	-- Consumables (stackable)
	local medkit: PlayerDataType.ItemDefinition = {
		name = "Medkit",
		icon = "rbxassetid://1011",
		description = "Patches you up.",
		rarity = "common",
		kind = "consumable",
		stackMax = 10,
	}
	ItemRegistry.register("medkit", medkit)

	local flare: PlayerDataType.ItemDefinition = {
		name = "Flare",
		icon = "rbxassetid://1213",
		description = "Bright, brief, and limited to one stack.",
		rarity = "common",
		kind = "consumable",
		stackMax = 10,
		maxStacks = 1,
	}
	ItemRegistry.register("flare", flare)

	-- Misc
	local scrap: PlayerDataType.ItemDefinition = {
		name = "Scrap",
		icon = "rbxassetid://1415",
		description = "Bits of metal. Someone will buy it.",
		rarity = "common",
		kind = "misc",
		stackMax = 30,
	}
	ItemRegistry.register("scrap", scrap)

	local masterKey: PlayerDataType.ItemDefinition = {
		name = "Master Key",
		icon = "rbxassetid://1617",
		description = "Opens the door you were told not to open.",
		rarity = "legendary",
		kind = "misc",
	}
	ItemRegistry.register("master-key", masterKey)
end

return ItemContentRegistry
