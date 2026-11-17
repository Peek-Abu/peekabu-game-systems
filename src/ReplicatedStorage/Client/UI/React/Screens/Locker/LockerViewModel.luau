--!strict
--[=[
	LockerViewModel: everything the Shop's Lockers tab, the Odds sheet and the stage-1 opening screen show, computed
	from `LockerRules` and the player's synced state (design:
	docs/superpowers/specs/2026-10-25-odd-hours-lockers-design.md). The opening's 3D cutscene (`cutscenePose`,
	`openingDuration`, `RARITY_FX`) lives in LockerCutsceneViewModel and the Locker card (`card`) in LockerCardViewModel,
	both split out of this file and re-exported here.

	@class LockerViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local Locker = ReplicatedStorage.Shared.Features.Locker
local LockerConstants = require(Locker.Data.LockerConstants)
local LockerRules = require(Locker.Rules.LockerRules)
local LockerTypes = require(Locker.Data.LockerTypes)
local LockerCardViewModel = require(script.Parent.LockerCardViewModel)
local LockerCutsceneViewModel = require(script.Parent.LockerCutsceneViewModel)
local ToonStyleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonStyleViewModel)
local CosmeticRevealStore = require(ReplicatedStorage.Client.Features.Cosmetic.State.CosmeticRevealStore)

type Item = CosmeticTypes.Item
type Locker = LockerTypes.Locker
type LockerId = LockerTypes.LockerId
type Rarity = CosmeticTypes.Rarity
type Owns = (id: string) -> boolean

export type Balances = LockerCardViewModel.Balances
export type ButtonKind = LockerCardViewModel.ButtonKind
export type OpenButton = LockerCardViewModel.OpenButton
export type LockerCard = LockerCardViewModel.LockerCard
export type PityMeter = LockerCardViewModel.PityMeter

export type InsideItem = {
	id: string,
	name: string,
	line: string,
	kind: CosmeticTypes.Kind,
	rarity: Rarity,
	employee: string,
	skinKey: string?,
	vacuum: string?,
	owned: boolean,
	directPrice: string?,
	canBuyDirect: boolean,
	confirm: string,
}

export type PageButton = "buy" | "getGleam" | "back"

export type ItemPage = {
	from: string,
	chance: string?,
	button: PageButton,
}

export type OddsItemRow = {
	id: string,
	name: string,
	chanceText: string,
}

export type OddsRarityRow = {
	rarity: Rarity,
	label: string,
	chanceText: string,
	itemChanceText: string,
	refundText: string,
	items: { OddsItemRow },
}

export type OddsSheet = {
	locker: LockerId,
	title: string,
	pityRule: string,
	rarities: { OddsRarityRow },
}

export type CutsceneBeat = LockerCutsceneViewModel.CutsceneBeat
export type RarityFx = LockerCutsceneViewModel.RarityFx
export type CutscenePose = LockerCutsceneViewModel.CutscenePose

export type OpeningView = {
	locker: LockerId,
	lockerName: string,
	currency: LockerTypes.Currency,
	item: string,
	rarity: Rarity,
	guaranteed: boolean,
	duplicateLine: string?,
	skipAfter: number,
	duration: number,
}

local KIND_WORD: { [CosmeticTypes.Kind]: string } = {
	employee = "Employee",
	skin = "Skin",
	idle = "Idle",
	emote = "Emote",
	stickerPack = "Sticker pack",
	sticker = "Sticker",
	vacuum = "Vacuum",
}

local RARITY_RANK: { [Rarity]: number } = {
	default = 0,
	uncommon = 1,
	rare = 2,
	epic = 3,
	legendary = 4,
	odd = 5,
}

local RARITY_LABEL: { [Rarity]: string } = {
	default = "Classic",
	uncommon = "Uncommon",
	rare = "Rare",
	epic = "Epic",
	legendary = "Legendary",
	odd = "Odd",
}

