--!strict
--[=[
	ShiftHudViewModel: what the approved Shift HUD (Figma 1a-1c: the time card, the clearance folder and finder's fee
	plate, the hands item and the clock-out slip; the hotbar is ShiftHotbarViewModel's) shows, as display-ready fields per piece, from the shift snapshot and
	the local player's public entry; the phone's action-button arc (Figma 1d/1e: which buttons show, which are lit);
	the paper interaction prompt chip (from ShiftPromptStore) and when the arc takes its place; the desktop key
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
local CargoInventoryRules = require(CargoShared.Rules.CargoInventoryRules)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local DeathConstants = require(ReplicatedStorage.Shared.Features.Death.Data.DeathConstants)
local DepotMapRules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotMapRules)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local ShiftCurrencyUtils = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftCurrencyUtils)
local ShiftQuotaFormulas = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftQuotaFormulas)
local SprintConstants = require(ReplicatedStorage.Shared.Features.Sprint.Data.SprintConstants)
local SprintRules = require(ReplicatedStorage.Shared.Features.Sprint.Rules.SprintRules)
local CrouchConstants = require(ReplicatedStorage.Shared.Features.Crouch.Data.CrouchConstants)
local CrouchRules = require(ReplicatedStorage.Shared.Features.Crouch.Rules.CrouchRules)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local ShiftPromptStore = require(ReplicatedStorage.Client.Features.Shift.State.ShiftPromptStore)
local UIPaperConstants = require(ReplicatedStorage.Client.UI.React.Screens.Paper.UIPaperConstants)
local ShiftHotbarViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Shift.ShiftHotbarViewModel)

type ShiftSnapshot = ShiftTypes.ShiftSnapshot

export type HandsView = {
	kind: string,
	name: string,
	value: string,
	traits: string,
	short: string,
	-- Whether the traits are written in red (a FRAGILE item).
	fragile: boolean,
}

