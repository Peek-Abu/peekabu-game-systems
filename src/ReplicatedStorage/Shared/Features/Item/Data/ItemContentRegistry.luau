--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemRegistry)
local PlayerDataType = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

--[=[
	Boot-time seeding of the item registry. Both boot handlers (ServerHandler/ClientHandler) and the
	TestRunner call ItemContentRegistry.init() before anything else touches ItemRegistry, so every consumer
	(InventoryService, InventoryUtils, the Cmdr `itemType` enum) sees a fully-populated registry.

	Provisional content: real shapes (kind, rarity, stack rules), placeholder art/copy. Swap
	names/icons/descriptions freely; the SHAPE is what other systems depend on.

	`rusted-saw`, `chambered-helmet`, `throwing-knife`, and `wood` share names with real items in
	the live game (verified against ReplicatedStorage.Modules.{Weapon.AllWeapons, Armour.AllArmours,
	Items.AllItems} in the VentureTestingPlace reference copy) and their rarities are set to match
	that source data (Common/Epic/Common/Common respectively). `phoenix-blade`, `healing-tonic`, and
	`crypt-key` have no real-game analog and are fully invented placeholders.

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

	-- Weapons
	--
	-- Each item is built as an explicitly-typed LOCAL (its specific variant, e.g.
	-- PlayerDataType.WeaponDefinition) rather than an inline table literal passed straight into
	-- register(): register()'s parameter is the ItemDefinition UNION, and Luau does not propagate an
	-- expected type through a union for table-literal checking, so a literal built straight at the
	-- call site has its `kind` field widened to plain `string` and fails to match any union arm.
	-- Checking against the single concrete variant type on the `local` annotation gives the table
	-- constructor its expected type directly, so `kind` is checked as its singleton literal with no
	-- cast needed.
	local rustedSaw: PlayerDataType.WeaponDefinition = {
		name = "Rusted Saw Blade",
		icon = "rbxassetid://123",
		description = "A pitted old saw blade lashed to a handle. Better than nothing.",
		rarity = "common",
		kind = "weapon",
		equipSlot = "weapon",
	}
	ItemRegistry.register("rusted-saw", rustedSaw)

	local phoenixBlade: PlayerDataType.WeaponDefinition = {
		name = "Phoenix Blade",
		icon = "rbxassetid://456",
		description = "Forged in the ashes of something that used to matter.",
		rarity = "legendary",
		kind = "weapon",
		equipSlot = "weapon",
	}
	ItemRegistry.register("phoenix-blade", phoenixBlade)

	-- Armour
	--
	-- chambered-helmet's requiredLevel/statBonuses match the live game's AllArmours.Chambered module
	-- (Required Level = 8, Stats = { ["Rot Defense"] = { min = 20, max = 28 } }): rotEndurance is the
	-- closest existing StatConstants id to "Rot Defense", and 8 is a fixed midpoint-of-the-floor
	-- bonus standing in for that old min/max range.
	local chamberedHelmet: PlayerDataType.ArmourDefinition = {
		name = "Chambered Helmet",
		icon = "rbxassetid://789",
		description = "Riveted plate with a narrow eye-slit. Muffles everything.",
		rarity = "epic",
		kind = "armour",
		equipSlot = "helmet",
		requiredLevel = 8,
		statBonuses = { rotEndurance = 8 },
	}
	ItemRegistry.register("chambered-helmet", chamberedHelmet)

	-- Consumables
	local healingTonic: PlayerDataType.ConsumableDefinition = {
		name = "Healing Tonic",
		icon = "rbxassetid://1011",
		description = "Bitter, but it closes wounds.",
		rarity = "common",
		kind = "consumable",
		stackMax = 10,
	}
	ItemRegistry.register("healing-tonic", healingTonic)

	local throwingKnife: PlayerDataType.ConsumableDefinition = {
		name = "Throwing Knife",
		icon = "rbxassetid://1213",
		description = "Balanced for the throw, not the fight.",
		rarity = "common",
		kind = "consumable",
		stackMax = 10,
		maxStacks = 1,
	}
	ItemRegistry.register("throwing-knife", throwingKnife)

	-- Misc
	local wood: PlayerDataType.MiscDefinition = {
		name = "Wood",
		icon = "rbxassetid://1415",
		description = "Rough-cut lumber. Common crafting material.",
		rarity = "common",
		kind = "misc",
		stackMax = 30,
	}
	ItemRegistry.register("wood", wood)

	local cryptKey: PlayerDataType.MiscDefinition = {
		name = "Crypt Key",
		icon = "rbxassetid://1617",
		description = "Cold to the touch. It wants to be used.",
		rarity = "cursed",
		kind = "misc",
		questItem = true,
	}
	ItemRegistry.register("crypt-key", cryptKey)
end

return ItemContentRegistry
