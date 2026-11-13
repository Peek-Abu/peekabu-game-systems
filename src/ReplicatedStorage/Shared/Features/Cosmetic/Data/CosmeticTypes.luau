--!strict
--[=[
	CosmeticTypes: what a cosmetic item is, and the shapes of a look, a loadout and an equip change
	(design: docs/superpowers/specs/2026-10-24-odd-hours-character-systems-design.md).

	@class CosmeticTypes
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

-- What the item is. Every kind but `sticker` is owned through the entitlements slice under its kind as the
-- category; a sticker is owned through its pack.
export type Kind = "employee" | "skin" | "idle" | "emote" | "stickerPack" | "sticker" | "vacuum"

--[=[
	A real sale on an item or a bundle: the price it sells at between `starts` and `ends` (UTC unix seconds; nil = open
	on that side). The Shop's price rules (ShopPriceRules) read it; never an invented "was" price.
]=]
export type Sale = { price: number, starts: number?, ends: number? }

export type Rarity = "default" | "uncommon" | "rare" | "epic" | "legendary" | "odd"

-- Where it comes from. `default` items are free and never stored: every player owns them.
export type Source =
	"default"
	| "credits"
	| "gleam"
	| "gloomLocker"
	| "gleamLocker"
	| "goal"
	| "event"
	| "gift"
	| "later"

export type Item = {
	id: string,
	kind: Kind,
	name: string,
	rarity: Rarity,
	source: Source,
	-- The employee it belongs to; nil = works on every employee (shared idles, sticker packs, stickers, vacuums).
	employee: string?,
	-- In the source's currency (Credits for `credits`, Gleam for `gleam`); nil when it can't be bought.
	price: number?,
	-- A real sale on it (the regular price is `price`).
	sale: Sale?,
	-- How many colour styles a skin has (1 when nil).
	styles: number?,
	-- A short line or two about it, kid reading level, usually told about the employee (third person).
	lore: string,
	-- True when the lore is the employee speaking (first person): drawn as a quote. A choice per item (some lines
	-- only sound right spoken), never tied to rarity.
	quote: boolean?,
	-- A sticker's pack.
	pack: string?,
	-- An idle that fits only some of its employee's skins (it needs a prop only they have): their ids. nil = every
	-- skin of its employee. On any other skin the idle is locked and the skin's own idle plays (owner, 2026-11-13).
	fits: { string }?,
}

--[=[
	A bundle: items sold together (CosmeticBundleRegistry). It can mix employees and kinds. Buying it grants every item
	in it; "owning a bundle" only means owning all of its items (nothing about the bundle itself is saved). Each item
	is also its own item, owned, bought and granted alone (owner, 2026-11-13).
]=]
export type Bundle = {
	-- `Bundle.<Name>`, never a CosmeticRegistry id.
	id: string,
	name: string,
	rarity: Rarity,
	-- The CosmeticRegistry ids it grants, in show order (the first is the hero). No stickers, no free defaults.
	items: { string },
	currency: "gleam" | "credits",
	-- The bundle's price (hand-set, about 30% off its items' regular prices; the owner sets it).
	price: number,
	-- A real sale on the bundle.
	sale: Sale?,
	lore: string,
}

--[=[
	A collection: a named group of items, data only for launch (not shown or sold; CosmeticCollectionRegistry). It can
	mix employees and kinds, and keeps a set linked even when its bundle is retired.
]=]
export type Collection = {
	-- `Collection.<Name>`.
	id: string,
	name: string,
	items: { string },
}

-- Why something was granted (the reveal's flavour): bought in the Shop, opened from a Locker, the first-join pick, any other grant.
export type GrantSource = "shop" | "locker" | "pick" | "grant"

-- One "you got these" moment.
export type Granted = { userId: number, ids: { string }, source: GrantSource }

export type Look = PlayerDataTypes.Look
export type Loadout = PlayerDataTypes.Loadout

-- One thing a player asks to change. An emote or sticker `id` of "" clears that slot.
export type Change =
	{ kind: "employee", id: string }
	| { kind: "skin", id: string, style: number }
	| { kind: "idle", employee: string, id: string }
	| { kind: "emote", employee: string, slot: number, id: string }
	| { kind: "sticker", slot: number, id: string }
	| { kind: "vacuum", id: string }

--[=[
	Everything one player wears, resolved (CosmeticOutfitRules.current): what to build to show or spawn them.
	`vacuum` is account-wide (one vacuum for the whole crew), the look is the employee's own.
]=]
export type Outfit = {
	employee: string,
	look: Look,
	vacuum: string,
	stickers: { string },
}

return {}
