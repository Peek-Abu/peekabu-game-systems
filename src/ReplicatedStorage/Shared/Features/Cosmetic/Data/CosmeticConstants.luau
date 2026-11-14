--!strict
--[=[
	CosmeticConstants: the loadout slice's name, the default employee and the slot counts.

	@class CosmeticConstants
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

local WHEEL_SLOTS = 4
local STICKER_SLOTS = 4

local function emptySlots(count: number): { string }
	local slots: { string } = {}
	for index = 1, count do
		slots[index] = ""
	end
	return slots
end

return table.freeze({
	-- The account slice CosmeticServiceServer owns (what each player wears).
	SLICE = "loadout",
	-- Everyone owns this employee; the first-join pick preselects it.
	DEFAULT_EMPLOYEE = "Pippa",
	-- Studio only: a Workspace string attribute naming an employee (e.g. "Pippa") makes the server pick it for every
	-- player who has not picked yet, through the real pick path, and the client skip that pick's "You're hired!"
	-- reveal (CosmeticDevPickRules). For agents and testers in Studio; never active in a published server.
	DEV_PICK_ATTRIBUTE = "DevAutoPick",
	-- Emote-wheel slots per employee, sticker slots per account.
	WHEEL_SLOTS = WHEEL_SLOTS,
	STICKER_SLOTS = STICKER_SLOTS,
	-- The most colour styles a skin may have (Legendaries ship 3).
	MAX_STYLES = 9,
	-- A sticker pack's rarity and Gleam price by how many stickers it holds (owner, 2026-11-13: 100 Gleam a sticker).
	-- CosmeticStickerRegistry.spec holds every pack to it.
	STICKER_PACKS = table.freeze({
		[2] = table.freeze({ rarity = "rare", price = 200 }),
		[4] = table.freeze({ rarity = "epic", price = 400 }),
		[6] = table.freeze({ rarity = "legendary", price = 600 }),
	}),
	-- Ids are 1-64 characters (EntitlementRules.isKey).
	MAX_ID_LENGTH = 64,
	-- The most ids one "seen" request may carry (one page of cards).
	MAX_SEEN = 32,

	--[=[
		A new loadout: Pippa, the first-join pick not made yet, no looks (each falls back to its employee's
		defaults), empty sticker slots, nothing seen.
	]=]
	defaultLoadout = function(): PlayerDataTypes.Loadout
		return {
			current = "Pippa",
			picked = false,
			looks = {},
			stickers = emptySlots(STICKER_SLOTS),
			seen = {},
		}
	end,

	emptyWheel = function(): { string }
		return emptySlots(WHEEL_SLOTS)
	end,
})
