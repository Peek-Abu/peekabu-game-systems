--!strict
--[=[
	LockerViewModel: everything the Shop's Lockers tab, the Odds sheet and the stage-1 opening screen show, computed
	from `LockerRules` and the player's synced state (design:
	docs/superpowers/specs/2026-10-25-odd-hours-lockers-design.md).

	@class LockerViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local CosmeticTypes = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticTypes)
local Locker = ReplicatedStorage.Shared.Features.Locker
local LockerConstants = require(Locker.Data.LockerConstants)
local LockerRules = require(Locker.Rules.LockerRules)
local LockerTypes = require(Locker.Data.LockerTypes)
local ToonStyleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonStyleViewModel)
local CosmeticRevealStore = require(ReplicatedStorage.Client.Features.Cosmetic.State.CosmeticRevealStore)

type Item = CosmeticTypes.Item
type Locker = LockerTypes.Locker
type LockerId = LockerTypes.LockerId
type Rarity = CosmeticTypes.Rarity
type Owns = (id: string) -> boolean

-- `acorns`: a live event's money (absent reads 0).
export type Balances = { gloom: number, gleam: number, acorns: number? }

export type ButtonKind = "key" | "buy" | "short" | "restricted" | "empty"

export type OpenButton = {
	text: string,
	enabled: boolean,
	kind: ButtonKind,
	currency: LockerTypes.Currency,
	price: string,
}

export type LockerCard = {
	id: LockerId,
	name: string,
	currency: LockerTypes.Currency,
	keys: number,
	keysText: string,
	keyPrice: string,
	pityText: string,
	restricted: boolean,
	button: OpenButton,
}

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

export type CutsceneBeat = "establishing" | "approach" | "key_turn" | "rattle" | "burst_open"

-- How a rarity plays its opening (owner picks 11-16: the rarer the prize, the longer the hold before the burst, the
-- harder the rattle and the more and brighter the lights).
export type RarityFx = {
	-- Seconds the shut door rattles, light leaking out, between the key turn and the burst.
	hold: number,
	-- Light shafts leaking from the door's seams.
	lights: number,
	-- The leak's and the burst's light brightness.
	brightness: number,
	-- How far the rattling door jumps open, in degrees.
	rattleDeg: number,
	-- Camera shake at the height of the rattle, in studs.
	shake: number,
	-- Neon rays at the burst.
	rays: number,
	-- How opaque the burst's colour flash gets (0..1).
	flash: number,
	-- The prize chime's layers at the burst (sound ids, LockerAssets).
	chime: { string },
}

