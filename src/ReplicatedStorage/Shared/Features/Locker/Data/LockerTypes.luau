--!strict
--[=[
	LockerTypes: the Lost & Found Lockers (design: docs/superpowers/specs/2026-10-25-odd-hours-lockers-design.md).

	@class LockerTypes
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

export type LockerId = "gloom" | "gleam"

-- What a key costs: Gloom (earned, a game currency) or Gleam (premium).
export type Currency = "gloom" | "gleam"

export type Locker = {
	id: LockerId,
	name: string,
	-- The CosmeticRegistry source its items carry.
	source: CosmeticTypes.Source,
	currency: Currency,
	keyPrice: number,
	-- Chance weights by rarity (any scale); a rarity with no items in the pool drops out.
	odds: { [CosmeticTypes.Rarity]: number },
	-- Opening it is a paid random item (Roblox policy): restricted players buy its items directly instead.
	paidRandom: boolean,
}

-- One rarity's real chance (0..1) in a Locker, and each of its items' chance.
export type RarityOdds = { rarity: CosmeticTypes.Rarity, chance: number, items: { string } }

export type Odds = {
	rarities: { RarityOdds },
	-- The chance of an Epic or better on one open (0..1).
	epicPlus: number,
	-- Opens until an Epic or better is guaranteed (nil if the pool has none).
	pityAt: number?,
}

-- What one open gave.
export type Outcome = {
	locker: LockerId,
	item: string,
	rarity: CosmeticTypes.Rarity,
	-- Already owned: the player gets `refund` of the Locker's currency instead.
	duplicate: boolean,
	refund: number,
	-- The pity guarantee forced this Epic-or-better.
	guaranteed: boolean,
	-- Opens since the last Epic-or-better after this open.
	pity: number,
}

export type Lockers = PlayerDataTypes.Lockers

return {}
