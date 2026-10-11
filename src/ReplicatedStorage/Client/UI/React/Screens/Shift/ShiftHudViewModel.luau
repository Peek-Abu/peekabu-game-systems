--!strict
--[=[
	ShiftHudViewModel: what the approved Shift HUD (Figma 1a-1c: the time card, the clearance folder and finder's fee
	plate, the carry panel and the clock-out slip) shows, as display-ready fields per piece, from the shift snapshot and
	the local player's public entry; the phone's action-button arc (Figma 1d/1e: which buttons show, which are lit);
	the paper interaction prompt chip and the phone LOAD button's readiness (from ShiftPromptStore); the desktop key
	hints row (Figma 1a) from the live Input bindings. Pure (specced); the components only lay the fields out. The
	crew roster has its own view model (ShiftCrewViewModel); the performance review has ShiftReviewViewModel.

	@class ShiftHudViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PublicPlayerTypes = require(ReplicatedStorage.Shared.Data.PublicPlayerTypes)
local CargoShared = ReplicatedStorage.Shared.Features.Cargo
local CargoConstants = require(CargoShared.Data.CargoConstants)
local CargoRegistry = require(CargoShared.Data.CargoRegistry)
local CargoTypes = require(CargoShared.Data.CargoTypes)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local DeathConstants = require(ReplicatedStorage.Shared.Features.Death.Data.DeathConstants)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local ShiftPromptStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftPromptStore)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)

type ShiftSnapshot = ShiftTypes.ShiftSnapshot

export type HandsView = {
	name: string,
	value: string,
	traits: string,
	short: string,
	-- Whether the traits are written in red (a FRAGILE item).
	fragile: boolean,
}

export type PocketView = {
	name: string,
	empty: boolean,
}

export type HudView = {
	-- The time card.
	clockLabel: string,
	time: string,
	outText: string,
	-- The phone's compact card has one line beside the clock: OUT until overtime, then OVERTIME (Figma 1d/1e).
	compactSub: string,
	overtime: boolean,
	punched: number,
	pressure: number,
	-- The clearance folder and the finder's fee plate.
	cleared: string,
	quotaText: string,
	clearedShort: string,
	fill: number,
	quotaMet: boolean,
	fee: string,
	feeBoost: string?,
	-- The phone plate's shorter boost (Figma 1e "+140 ×1.5").
	feeBoostShort: string?,
	-- The carry panel.
	hands: HandsView?,
	pockets: { PocketView },
	canister: number,
	canisterMax: number,
	-- The clock-out slip's countdown, while one runs.
	clockOut: string?,
	truck: number?,
}

export type ButtonsView = {
	primary: "VACUUM" | "LOAD",
	primaryReady: boolean,
	-- VACUUM is always usable; LOAD only while lit (a touch hold reaches only a prompt that is shown).
	primaryAvailable: boolean,
	drop: boolean,
	throw: boolean,
	pocket: boolean,
	pocketReady: boolean,
}

