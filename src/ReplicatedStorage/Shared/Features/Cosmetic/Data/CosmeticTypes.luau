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
export type Kind = "employee" | "skin" | "idle" | "emote" | "stickerPack" | "sticker"

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
	-- The employee it belongs to; nil = works on every employee (shared idles, sticker packs, stickers).
	employee: string?,
	-- In the source's currency (Credits for `credits`, Gleam for `gleam`); nil when it can't be bought.
	price: number?,
	-- How many colour styles a skin has (1 when nil).
	styles: number?,
	-- One short line in the employee's voice, kid reading level.
	lore: string,
	-- Items that come with this one (a Legendary skin's emote, idle and sticker pack).
	bundle: { string }?,
	-- A sticker's pack.
	pack: string?,
}

-- Why something was granted (the reveal's flavour): bought in the Shop, the first-join pick, any other grant.
export type GrantSource = "shop" | "pick" | "grant"

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

return {}
