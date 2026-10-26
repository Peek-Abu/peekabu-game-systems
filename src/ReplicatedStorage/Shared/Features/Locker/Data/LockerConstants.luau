--!strict
--[=[
	LockerConstants: the two Lost & Found Lockers and every number the design marks as tunable (design:
	docs/superpowers/specs/2026-10-25-odd-hours-lockers-design.md). Static data (spec-exempt; checked through
	LockerRules.spec).

	Key prices: Saved Gloom is ~100 a shift, so a Gloom key is about three shifts; Gleam is ~2 per Robux, so a Gleam key
	is about 49 Robux. Pity is worked out from the odds (owner): PITY_FACTOR times the average wait for an Epic+.

	@class LockerConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local LockerTypes = require(script.Parent.LockerTypes)

type Rarity = CosmeticTypes.Rarity

local GLOOM: LockerTypes.Locker = {
	id = "gloom",
	name = "Gloom Locker",
	source = "gloomLocker",
	currency = "gloom",
	keyPrice = 300,
	odds = { uncommon = 72, rare = 20, epic = 7, legendary = 1 },
	-- Gloom is only earned, never bought, so its Locker is not a paid random item (design: to confirm).
	paidRandom = false,
}

local GLEAM: LockerTypes.Locker = {
	id = "gleam",
	name = "Gleam Locker",
	source = "gleamLocker",
	currency = "gleam",
	keyPrice = 100,
	odds = { rare = 60, epic = 32, legendary = 8 },
	paidRandom = true,
}

-- The order rarities are listed (and rolled) in, worst to best.
local RARITY_ORDER: { Rarity } = { "uncommon", "rare", "epic", "legendary", "odd" }

-- Rarities that count as "Epic or better" for pity.
local EPIC_PLUS: { [Rarity]: boolean } = { epic = true, legendary = true, odd = true }

-- A duplicate gives back this share of the key price.
local REFUND: { [Rarity]: number } = { uncommon = 0.15, rare = 0.3, epic = 0.6, legendary = 1, odd = 1 }

-- What a restricted player pays, in Gleam, to buy a paid Locker's item directly.
local DIRECT_PRICE: { [Rarity]: number } = { uncommon = 150, rare = 300, epic = 750, legendary = 1500, odd = 1500 }

local ORDER: { LockerTypes.LockerId } = { "gloom", "gleam" }

local LOCKERS = table.freeze({ gloom = GLOOM, gleam = GLEAM })

export type LockerConstants = {
	SLICE: string,
	LOCKERS: { gloom: LockerTypes.Locker, gleam: LockerTypes.Locker },
	ORDER: { LockerTypes.LockerId },
	RARITY_ORDER: { Rarity },
	EPIC_PLUS: { [Rarity]: boolean },
	PITY_FACTOR: number,
	REFUND: { [Rarity]: number },
	DIRECT_PRICE: { [Rarity]: number },
	DEFAULT_DIRECT_PRICE: number,
	OPEN_COOLDOWN: number,
	defaultLockers: () -> LockerTypes.Lockers,
}

local LockerConstants: LockerConstants = {
	SLICE = "lockers",
	LOCKERS = LOCKERS,
	-- The order the Shop shows them in.
	ORDER = ORDER,
	RARITY_ORDER = RARITY_ORDER,
	EPIC_PLUS = EPIC_PLUS,
	PITY_FACTOR = 1.5,
	REFUND = REFUND,
	DIRECT_PRICE = DIRECT_PRICE,
	DEFAULT_DIRECT_PRICE = 1500,
	-- One open per this many seconds per player.
	OPEN_COOLDOWN = 1,
	defaultLockers = function(): LockerTypes.Lockers
		return { keys = {}, pity = {}, opened = 0 }
	end,
}

table.freeze(LockerConstants)
return LockerConstants