-- A round button (or the Jump button's square) as its top-left corner's offset from the screen's bottom-right corner
-- and its diameter, in px.
export type ArcSpot = {
	x: number,
	y: number,
	size: number,
}

export type ArcView = {
	primary: ArcSpot,
	drop: ArcSpot,
	throw: ArcSpot,
	pocket: ArcSpot,
	-- The engine's Jump button the arc keeps clear of.
	jump: ArcSpot,
}

export type PromptChipView = {
	key: string,
	text: string,
	-- 0-1 while a hold prompt is held; 0 for a hold prompt not yet held; nil for a press prompt.
	fill: number?,
}

export type HintView = {
	prefix: string?,
	key: string,
	label: string,
}

-- A device's keyboard bindings per action id (InputServiceClient:bindingsFor(id).keyboard).
export type KeyBindings = { [string]: { Enum.KeyCode | Enum.UserInputType }? }

local ShiftHudViewModel = {}

-- "m:ss", seconds rounded up, never below 0:00.
function ShiftHudViewModel.clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

ShiftHudViewModel.PUNCH_HOLES = 5
ShiftHudViewModel.PRESSURE_PIPS = 3

local function traitsOf(def: CargoTypes.ItemDef): string
	local parts: { string } = { def.size }
	if def.fragile then
		table.insert(parts, "FRAGILE")
	end
	if def.rattly then
		table.insert(parts, "RATTLY")
	end
	return table.concat(parts, " · ")
end

local function handsOf(kind: PublicPlayerTypes.PublicValue?): HandsView?
	if type(kind) ~= "string" then
		return nil
	end
	local def = CargoRegistry.get(kind)
	if def == nil then
		return { name = kind, value = "", traits = "", short = "", fragile = false }
	end
	return {
		name = def.name,
		value = `+{def.value}`,
		traits = traitsOf(def),
		short = `+{def.value}{if def.fragile then " fragile" else ""}`,
		fragile = def.fragile,
	}
end

local function stageLabel(snapshot: ShiftSnapshot, now: number): string
	local stageEndsAt = snapshot.stageEndsAt
	local left = if stageEndsAt ~= nil then stageEndsAt - now else 0
	if snapshot.stage == "break" then
		return `HARLOW ON BREAK {ShiftHudViewModel.clock(left)}`
	elseif snapshot.stage == "warning" then
		return `OVERTIME IN {ShiftHudViewModel.clock(left)}`
	elseif snapshot.stage == "overtime" then
		return "OVERTIME"
	end
	return "SHIFT"
end

--[=[
	The HUD's pieces while a shift runs; nil otherwise, and nil while `hidden` (the scare beat, or the local player is
	caught: the CCTV takes the screen). `me` is the local player's public entry.
]=]
function ShiftHudViewModel.hud(
	snapshot: ShiftSnapshot?,
	me: PublicPlayerTypes.PublicPlayer?,
	now: number,
	hidden: boolean
): HudView?
	if hidden or snapshot == nil or snapshot.phase ~= "running" then
		return nil
	end
	local entry: PublicPlayerTypes.PublicPlayer = me or {}
	local endsAt = snapshot.endsAt
	local left = if endsAt ~= nil then endsAt - now else 0
	local total = ShiftConstants.SHIFT_SECONDS
	local elapsed = math.clamp(total - left, 0, total)
	local pockets: { PocketView } = {}
	for _, field in CargoConstants.PUBLIC_POCKET_FIELDS do
		local kind = entry[field]
		local def = if type(kind) == "string" then CargoRegistry.get(kind) else nil
		table.insert(pockets, {
			name = if def ~= nil then def.name elseif type(kind) == "string" then kind else "empty",
			empty = type(kind) ~= "string",
		})
	end
	local fill = entry[VacuumConstants.PUBLIC_FIELD]
	local clockOutAt = snapshot.clockOutAt
	local overtime = snapshot.stage == "overtime"
	return {
		clockLabel = stageLabel(snapshot, now),
		time = ShiftHudViewModel.clock(left),
		outText = `OUT {ShiftHudViewModel.clock(total)}`,
		compactSub = if overtime then "OVERTIME" else `OUT {ShiftHudViewModel.clock(total)}`,
		overtime = overtime,
		punched = math.clamp(
			math.floor(elapsed / total * ShiftHudViewModel.PUNCH_HOLES),
			0,
			ShiftHudViewModel.PUNCH_HOLES
		),
		pressure = math.clamp(snapshot.tier + 1, 1, ShiftHudViewModel.PRESSURE_PIPS),
		cleared = tostring(snapshot.cleared),
		quotaText = `/ {snapshot.quota} cleared`,
		clearedShort = `{snapshot.cleared} / {snapshot.quota}`,
		fill = if snapshot.quota > 0 then math.clamp(snapshot.cleared / snapshot.quota, 0, 1) else 1,
		quotaMet = snapshot.quotaMet,
		fee = `+{snapshot.bonus}`,
		feeBoost = if overtime then `×{ShiftConstants.OVERTIME_SALVAGE_MULTIPLIER} now` else nil,
		feeBoostShort = if overtime then `×{ShiftConstants.OVERTIME_SALVAGE_MULTIPLIER}` else nil,
		hands = handsOf(entry[CarryConstants.PUBLIC_FIELD]),
		pockets = pockets,
		canister = if type(fill) == "number" then fill else 0,
		canisterMax = VacuumConstants.CANISTER_CAPACITY,
		clockOut = if snapshot.sub == "clockout" and clockOutAt ~= nil
			then ShiftHudViewModel.clock(clockOutAt - now)
			else nil,
		truck = snapshot.truck,
	}
end