local VM = {
	OPENING_SCENE = "lockerOpening",
	SKIP_AFTER = 1.0,
	BURST_SECONDS = LockerCutsceneViewModel.BURST_SECONDS,
	GLIMPSE_SECONDS = LockerCutsceneViewModel.GLIMPSE_SECONDS,
	-- The hub music's duck while a Locker opens (owner 11-16: "Yes, fade it"): dB on the Music group, eased down over
	-- MUSIC_DUCK_IN seconds and back over MUSIC_DUCK_OUT once the reveal closes. The track keeps playing underneath.
	MUSIC_DUCK_DB = -30,
	MUSIC_DUCK_IN = 0.6,
	MUSIC_DUCK_OUT = 1.5,
	RARITY_FX = LockerCutsceneViewModel.RARITY_FX,
	STAGE_ORIGIN = CFrame.new(3000, 0, 0),
}

VM.openingDuration = LockerCutsceneViewModel.openingDuration
VM.cutscenePose = LockerCutsceneViewModel.cutscenePose
VM.card = LockerCardViewModel.card

-- Whether the hub music is ducked: while a Locker opening plays (`opening`) and while its reveal is up (`reveal` from a
-- Locker); any other reveal leaves the music alone.
function VM.musicDucked(opening: LockerTypes.Outcome?, reveal: CosmeticRevealStore.Reveal?): boolean
	return opening ~= nil or (reveal ~= nil and reveal.source == "locker")
end

-- When Skip shows (owner pick 11-16): a second into your first ever open, at once after that. `opened` is the
-- synced open count, which already counts this open once the server's answer has synced.
function VM.skipAfter(opened: number): number
	return if opened >= 2 then 0 else VM.SKIP_AFTER
end

local function currencyWord(currency: LockerTypes.Currency): string
	if currency == "gleam" then
		return "Gleam"
	elseif currency == "acorns" then
		return "acorns"
	end
	return "Gloom"
end

-- The Lockers to show, in order: an event's Locker only while its event (`live`, its id) is live.
function VM.lockers(live: string?): { Locker }
	local list: { Locker } = {}
	for _, id in LockerConstants.ORDER do
		local locker = LockerConstants.BY_ID[id]
		if locker ~= nil and (locker.event == nil or locker.event == live) then
			table.insert(list, locker)
		end
	end
	return list
end

local function formatPercent(chance: number): string
	local pct = chance * 100
	local rounded = math.floor(pct * 10 + 0.5) / 10
	if rounded == math.floor(rounded) then
		return `{math.floor(rounded)}%`
	end
	return string.format("%.1f%%", rounded)
end

local function lineOf(item: Item): string
	local word = KIND_WORD[item.kind]
	if item.kind == "employee" or item.kind == "stickerPack" then
		return word
	elseif item.kind == "vacuum" then
		return `{word} · every employee`
	end
	return `{word} · {item.employee or "any employee"}`
end

function VM.inside(locker: Locker, owns: Owns, balances: Balances, restricted: boolean, pool: { Item }?): { InsideItem }
	local items = table.clone(pool or LockerRules.pool(locker))
	table.sort(items, function(a: Item, b: Item): boolean
		if RARITY_RANK[a.rarity] ~= RARITY_RANK[b.rarity] then
			return RARITY_RANK[a.rarity] > RARITY_RANK[b.rarity]
		end
		return a.id < b.id
	end)
	local isRestricted = locker.paidRandom and restricted
	local list: { InsideItem } = {}
	for _, item in items do
		local owned = owns(item.id)
		local direct = LockerRules.directPrice(item)
		local directText = ToonStyleViewModel.grouped(direct)
		local employee = if item.kind == "employee" then item.id else item.employee or "Pippa"
		table.insert(list, {
			id = item.id,
			name = item.name,
			line = lineOf(item),
			kind = item.kind,
			rarity = item.rarity,
			employee = employee,
			skinKey = if item.kind == "skin" then string.match(item.id, "^[^%.]+%.(.+)$") else nil,
			vacuum = if item.kind == "vacuum" then item.id else nil,
			owned = owned,
			directPrice = if isRestricted then directText else nil,
			canBuyDirect = isRestricted and not owned and balances.gleam >= direct,
			confirm = `Buy {item.name} for {directText} Gleam?`,
		})
	end
	return list
end

