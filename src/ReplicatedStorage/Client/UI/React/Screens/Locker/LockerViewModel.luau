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
local LockerRules = require(Locker.Rules.LockerRules)
local LockerTypes = require(Locker.Data.LockerTypes)
local ToonStyleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonStyleViewModel)

type Item = CosmeticTypes.Item
type Locker = LockerTypes.Locker
type LockerId = LockerTypes.LockerId
type Rarity = CosmeticTypes.Rarity
type Owns = (id: string) -> boolean

export type Balances = { gloom: number, gleam: number }

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

export type CutsceneBeat = "establishing" | "approach" | "key_turn" | "burst_open"

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
	OPENING_DURATION = 2.8,
	STAGE_ORIGIN = CFrame.new(3000, 0, 0),
}

local function currencyWord(currency: LockerTypes.Currency): string
	return if currency == "gleam" then "Gleam" else "Gloom"
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
	local isRestricted = locker.paidRandom and restricted
	local priceText = ToonStyleViewModel.grouped(locker.keyPrice)
	local balance = if locker.currency == "gleam" then balances.gleam else balances.gloom

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
		duration = VM.OPENING_DURATION,
	}
end

function VM.cutscenePose(lockerId: LockerId, alpha: number): CutscenePose
	local a = math.clamp(alpha, 0, 1)
	local sign = if lockerId == "gleam" then -1 else 1
	local lx = 6.5 * sign
	local kx = if lockerId == "gleam" then -6.35 else 6.65
	local keyHole = Vector3.new(kx, 5.2, 3.42)

	local beat: CutsceneBeat = "establishing"
	local camPos: Vector3
	local camLook: Vector3
	local fov = 50
	local empPos = Vector3.new(lx - sign * 1.5, 3.1, 1.35)
	local keyPos = Vector3.new(kx, 5.2, 2.3)
	local keyRollDeg = 0
	local doorDeg = 0
	local glow = false
	local flashTransparency = 1

	if a < 0.24 then
		beat = "establishing"
		local t = a / 0.24
		camPos = Vector3.new(0, 6.2, -9.5):Lerp(Vector3.new(lx * 0.55, 5.6, -6.2), t)
		camLook = Vector3.new(0, 6.2, 6.0):Lerp(Vector3.new(lx, 5.2, 4.5), t)
		fov = 52 - 6 * t
		empPos = Vector3.new(lx * 0.35, 3.0, -2.0):Lerp(Vector3.new(lx - sign * 1.6, 3.0, 0.6), t)
		keyPos = empPos + Vector3.new(sign * 0.45, 1.3, 0.85)
	elseif a < 0.50 then
		beat = "approach"
		local t = (a - 0.24) / 0.26
		camPos = Vector3.new(lx - sign * 3.1, 5.4, -3.8):Lerp(Vector3.new(lx - sign * 2.1, 5.3, -1.5), t)
		camLook = Vector3.new(lx, 5.1, 4.0):Lerp(keyHole, t)
		fov = 46 - 4 * t
		empPos = Vector3.new(lx - sign * 1.6, 3.0, 0.6):Lerp(Vector3.new(lx - sign * 1.5, 3.1, 1.35), t)
		keyPos = (empPos + Vector3.new(sign * 0.5, 1.5, 0.95)):Lerp(Vector3.new(kx, 5.2, 2.25), t)
	elseif a < 0.76 then
		beat = "key_turn"
		local t = (a - 0.50) / 0.26
		camPos = Vector3.new(kx - sign * 1.15, 5.35, 0.5):Lerp(Vector3.new(kx - sign * 0.85, 5.25, 1.1), t)
		camLook = keyHole
		fov = 38
		if t < 0.45 then
			local fly = t / 0.45
			keyPos = Vector3.new(kx, 5.2, 2.25 + 0.83 * fly)
		else
			local turn = (t - 0.45) / 0.55
			keyPos = Vector3.new(kx, 5.2, 3.08)
			keyRollDeg = math.sin(turn * math.pi * 0.5) * 90
		end
	else
		beat = "burst_open"
		local t = (a - 0.76) / 0.24
		local swing = 1 - (1 - math.min(1, t * 1.25)) ^ 3
		doorDeg = 115 * swing
		glow = true
		keyPos = Vector3.new(kx, 5.2, -100)
		camPos = Vector3.new(lx - sign * 0.6, 5.3, -1.2):Lerp(Vector3.new(lx, 5.2, 1.2), t)
		camLook = Vector3.new(lx, 5.2, 5.0)
		fov = 46 - 10 * t
		if t > 0.55 then
			local burst = (t - 0.55) / 0.45
			flashTransparency = math.clamp(1 - math.sin(burst * math.pi) * 0.85, 0.15, 1)
		end
	end

	local empLook = Vector3.new(lx, empPos.Y, 4.2)
	local employeeCFrame = CFrame.lookAt(empPos, empLook)
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
	end
	return "That didn't work. Try again!"
end

return VM