--[=[
	The phone's action buttons (Figma 1d/1e): one big button that is VACUUM with empty hands and LOAD while holding
	something (lit green when the truck's Load prompt is up, `loadReady`); DROP / THROW only with something in hand
	(THROW only for a throwable item); POCKET usable with a tiny item or something pocketed, lit when a tiny item can
	go in a free pocket.
]=]
function ShiftHudViewModel.buttons(me: PublicPlayerTypes.PublicPlayer?, loadReady: boolean): ButtonsView
	local entry: PublicPlayerTypes.PublicPlayer = me or {}
	local kind = entry[CarryConstants.PUBLIC_FIELD]
	local def = if type(kind) == "string" then CargoRegistry.get(kind) else nil
	local holding = type(kind) == "string"
	local filled, free = 0, 0
	for _, field in CargoConstants.PUBLIC_POCKET_FIELDS do
		if type(entry[field]) == "string" then
			filled += 1
		else
			free += 1
		end
	end
	local tiny = def ~= nil and def.size == "tiny"
	local primary: "VACUUM" | "LOAD" = if holding then "LOAD" else "VACUUM"
	return {
		primary = primary,
		primaryReady = holding and loadReady,
		primaryAvailable = not holding or loadReady,
		drop = holding,
		throw = def ~= nil and def.throwable,
		pocket = tiny or filled > 0,
		pocketReady = tiny and free > 0,
	}
end

--[=[
	Whether the big button is a pressable LOAD right now (the arc shows, it reads LOAD and the Load prompt is up). A
	held LOAD is let go the moment this turns false.
]=]
function ShiftHudViewModel.loadLive(view: ButtonsView?): boolean
	return view ~= nil and view.primary == "LOAD" and view.primaryAvailable
end

-- The engine's TouchGui switches to the large Jump button above this short side (px).
ShiftHudViewModel.SMALL_JUMP_SHORT_SIDE = 500

local function spot(x: number, y: number, size: number): ArcSpot
	return table.freeze({ x = x, y = y, size = size })
end

-- Figma 1d (844x390): the Jump button is 70 px at (1,-95,1,-90); LOAD/VACUUM 104 px at (608, 266), DROP (512, 282),
-- THROW (555, 194), POCKET (651, 173), 72 px each, as offsets from the bottom-right corner.
local PHONE_ARC: ArcView = table.freeze({
	primary = spot(-236, -124, 104),
	drop = spot(-332, -108, 72),
	throw = spot(-289, -196, 72),
	pocket = spot(-193, -217, 72),
	jump = spot(-95, -90, 70),
})

-- A larger touch screen: the Jump button is 120 px at (1,-170,1,-210). The big button sits left of it, DROP and THROW
-- stack above the big button, POCKET sits above the Jump button; every gap is >= 16 px, and the arc's left edge
-- (292 px in) stays right of the bottom-left 40% on any screen past 500 px, and right of the desktop carry panel on
-- a 1024 px wide tablet.
local TABLET_ARC: ArcView = table.freeze({
	primary = spot(-292, -132, 104),
	drop = spot(-262, -224, 72),
	throw = spot(-262, -316, 72),
	pocket = spot(-146, -302, 72),
	jump = spot(-170, -210, 120),
})

--[=[
	Where the action buttons sit for a touch screen whose shorter side is `shortSide` px: around the engine's small
	Jump button at 500 px or less (phones), clear of its large Jump button above that.
]=]
function ShiftHudViewModel.arcFor(shortSide: number): ArcView
	return if shortSide <= ShiftHudViewModel.SMALL_JUMP_SHORT_SIDE then PHONE_ARC else TABLET_ARC
end

--[=[
	Whether the shift HUD and the action arc are hidden: during the scare beat (`scaring`), and while the local player
	(`me`) is caught, when the CCTV takes the screen.
]=]
function ShiftHudViewModel.hidden(me: PublicPlayerTypes.PublicPlayer?, scaring: boolean): boolean
	return scaring or (me ~= nil and me[DeathConstants.PUBLIC_FIELD] == true)
end

--[=[
	The phone's action-button arc, or nil when it is not drawn: only on a touch device (`touch`), while a shift runs,
	and not while the HUD is `hidden` (the scare beat, or the local player is caught). See `buttons` for the buttons.
]=]
function ShiftHudViewModel.mobileButtons(
	snapshot: ShiftSnapshot?,
	me: PublicPlayerTypes.PublicPlayer?,
	touch: boolean,
	hidden: boolean,
	loadReady: boolean
): ButtonsView?
	if not touch or hidden or snapshot == nil or snapshot.phase ~= "running" then
		return nil
	end
	return ShiftHudViewModel.buttons(me, loadReady)
end

--[=[
	The paper prompt chip (Figma 1a: "[E] LOAD monitor onto the truck"): a Load names the item in hand; anything else
	is the prompt's action in capitals and its object in lower case. Nil without a prompt, and nil while `hidden` (the
	scare beat, or the local player is caught). `now` and the view's `holdStartedAt` are both on the server clock.
]=]
function ShiftHudViewModel.prompt(
	view: ShiftPromptStore.PromptView?,
	carrying: PublicPlayerTypes.PublicValue?,
	now: number,
	hidden: boolean?
): PromptChipView?
	if view == nil or hidden == true then
		return nil
	end
	local text = `{string.upper(view.action)} {string.lower(view.object)}`
	if view.kind == CargoConstants.LOAD_KIND and type(carrying) == "string" then
		local def = CargoRegistry.get(carrying)
		text = `LOAD {string.lower(if def ~= nil then def.name else carrying)} onto the truck`
	end
	local fill: number? = nil
	if view.hold > 0 then
		local started = view.holdStartedAt
		fill = if started ~= nil then math.clamp((now - started) / view.hold, 0, 1) else 0
	end
	return { key = view.key, text = text, fill = fill }