--[=[
	A "What's inside" item's own page (owner, 2026-11-14: locker items get a product-page view too): where it comes from,
	its chance each open (the odds sheet's per-item chance), and its one button: the direct buy where the card offers it,
	Get Gleam when that buy is too dear, else Back.
]=]
function VM.itemPage(locker: Locker, item: InsideItem, pool: { Item }?): ItemPage
	local items = pool or LockerRules.pool(locker)
	local odds = LockerRules.odds(locker, items)
	local chance: string? = nil
	for _, entry in odds.rarities do
		if table.find(entry.items, item.id) ~= nil then
			chance = `{formatPercent(entry.chance / math.max(1, #entry.items))} chance each time you open it`
		end
	end
	local button: PageButton = if item.owned or item.directPrice == nil
		then "back"
		elseif item.canBuyDirect then "buy"
		else "getGleam"
	return { from = `You can get it from the {locker.name}.`, chance = chance, button = button }
end

function VM.oddsSheet(locker: Locker, state: LockerTypes.Lockers, pool: { Item }?): OddsSheet
	local items = pool or LockerRules.pool(locker)
	local byId: { [string]: Item } = {}
	for _, item in items do
		byId[item.id] = item
	end
	local odds = LockerRules.odds(locker, items)
	local pity = state.pity[locker.id] or 0
	local pityRule = if odds.pityAt ~= nil
		then `Epic or better is guaranteed within {odds.pityAt} opens ({math.max(1, odds.pityAt - pity)} left for you).`
		else "No items in this Locker yet."

	local rows: { OddsRarityRow } = {}
	local cWord = currencyWord(locker.currency)
	for _, entry in odds.rarities do
		local count = math.max(1, #entry.items)
		local each = entry.chance / count
		local eachText = formatPercent(each)
		local itemRows: { OddsItemRow } = {}
		for _, id in entry.items do
			local item = byId[id] or CosmeticRegistry.get(id)
			table.insert(itemRows, {
				id = id,
				name = if item ~= nil then item.name else id,
				chanceText = eachText,
			})
		end
		local refund = LockerRules.refund(locker, entry.rarity)
		table.insert(rows, {
			rarity = entry.rarity,
			label = RARITY_LABEL[entry.rarity],
			chanceText = formatPercent(entry.chance),
			itemChanceText = `{eachText} each`,
			refundText = `+{ToonStyleViewModel.grouped(refund)} {cWord} back`,
			items = itemRows,
		})
	end
	return {
		locker = locker.id,
		title = `{string.upper(locker.name)} ODDS`,
		pityRule = pityRule,
		rarities = rows,
	}
end

function VM.openingView(outcome: LockerTypes.Outcome): OpeningView
	local locker = LockerRules.get(outcome.locker)
	local currency: LockerTypes.Currency = if locker ~= nil then locker.currency else "gloom"
	local cWord = currencyWord(currency)
	return {
		locker = outcome.locker,
		lockerName = if locker ~= nil then locker.name else "Locker",
		currency = currency,
		item = outcome.item,
		rarity = outcome.rarity,
		guaranteed = outcome.guaranteed,
		duplicateLine = if outcome.duplicate
			then `You already have this! +{ToonStyleViewModel.grouped(outcome.refund)} {cWord} back`
			else nil,
		skipAfter = VM.SKIP_AFTER,
		duration = VM.openingDuration(outcome.rarity),
	}
end

-- What the reveal shows once the opening ends (or is skipped or closed): the rolled item, and for a duplicate the
-- refund in the Locker's own money (the Harvest Locker's is acorns).
function VM.revealOf(outcome: LockerTypes.Outcome): CosmeticRevealStore.Reveal
	local locker = LockerRules.get(outcome.locker)
	return {
		ids = { outcome.item },
		source = "locker",
		duplicate = outcome.duplicate,
		refund = outcome.refund,
		currency = if locker ~= nil then locker.currency else "gloom",
	}
end

function VM.resultText(reason: string): string?
	if reason == "" then
		return nil
	elseif reason == "short" then
		return "Not enough yet!"
	elseif reason == "empty" then
		return "Nothing in this Locker yet!"
	elseif reason == "restricted" then
		return "Paid random items aren't available — buy items directly below!"
	elseif reason == "owned" then
		return "You already have it!"
	elseif reason == "too soon" then
		return "Hold on a second!"
	elseif reason == "locked during a shift" then
		return "Lockers open at the depot."
	elseif reason == "not on" then
		return "This Locker is closed now."
	end
	return "That didn't work. Try again!"
end

return VM