export type CutscenePose = {
	beat: CutsceneBeat,
	camPos: Vector3,
	camLook: Vector3,
	fov: number,
	employeeCFrame: CFrame,
	keyCFrame: CFrame,
	keyRollDeg: number,
	doorDeg: number,
	glow: boolean,
	flashTransparency: number,
	-- 0..1: how bright the light leaks out round the shut door (the rattle beat; 1 at the burst).
	leak: number,
	-- 0..1: the leaking light's colour, plain white (0) to the prize's rarity colour (1): white through the hold, the
	-- rarity showing through in the last GLIMPSE_SECONDS before the door opens (owner 11-16).
	leakTint: number,
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

-- Uncommon has no chime (owner 11-16 hated the Uncommon one); Rare a plain chime; the sparkly Aura layer only on Epic
-- and up (the sound rarity rule).
local RARITY_FX: { [Rarity]: RarityFx } = {
	default = {
		hold = 0.5,
		lights = 2,
		brightness = 2,
		rattleDeg = 1.5,
		shake = 0,
		rays = 3,
		flash = 0.55,
		chime = {},
	},
	uncommon = {
		hold = 0.5,
		lights = 2,
		brightness = 2,
		rattleDeg = 1.5,
		shake = 0,
		rays = 3,
		flash = 0.55,
		chime = {},
	},
	rare = {
		hold = 0.8,
		lights = 3,
		brightness = 3,
		rattleDeg = 2.5,
		shake = 0.02,
		rays = 5,
		flash = 0.65,
		chime = { "lockerChimeHigh" },
	},
	epic = {
		hold = 1.2,
		lights = 5,
		brightness = 4.5,
		rattleDeg = 4,
		shake = 0.06,
		rays = 7,
		flash = 0.8,
		chime = { "lockerChimeHigh", "lockerChimeAura" },
	},
	legendary = {
		hold = 1.7,
		lights = 8,
		brightness = 7,
		rattleDeg = 6,
		shake = 0.12,
		rays = 10,
		flash = 0.88,
		chime = { "lockerChimeHigh", "lockerChimeAura" },
	},
	odd = {
		hold = 1.7,
		lights = 8,
		brightness = 7,
		rattleDeg = 6,
		shake = 0.12,
		rays = 10,
		flash = 0.88,
		chime = { "lockerChimeHigh", "lockerChimeAura" },
	},
}

-- The fixed beats, in seconds; the rattle's hold sits between the key turn and the burst.
local ESTABLISH_SECONDS = 0.8
local APPROACH_SECONDS = 0.9
local KEY_SECONDS = 1.0
local BURST_SECONDS = 0.8
-- The rarity's colour shows through the seams this long before the door opens (owner 11-16: "half a second before
-- the actual locker opens you get a small glimpse of the rarity leaking through").
local GLIMPSE_SECONDS = 0.5
-- How long the leak takes to turn from white to the rarity's colour.
local GLIMPSE_BLEND = 0.15

local VM = {
	OPENING_SCENE = "lockerOpening",
	SKIP_AFTER = 1.0,
	BURST_SECONDS = BURST_SECONDS,
	GLIMPSE_SECONDS = GLIMPSE_SECONDS,
	-- The hub music's duck while a Locker opens (owner 11-16: "Yes, fade it"): dB on the Music group, eased down over
	-- MUSIC_DUCK_IN seconds and back over MUSIC_DUCK_OUT once the reveal closes. The track keeps playing underneath.
	MUSIC_DUCK_DB = -30,
	MUSIC_DUCK_IN = 0.6,
	MUSIC_DUCK_OUT = 1.5,
	RARITY_FX = RARITY_FX,
	STAGE_ORIGIN = CFrame.new(3000, 0, 0),
}

-- The whole opening's length for a prize of `rarity` (about 4 seconds for Uncommon).
function VM.openingDuration(rarity: Rarity): number
	return ESTABLISH_SECONDS + APPROACH_SECONDS + KEY_SECONDS + RARITY_FX[rarity].hold + BURST_SECONDS
end

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

function VM.card(
	locker: Locker,
	state: LockerTypes.Lockers,
	balances: Balances,
	restricted: boolean,
	pool: { Item }?
): LockerCard
	local items = pool or LockerRules.pool(locker)
	local odds = LockerRules.odds(locker, items)
	local keys = state.keys[locker.id] or 0
	local pity = state.pity[locker.id] or 0
	-- An empty Locker has nothing to buy directly either, so it reads as empty (not "Buy items directly below").
	local isRestricted = locker.paidRandom and restricted and #items > 0
	local priceText = ToonStyleViewModel.grouped(locker.keyPrice)
	local balance = if locker.currency == "gleam"
		then balances.gleam
		elseif locker.currency == "acorns" then balances.acorns or 0
		else balances.gloom

	local pityText = "Nothing inside yet."
	if isRestricted then
		pityText = "Buy items directly below."
	elseif odds.pityAt ~= nil then
		local remaining = math.max(1, odds.pityAt - pity)
		pityText = if remaining == 1
			then "Epic or better on the next open!"
			else `Epic or better in {remaining} opens or sooner.`
	end

	local button: OpenButton
	if #items == 0 then
		button = {
			text = "Coming soon",
			enabled = false,
			kind = "empty",
			currency = locker.currency,
			price = priceText,
		}
	elseif isRestricted then
		button = {
			text = "Buy directly",
			enabled = false,
			kind = "restricted",
			currency = locker.currency,
			price = priceText,
		}
	elseif keys > 0 then
		button = {
			text = "Open (1 key)",
			enabled = true,
			kind = "key",
			currency = locker.currency,
			price = priceText,
		}
	elseif balance >= locker.keyPrice then
		button = {
			text = "Open",
			enabled = true,
			kind = "buy",
			currency = locker.currency,
			price = priceText,
		}
	else
		local missing = locker.keyPrice - balance
		button = {
			text = `Need {ToonStyleViewModel.grouped(missing)} more`,
			enabled = locker.currency == "gleam",
			kind = "short",
			currency = locker.currency,
			price = priceText,
		}
	end

	local keysText = if keys == 0 then "No keys" elseif keys == 1 then "1 key" else `{keys} keys`
	return {
		id = locker.id,
		name = locker.name,
		currency = locker.currency,
		keys = keys,
		keysText = keysText,
		keyPrice = priceText,
		pityText = pityText,
		restricted = isRestricted,
		button = button,
	}
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

--[=[
	The 3D cutscene at `alpha` (0..1 of `VM.openingDuration(rarity)`) for `lockerId`'s Locker (the Gleam Locker sits at
	-X, every other one at +X). Beats: establishing, approach (the key floats in from screen right, away from the
	employee, who only idles: owner 11-16), key_turn,
	rattle (the shut door jumps against its latch, harder and longer the rarer the prize, light in the prize's colour
	leaking round it) and burst_open. Both doors hinge on their -X edge, so the employee waits on the latch side (+X),
	facing the keyhole, and every shot comes from the hinge side: the employee is never between the camera and what it
	looks at (owner check 11-16: the camera sat behind, then inside, the employee's head). `doorDeg` swings the door
	out toward the camera.
]=]
function VM.cutscenePose(lockerId: LockerId, alpha: number, rarity: Rarity?): CutscenePose
	local tier: Rarity = rarity or "uncommon"
	local fx = RARITY_FX[tier]
	local seconds = math.clamp(alpha, 0, 1) * VM.openingDuration(tier)
	local lx = if lockerId == "gleam" then -6.5 else 6.5
	local kx = lx + 0.15
	local keyHole = Vector3.new(kx, 5.2, 3.42)
	local keyFront = Vector3.new(kx, 5.2, 2.25)
	local keyIn = Vector3.new(kx, 5.2, 3.08)
	-- A step aside and back from the latch seam, so the leaking light shows and the burst shot keeps them out of frame
	-- (Play check 11-16).
	local empPos = Vector3.new(lx + 3.4, 3.1, -0.2)
	-- Where the key floats in from: the hinge side (-X), which is screen right in every shot, never the employee.
	local keyStart = Vector3.new(kx - 4.5, 6.4, 0.5)
	local hidden = Vector3.new(kx, -100, 0)

	local rattleAt = ESTABLISH_SECONDS + APPROACH_SECONDS + KEY_SECONDS
	local burstAt = rattleAt + fx.hold

	local beat: CutsceneBeat
	local camPos: Vector3
	local camLook: Vector3
	local fov: number
	local keyPos = hidden
	local keyRollDeg = 0
	local doorDeg = 0
	local glow = false
	local flashTransparency = 1
	local leak = 0
	local leakTint = 0

	if seconds < ESTABLISH_SECONDS then
		beat = "establishing"
		local t = seconds / ESTABLISH_SECONDS
		camPos = Vector3.new(lx - 5.5, 6.6, -9.5):Lerp(Vector3.new(lx - 3.2, 6.0, -6.5), t)
		camLook = Vector3.new(lx - 1, 5.6, 4):Lerp(Vector3.new(lx + 0.5, 5.2, 3.5), t)
		fov = 50 - 4 * t
	elseif seconds < ESTABLISH_SECONDS + APPROACH_SECONDS then
		beat = "approach"
		local t = (seconds - ESTABLISH_SECONDS) / APPROACH_SECONDS
		camPos = Vector3.new(lx - 3.2, 6.0, -6.5):Lerp(Vector3.new(lx - 2.2, 5.6, -3.0), t)
		camLook = Vector3.new(lx + 0.5, 5.2, 3.5):Lerp(keyHole, t)
		fov = 46 - 4 * t
		keyPos = keyStart:Lerp(keyFront, t * t * (3 - 2 * t))
	elseif seconds < rattleAt then
		beat = "key_turn"
		local t = (seconds - ESTABLISH_SECONDS - APPROACH_SECONDS) / KEY_SECONDS
		-- Far enough back that the key and the lock read together (Play check 11-16: the key filled a third of the screen).
		camPos = Vector3.new(kx - 2.0, 5.7, -0.6):Lerp(Vector3.new(kx - 1.6, 5.5, 0.3), t)
		camLook = keyHole
		fov = 40
		if t < 0.45 then
			keyPos = keyFront:Lerp(keyIn, t / 0.45)
		else
			local turn = (t - 0.45) / 0.55
			keyPos = keyIn
			keyRollDeg = math.sin(turn * math.pi * 0.5) * 90
		end
	elseif seconds < burstAt then
		beat = "rattle"
		local t = (seconds - rattleAt) / fx.hold
		-- Builds up: a faint, gentle rattle that grows to the rarity's full shake and glow.
		local grow = 0.25 + 0.75 * t ^ 1.5
		-- From the hinge side, so the employee stands clear of the latch seam where the light leaks (Play check 11-16).
		camPos = Vector3.new(lx - 1.3, 5.6, -5.2):Lerp(Vector3.new(lx - 1.1, 5.7, -4.2), t)
		camLook = Vector3.new(lx, 5.1, 4.0)
		fov = 44
		keyPos = keyIn
		keyRollDeg = 90
		-- The door jumps open against its latch and falls back (0 or more: never into the locker's body).
		doorDeg = fx.rattleDeg * grow * (0.5 + 0.5 * math.sin(seconds * math.pi * 2 * 9))
		leak = grow
		leakTint = math.clamp((seconds - (burstAt - GLIMPSE_SECONDS)) / GLIMPSE_BLEND, 0, 1)
		local shake = fx.shake * grow
		camPos += Vector3.new(math.sin(seconds * 71) * shake, math.sin(seconds * 53 + 1.3) * shake, 0)
	else
		beat = "burst_open"
		local t = math.min(1, (seconds - burstAt) / BURST_SECONDS)
		local swing = 1 - (1 - math.min(1, t * 1.25)) ^ 3
		doorDeg = 115 * swing
		glow = true
		leak = 1
		leakTint = 1
		keyPos = Vector3.new(kx, 5.2, -100)
		camPos = Vector3.new(lx - 0.4, 5.7, -4.2):Lerp(Vector3.new(lx - 0.15, 5.45, -3.0), t)
		camLook = Vector3.new(lx, 5.0, 5.0)
		fov = 44 - 8 * t
		if t > 0.55 then
			local burst = (t - 0.55) / 0.45
			flashTransparency = math.clamp(1 - math.sin(burst * math.pi) * fx.flash, 1 - fx.flash, 1)
		end
	end

	local employeeCFrame = CFrame.lookAt(empPos, Vector3.new(kx, empPos.Y, keyHole.Z))
	local keyCFrame = CFrame.lookAt(keyPos, keyPos + Vector3.new(0, 0, 1)) * CFrame.Angles(0, 0, math.rad(keyRollDeg))

	return {
		beat = beat,
		camPos = camPos,
		camLook = camLook,
		fov = fov,
		employeeCFrame = employeeCFrame,
		keyCFrame = keyCFrame,
		keyRollDeg = keyRollDeg,
		doorDeg = doorDeg,
		glow = glow,
		flashTransparency = flashTransparency,
		leak = leak,
		leakTint = leakTint,
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