end

--[=[
	Whether the phone's big button can LOAD: only while the truck's Load prompt is the one shown (the engine takes a
	touch hold on a prompt only while that prompt is shown on this client).
]=]
function ShiftHudViewModel.loadReady(view: ShiftPromptStore.PromptView?): boolean
	return view ~= nil and view.kind == CargoConstants.LOAD_KIND
end

local KEY_NAMES: { [string]: string } = {
	MouseButton1 = "LMB",
	MouseButton2 = "RMB",
	Left = "←",
	Right = "→",
	LeftShift = "Shift",
}

-- A key's legend as the HUD prints it on a KeyChip.
function ShiftHudViewModel.keyName(input: Enum.KeyCode | Enum.UserInputType): string
	return KEY_NAMES[input.Name] or input.Name
end

-- Figma 1a's hint row, in order: the action id, how to say it, and whether it is held.
local HINTS: { { action: string, label: string, hold: boolean } } = {
	{ action = VacuumConstants.ACTION, label = "vacuum", hold = true },
	{ action = "drop", label = "drop", hold = false },
	{ action = "throw", label = "throw", hold = false },
	{ action = CargoConstants.POCKET_ACTION, label = "pocket", hold = false },
	{ action = "interact", label = "load / search", hold = false },
}

local hintActions: { string } = {}
for _, hint in HINTS do
	table.insert(hintActions, hint.action)
end
-- The action ids the hint row reads bindings for (ShiftHud asks InputServiceClient for each).
ShiftHudViewModel.HINT_ACTIONS = table.freeze(hintActions)

local function firstKey(bindings: KeyBindings, action: string): (Enum.KeyCode | Enum.UserInputType)?
	local list = bindings[action]
	return if list ~= nil then list[1] else nil
end

--[=[
	The desktop key hints row (Figma 1a), one per action with a keyboard binding: "Hold LMB vacuum", "G drop", ...
]=]
function ShiftHudViewModel.keyHints(bindings: KeyBindings): { HintView }
	local hints: { HintView } = {}
	for _, hint in HINTS do
		local first = firstKey(bindings, hint.action)
		if first ~= nil then
			table.insert(hints, {
				prefix = if hint.hold then "Hold" else nil,
				key = ShiftHudViewModel.keyName(first),
				label = hint.label,
			})
		end
	end
	return hints
end

--[=[
	How far (px) the centred pieces (time card, SALVAGE stamp, clock-out slip) move right so the widest of them, the
	500 px slip, clears the left column (the folder and fee plate) by a 16 px gap; 0 on a wide screen.
]=]
function ShiftHudViewModel.centreShift(viewportWidth: number): number
	local HUD = UIPaperConstants.HUD
	local leftColumnRight = HUD.LEFT + HUD.FOLDER_WIDTH
	return math.max(0, (leftColumnRight + HUD.GAP) - (viewportWidth / 2 - HUD.SLIP_WIDTH / 2))
end

--[=[
	The carry panel's left edge (px): the corner inset on a tall viewport; on a short one (a windowed laptop), right of
	the crew roster column so a full roster (4 rows) is not covered.
]=]
function ShiftHudViewModel.carryLeft(viewport: Vector2): number
	local HUD = UIPaperConstants.HUD
	local rosterBottom = HUD.ROSTER_TOP + HUD.ROSTER_HEADER + HUD.ROSTER_MAX_ROWS * HUD.ROSTER_ROW
	if viewport.Y >= rosterBottom + HUD.GAP + HUD.CARRY_HEIGHT + HUD.CARRY_INSET then
		return HUD.CARRY_INSET
	end
	return HUD.ROSTER_LEFT + HUD.ROSTER_WIDTH + HUD.GAP
end

--[=[
	Whether the prompt chip is a touch button: only on a touch device without a keyboard. Anywhere else the chip is a
	plain Frame, because a GuiButton under the cursor sinks the mouse click (the vacuum is LMB) even when it ignores it.
]=]
function ShiftHudViewModel.promptTouchable(touch: boolean, keyboard: boolean): boolean
	return touch and not keyboard
end

-- The hint row is drawn on desktop with a keyboard only.
function ShiftHudViewModel.showHints(layout: UIPaperConstants.Layout, keyboard: boolean): boolean
	return layout == "desktop" and keyboard
end

-- The carry panel's "Q pocket" caption key: the pocket action's first keyboard binding, Q when it has none.
function ShiftHudViewModel.pocketKey(bindings: KeyBindings): string
	local first = firstKey(bindings, CargoConstants.POCKET_ACTION)
	return if first ~= nil then ShiftHudViewModel.keyName(first) else "Q"
end

return ShiftHudViewModel