export type HudView = {
	vacuumEquipped: boolean,
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
	-- The plate's label ("EARNED", ShiftCurrencyUtils) over the crew's running total ("240 Credits": the Gloom removed so
	-- far plus the valuables banked).
	feeLabel: string,
	fee: string,
	feeBoost: string?,
	-- The phone plate's shorter boost (Figma 1e "+140 ×1.5").
	feeBoostShort: string?,
	-- The hands item and the hotbar.
	hands: HandsView?,
	hotbar: ShiftHotbarViewModel.HotbarView,
	-- The server-clock time the shift clock counts down to (a live clock ticks on it by itself, ShiftCountdown, so
	-- the HUD does not re-render each second).
	endsAt: number?,
	truck: number?,
	-- On a training run: the stop the player is on (the meter shows the stops, not the shift's Gloom goal).
	training: number?,
	-- The run's map (the `shiftTransit` entry; nil: the office): it picks the meter's site line.
	map: ShiftTypes.MapId?,
}

export type ButtonsView = {
	-- The big button (phone Layout 2): VACUUM, or THROW while a throwable item is in hand.
	primary: "VACUUM" | "THROW",
	-- VACUUM with a big item in hand cannot be used (it fills both hands); everything else can.
	primaryAvailable: boolean,
	-- SPRINT (held): whenever the player is not hiding (a load slows it, it never forbids it), unless the move stick
	-- runs (SprintConstants.STICK_RUN).
	sprint: boolean,
	-- CROUCH (a toggle, lit while crouched): whenever the player is not hiding (the server refuses it with a big item).
	crouch: boolean,
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
	-- The helper button (ShiftHelperViewModel): HIDE / LEAVE / SEARCH / PICK UP / BANK ..., only while there is one.
	helper: ArcSpot,
	-- Drawn only while the move stick does not run (SprintConstants.STICK_RUN).
	sprint: ArcSpot,
	-- CROUCH: right above the engine's Jump button.
	crouch: ArcSpot,
	-- The employee's ability (AbilityButton).
	ability: ArcSpot,
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

-- The Gloom meter plate (ShiftGloomMeter), top centre, in HUD design px: its size, its top edge and its Gloom render's
-- size (the render breaks the plate's left edge by 38% of itself). What opens beside or under it (the crew roster)
-- lays out against these.
ShiftHudViewModel.METER = table.freeze({
	phone = table.freeze({ size = Vector2.new(400, 70), top = 28, icon = 70 }),
	desktop = table.freeze({ size = Vector2.new(620, 96), top = 40, icon = 100 }),
})
ShiftHudViewModel.METER_ICON_OVERHANG = 0.38
-- A training run has no goal bar (owner 2026-11-15): on a phone Prickles' card takes the meter's place, its top at the
-- meter's top and this tall (design px, its head and name tab included: TrainingCoach's phone card), and the hearts drop
-- TRAINING_LIVES_DROP under it. On desktop the card stays bottom-left and the hearts stay put.
ShiftHudViewModel.TRAINING_COACH_TALL = table.freeze({ phone = 115 })
ShiftHudViewModel.TRAINING_LIVES_DROP = 40

-- The local player's Gloom-life hearts, just under the meter (HUD design px): a heart's side (`pip`; never under 20),
-- the gap between hearts (the phone's is negative: each heart overlaps the last by 6 px, the leftmost on top), the extra outline drawn around each (`stroke`: 0, the toon heart renders carry their ink
-- outline baked in), the gap under the meter (clear of its 7 px drop shadow) and the gap the clock-out board keeps under
-- the hearts.
ShiftHudViewModel.LIVES = table.freeze({
	phone = table.freeze({ pip = 20, gap = -6, stroke = 0, below = 8, boardGap = 8 }),
	desktop = table.freeze({ pip = 28, gap = 4, stroke = 0, below = 8, boardGap = 8 }),
})
-- The pip row's loss pop: scale up to this and back over this many seconds.
ShiftHudViewModel.LIVES_POP = table.freeze({ scale = 1.25, seconds = 0.25 })

-- The pip row's scale `t` (0-1) into a life-loss pop: 1 up to LIVES_POP.scale at the midpoint and back to 1.
function ShiftHudViewModel.lossPop(t: number): number
	return 1 + (ShiftHudViewModel.LIVES_POP.scale - 1) * math.sin(math.pi * math.clamp(t, 0, 1))
end

--[=[
	Where the local player's Gloom-life pips go on a `viewport` (HUD design px): the top-left corner and size of the row
	for a full set of lives (ShiftConstants.STARTING_LIVES), centred under the Gloom meter, `below` clear of its plate and
	drop shadow. It sits in the band the clock-out board used to open at (see `boardTop`), clear of the crew list and the
	open roster.
]=]
function ShiftHudViewModel.livesFrame(
	layout: UIPaperConstants.Layout,
	viewport: Vector2,
	training: boolean?
): (Vector2, Vector2)
	local lives = if layout == "phone" then ShiftHudViewModel.LIVES.phone else ShiftHudViewModel.LIVES.desktop
	local meter = if layout == "phone" then ShiftHudViewModel.METER.phone else ShiftHudViewModel.METER.desktop
	local count = ShiftConstants.STARTING_LIVES
	local box = lives.pip + 2 * lives.stroke
	local size = Vector2.new(count * box + (count - 1) * lives.gap, box)
	local drop = if training == true and layout == "phone" then ShiftHudViewModel.TRAINING_LIVES_DROP else 0
	return Vector2.new(viewport.X / 2 - size.X / 2, meter.top + meter.size.Y + lives.below + drop), size
end

--[=[
	The clock-out board's top edge (HUD design px): `boardGap` under the Gloom-life pips, so the board never sits on them.
]=]
function ShiftHudViewModel.boardTop(layout: UIPaperConstants.Layout, viewport: Vector2): number
	local lives = if layout == "phone" then ShiftHudViewModel.LIVES.phone else ShiftHudViewModel.LIVES.desktop
	local at, size = ShiftHudViewModel.livesFrame(layout, viewport)
	return at.Y + size.Y + lives.boardGap
end

-- "m:ss", seconds rounded up, never below 0:00.
function ShiftHudViewModel.clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

-- A countdown wakes this long after the second it waits for, so the new second is surely shown.
ShiftHudViewModel.TICK_SLACK = 0.02

--[=[
	How long until a countdown with `seconds` left shows a different `clock` (just past that second); nil once it shows
	0:00 (it never changes again). A live clock (ShiftCountdown) sleeps exactly this, so it re-renders once a second,
	on the second.
]=]
function ShiftHudViewModel.untilTick(seconds: number): number?
	if seconds <= 0 then
		return nil
	end
	local fraction = seconds - math.floor(seconds)
	return (if fraction > 0 then fraction else 1) + ShiftHudViewModel.TICK_SLACK
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
		return { kind = kind, name = kind, value = "", traits = "", short = "", fragile = false }
	end
	-- A valuable's worth is rolled, scaled and grimy: "??? Credits" here, its real number on its tag (the loot loop).
	local value = if def.grimy then ShiftCurrencyUtils.unknown() else `+{def.value}`
	return {
		kind = kind,
		name = def.name,
		value = value,
		traits = traitsOf(def),
		short = `{value}{if def.fragile then " fragile" else ""}`,
		fragile = def.fragile,
	}
end

local function stageLabel(snapshot: ShiftSnapshot, now: number): string
	local stageEndsAt = snapshot.stageEndsAt
	local left = if stageEndsAt ~= nil then stageEndsAt - now else 0
	if snapshot.stage == "break" then
		return `MANAGER ON BREAK {ShiftHudViewModel.clock(left)}`
	elseif snapshot.stage == "warning" then
		return `OVERTIME IN {ShiftHudViewModel.clock(left)}`
	elseif snapshot.stage == "overtime" then
		return "OVERTIME"
	elseif snapshot.quotaMet then
		-- Quota met, the break over: overtime waits on the crew's choice at the truck.
		return "OVERTIME OPTIONAL"
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
	local overtime = snapshot.stage == "overtime"
	return {
		vacuumEquipped = entry[VacuumConstants.PUBLIC_EQUIPPED_FIELD] == true,
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
		cleared = tostring(math.floor(snapshot.cleared)),
		quotaText = `/ {snapshot.quota} {ShiftConstants.CONTRACT_UNIT}`,
		clearedShort = ShiftCurrencyUtils.gloom(snapshot.cleared, snapshot.quota),
		fill = if snapshot.quota > 0 then math.clamp(snapshot.cleared / snapshot.quota, 0, 1) else 1,
		quotaMet = snapshot.quotaMet,
		feeLabel = ShiftCurrencyUtils.earnedLabel(),
		-- Earned so far: every Gloom removed (paid at clock-out) plus the valuables banked.
		fee = ShiftCurrencyUtils.amount(ShiftQuotaFormulas.breakdown(snapshot.cleared, 0, snapshot.bonus).credits),
		feeBoost = if overtime then `New loot ×{ShiftConstants.OVERTIME_SALVAGE_MULTIPLIER}` else nil,
		feeBoostShort = if overtime then `NEW ×{ShiftConstants.OVERTIME_SALVAGE_MULTIPLIER}` else nil,
		hands = handsOf(entry[CarryConstants.PUBLIC_FIELD]),
		hotbar = ShiftHotbarViewModel.hotbar(entry, snapshot.cleared, snapshot.quota),
		endsAt = endsAt,
		truck = snapshot.truck,
	}
end

--[=[
	The phone's action buttons (Layout 2, owner pick 11-15): one big button that is VACUUM, or THROW while a throwable
	item is in hand (VACUUM with a small item in hand puts it away first; under a big item it is dim); SPRINT only while
	the move stick does not run, and CROUCH, whenever not `hiding`. Drop is a long press on the item's hotbar slot, and
	the prompts (HIDE, SEARCH, BANK ...) ride the helper button (ShiftHelperViewModel).
]=]
function ShiftHudViewModel.buttons(me: PublicPlayerTypes.PublicPlayer?, hiding: boolean?): ButtonsView
	local entry: PublicPlayerTypes.PublicPlayer = me or {}
	local kind = entry[CarryConstants.PUBLIC_FIELD]
	local def = if type(kind) == "string" then CargoRegistry.get(kind) else nil
	local throwable = def ~= nil and def.throwable == true
	local big = def ~= nil and not CargoInventoryRules.isSmall(def)
	return {
		primary = if throwable then "THROW" else "VACUUM",
		primaryAvailable = throwable or not big,
		sprint = SprintRules.offered(hiding == true, SprintConstants.STICK_RUN.enabled),
		crouch = CrouchRules.offered(hiding == true),
	}
end

-- The engine's TouchGui switches to the large Jump button above this short side (px).
ShiftHudViewModel.SMALL_JUMP_SHORT_SIDE = 500

local function spot(x: number, y: number, size: number): ArcSpot
	return table.freeze({ x = x, y = y, size = size })
end

-- Figma 1d (844x390): the Jump button is 70 px at (1,-95,1,-90); VACUUM 104 px at (608, 266), as offsets from the
-- bottom-right corner.
local PHONE_ARC: ArcView = table.freeze({
	primary = spot(-236, -124, 104),
	-- HELPER (Layout 2): up and left of the big button, where THROW was, above the hotbar (DROP's old spot sat on it).
	helper = spot(-291, -198, 76),
	-- SPRINT: up and left of DROP, clear of THROW and of the thumbstick zone on the narrowest landscape phones.
	sprint = spot(-380, -196, 72),
	-- CROUCH: over the Jump button, 18 px above it (the thumb's natural reach: jump and crouch on one column).
	crouch = spot(-95, -180, 72),
	-- ABILITY: 64 px, in the pocket between THROW, CROUCH and the big button, under the crew list (top-right) and
	-- right of the clock-out board on a 667 px phone; above CROUCH it would run into the crew list.
	ability = spot(-168, -222, 64),
	jump = spot(-95, -90, 70),
})

-- A larger touch screen: the Jump button is 120 px at (1,-170,1,-210). The big button sits left of it, DROP and THROW
-- stack above the big button; every gap is >= 16 px, and the arc's left edge
-- (292 px in) stays right of the bottom-left 40% on any screen past 500 px, and right of the desktop carry panel on
-- a 1024 px wide tablet.
local TABLET_ARC: ArcView = table.freeze({
	primary = spot(-292, -132, 104),
	-- HELPER: above the big button, where DROP was.
	helper = spot(-264, -226, 76),
	-- SPRINT: above THROW (the arc's left edge stays inside the right 60% down to 501 px).
	sprint = spot(-262, -408, 72),
	-- CROUCH: centred over the large Jump button, 20 px above it.
	crouch = spot(-146, -302, 72),
	-- ABILITY: 20 px above CROUCH.
	ability = spot(-146, -394, 72),
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
	hiding: boolean?
): ButtonsView?
	if not touch or hidden or snapshot == nil or snapshot.phase ~= "running" then
		return nil
	end
	return ShiftHudViewModel.buttons(me, hiding)
end

--[=[
	Whether the HIDE and interaction chips give way to the arc's helper button: while a shift runs, on a touch screen
	without a keyboard (where the chips would be touch buttons, `promptTouchable`). A keyboard player keeps the chips,
	whose key legends say what to press.
]=]
function ShiftHudViewModel.chipsOnArc(snapshot: ShiftSnapshot?, touch: boolean, keyboard: boolean): boolean
	return snapshot ~= nil and snapshot.phase == "running" and ShiftHudViewModel.promptTouchable(touch, keyboard)
end

--[=[
	The paper prompt chip (Figma 1a: "[E] BANK monitor"): the truck's Bank prompt names the item in hand; anything else
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
		text = `BANK {string.lower(if def ~= nil then def.name else carrying)}`
	end
	local fill: number? = nil
	if view.hold > 0 then
		local started = view.holdStartedAt
		fill = if started ~= nil then math.clamp((now - started) / view.hold, 0, 1) else 0
	end
	return { key = view.key, text = text, fill = fill }
end

local KEY_NAMES: { [string]: string } = {
	MouseButton1 = "LMB",
	MouseButton2 = "RMB",
	Left = "←",
	Right = "→",
	LeftShift = "Shift",
	LeftControl = "Ctrl",
	-- Gamepad buttons, as a controller prints them (Xbox names; the engine maps them on PlayStation).
	ButtonA = "A",
	ButtonB = "B",
	ButtonX = "X",
	ButtonY = "Y",
	ButtonL1 = "LB",
	ButtonR1 = "RB",
	ButtonL2 = "LT",
	ButtonR2 = "RT",
	ButtonL3 = "L3",
	ButtonR3 = "R3",
	DPadUp = "D↑",
	DPadDown = "D↓",
	DPadLeft = "D←",
	DPadRight = "D→",
}

-- A key's legend as the HUD prints it on a KeyChip.
function ShiftHudViewModel.keyName(input: Enum.KeyCode | Enum.UserInputType): string
	return KEY_NAMES[input.Name] or input.Name
end

--[=[
	A prompt chip's key legend: the prompt's gamepad button for a controller player, its keyboard key otherwise.
]=]
function ShiftHudViewModel.promptKey(keyboard: Enum.KeyCode, gamepad: Enum.KeyCode, padActive: boolean): string
	return ShiftHudViewModel.keyName(if padActive then gamepad else keyboard)
end

-- Figma 1a's hint row, in order: the action id, how to say it, and whether it is held. `padAction` / `padHold` are
-- the gamepad's when they differ (crouch is a held Ctrl, but a B toggle on a controller).
local HINTS: { { action: string, label: string, hold: boolean, padAction: string?, padHold: boolean? } } = {
	{ action = VacuumConstants.ACTION, label = "vacuum", hold = true },
	{ action = "drop", label = "drop", hold = false },
	{ action = "throw", label = "throw", hold = false },
	{ action = "interact", label = "bank / search", hold = false },
	{ action = "sprint", label = "sprint", hold = true },
	{
		action = CrouchConstants.ACTION,
		label = "crouch",
		hold = true,
		padAction = CrouchConstants.TOGGLE_ACTION,
		padHold = false,
	},
}

--[=[
	The action whose gamepad bindings a hint reads (`crouch` reads `crouchToggle`); the hint's own action otherwise.
]=]
function ShiftHudViewModel.padAction(action: string): string
	for _, hint in HINTS do
		if hint.action == action then
			return hint.padAction or action
		end
	end
	return action
end

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
	The key hints, one per action with a binding: "Hold LMB vacuum", "G drop", ... `bindings` is keyed by the hint's
	action and holds the keyboard list, or, with `gamepad` set, the gamepad list (crouch's from its toggle, not held).
]=]
function ShiftHudViewModel.keyHints(bindings: KeyBindings, gamepad: boolean?): { HintView }
	local hints: { HintView } = {}
	for _, hint in HINTS do
		local first = firstKey(bindings, hint.action)
		if first ~= nil then
			local hold = if gamepad and hint.padHold ~= nil then hint.padHold else hint.hold
			table.insert(hints, {
				prefix = if hold then "Hold" else nil,
				key = ShiftHudViewModel.keyName(first),
				label = hint.label,
			})
		end
	end
	return hints
end

--[=[
	How far (px) the centred pieces (time card, ASSETS stamp, clock-out slip) move right so the widest of them, the
	500 px slip, clears the left column (the folder and fee plate) by a 16 px gap; 0 on a wide screen. Takes the width
	in HUD design px (usePaperHudScale's virtual viewport), since the desktop HUD is drawn scaled to the window.
]=]
function ShiftHudViewModel.centreShift(viewportWidth: number): number
	local HUD = UIPaperConstants.HUD
	local leftColumnRight = HUD.LEFT + HUD.FOLDER_WIDTH
	return math.max(0, (leftColumnRight + HUD.GAP) - (viewportWidth / 2 - HUD.SLIP_WIDTH / 2))
end

--[=[
	The carry panel's left edge (px): the corner inset on a tall viewport; on a short one (a windowed laptop), right of
	the crew roster column so a full roster (4 rows) is not covered. Takes the viewport in HUD design px
	(usePaperHudScale's virtual viewport), since the desktop HUD is drawn scaled to the window.
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

export type CompactView = {
	cargoValue: string?,
	equipped: boolean,
	-- How many item slots hold something.
	itemCount: number,
	actions: { HintView },
}

function ShiftHudViewModel.compact(view: HudView, bindings: KeyBindings, gamepad: boolean?): CompactView
	local occupied = 0
	for _, slot in view.hotbar.slots do
		if not slot.vacuum and not slot.empty then
			occupied += 1
		end
	end
	local actions: { HintView } = {}
	if view.hands ~= nil then
		local def = CargoRegistry.get(view.hands.kind)
		for _, hint in ShiftHudViewModel.keyHints(bindings, gamepad) do
			if hint.label == "drop" or (hint.label == "throw" and def ~= nil and def.throwable) then
				table.insert(actions, hint)
			end
		end
	end
	local hands = view.hands
	local def = if hands ~= nil then CargoRegistry.get(hands.kind) else nil
	return {
		equipped = view.vacuumEquipped,
		itemCount = occupied,
		actions = actions,
		cargoValue = if hands ~= nil
			then if def ~= nil and def.grimy
				then hands.value
				elseif def ~= nil and def.category ~= "trash" then ShiftCurrencyUtils.signed(hands.value)
				else `{hands.value} {if def == nil then "value" else "clearance"}`
			else nil,
	}
end

--[=[
	The HUD on a training run, on stop `stop` of `stops`: the meter counts the stops (STOP 2 / 5, filled by the stops
	done) instead of the shift's Gloom goal, which training never asks for.
]=]
function ShiftHudViewModel.training(view: HudView, stop: number, stops: number): HudView
	local copy = table.clone(view)
	copy.training = stop
	copy.cleared = tostring(stop)
	copy.quotaText = `/ {stops} STOPS`
	copy.clearedShort = `STOP {stop} / {stops}`
	copy.fill = if stops > 0 then math.clamp((stop - 1) / stops, 0, 1) else 0
	copy.quotaMet = false
	return copy
end

export type MeterView = { title: string, site: string, met: boolean }

-- The V1 Gloom meter's words: the job until the contract is met, then the win, then overtime's push. The site line is
-- the run's map's (DepotMapRules.siteOf; the office's when unknown). A training run is TRAINING.
function ShiftHudViewModel.meter(
	view: { quotaMet: boolean, overtime: boolean, training: number?, map: ShiftTypes.MapId? }
): MeterView
	if view.training ~= nil then
		return { title = "TRAINING", site = "Harlow & Finch · training", met = false }
	end
	local title = if view.overtime then "OVERTIME!" elseif view.quotaMet then "GOAL DONE!" else "CLEAN THE GLOOM"
	return { title = title, site = DepotMapRules.siteOf(DepotMapRules.parse(view.map)).hud, met = view.quotaMet }
end

-- The hint row is drawn on desktop with a keyboard only.
function ShiftHudViewModel.showHints(layout: UIPaperConstants.Layout, keyboard: boolean): boolean
	return layout == "desktop" and keyboard
end

return ShiftHudViewModel
