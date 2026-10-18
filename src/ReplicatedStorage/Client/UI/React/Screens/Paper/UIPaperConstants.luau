--!strict
--[=[
	UIPaperConstants: Cleanup Crew's "Corporate After Hours" paperwork look (Figma "Style" page 4:2 and "Components"
	5:2, approved 2026-10-11): the 14-colour palette plus the three paper inks, the four fonts as Font faces, text
	sizes per layout (desktop >= 20 px for anything read in play, phone >= 14 px), the phone safe area and the motion
	timings. The game's UI kit reads only this; the base Tokens stay neutral (plan "Decisions").

	Static data only: `inkColor` is a frozen lookup, not a branch, so there is nothing here a spec could assert.

	@class UIPaperConstants
]=]

export type Layout = "desktop" | "phone"
export type Ink = "ok" | "busy" | "danger" | "muted" | "ink"

local COLOR = table.freeze({
	night = Color3.fromHex("0E1116"),
	office = Color3.fromHex("1A1F26"),
	manila = Color3.fromHex("E8C98A"),
	manilaDeep = Color3.fromHex("C9A564"),
	cream = Color3.fromHex("F4ECD6"), -- Punch Cream
	ink = Color3.fromHex("24211C"),
	sticky = Color3.fromHex("FFE45C"),
	stamp = Color3.fromHex("C8202F"),
	fluorescent = Color3.fromHex("E6F5E8"),
	fluorGlow = Color3.fromHex("B8F0C4"),
	exitRed = Color3.fromHex("FF4A3D"),
	exitGreen = Color3.fromHex("2FD27A"),
	monitor = Color3.fromHex("4C9BFF"),
	monitorDeep = Color3.fromHex("12305C"),
	-- Ink on paper.
	inkBlue = Color3.fromHex("1F4E9A"),
	companyTeal = Color3.fromHex("356D61"), -- Shared equipment/award illustration ink.
	inkGreen = Color3.fromHex("1E7A46"),
	inkRed = Color3.fromHex("C8202F"),
	-- Not on the Style page: the depot pinboard's cork and the empty pocket label (Components 5:2).
	cork = Color3.fromHex("6B4A2B"),
	-- The cork board's wood frame (Figma World UI 2a; picked from the export).
	wood = Color3.fromHex("4A2E1A"),
	slotEmpty = Color3.fromHex("8A8F98"),
})

local function face(font: Enum.Font, weight: Enum.FontWeight): Font
	return Font.new(Font.fromEnum(font).Family, weight)
end

local FONT = table.freeze({
	-- Special Elite: typewriter body copy.
	body = face(Enum.Font.SpecialElite, Enum.FontWeight.Regular),
	-- Oswald: numbers, headings, buttons, stamps.
	heading = face(Enum.Font.Oswald, Enum.FontWeight.Bold),
	medium = face(Enum.Font.Oswald, Enum.FontWeight.Medium),
	number = face(Enum.Font.Oswald, Enum.FontWeight.Bold),
	-- Roboto Mono: timers only (digits do not jitter).
	timer = face(Enum.Font.RobotoMono, Enum.FontWeight.Bold),
	-- Permanent Marker: sticky notes and marker marks only.
	marker = face(Enum.Font.PermanentMarker, Enum.FontWeight.Regular),
})

-- Text sizes in px, by role and layout (Figma dumps).
local TEXT = table.freeze({
	desktop = table.freeze({
		hint = 20,
		label = 20,
		body = 22,
		value = 32,
		big = 44,
		timer = 58,
		sticky = 24,
		stamp = 72,
		bigStamp = 120,
	}),
	phone = table.freeze({
		hint = 14,
		label = 14,
		body = 15,
		value = 18,
		big = 24,
		timer = 32,
		sticky = 16,
		stamp = 22,
		bigStamp = 40,
	}),
})

-- Safe areas (Components 5:2 rules): the Roblox top bar (~58 px, GuiService.TopbarInset), the phone notch margins,
-- the thumbstick zone (bottom-left 40%) and the Jump button (bottom-right).
local SAFE = table.freeze({
	desktop = table.freeze({ left = 60, right = 60, top = 68, bottom = 40, topBar = 58 }),
	phone = table.freeze({ left = 48, right = 48, top = 12, bottom = 20, topBar = 58 }),
})

local MOTION = table.freeze({
	-- A stamp drops from 140% with a thunk (1f), a sticky slides in from the right edge.
	popSeconds = 0.18,
	popFrom = 1.4,
	slideSeconds = 0.25,
	slideFrom = 380,
	-- Desktop key hints sit at 80% opacity (1a).
	hintTransparency = 0.2,
})

-- The ink a status is written in, as a lookup (no branch): ok green, busy blue, danger red, muted grey, plain ink.
local INK_COLOR: { [Ink]: Color3 } = table.freeze({
	ok = COLOR.inkGreen,
	busy = COLOR.inkBlue,
	danger = COLOR.inkRed,
	muted = COLOR.slotEmpty,
	ink = COLOR.ink,
})

local function inkColor(ink: Ink): Color3
	return INK_COLOR[ink]
end

-- The desktop Shift HUD's left column and carry panel geometry (Figma 1a), shared by the panels and the layout rules
-- (ShiftHudViewModel.centreShift / carryLeft) so one number drives both.
local HUD = table.freeze({
	-- The clearance folder and finder's fee plate: x 48, 470 wide.
	LEFT = 48,
	FOLDER_WIDTH = 470,
	-- The crew roster: x 52, 350 wide, y 330, a 46 px header and 36 px per row.
	ROSTER_LEFT = 52,
	ROSTER_WIDTH = 350,
	ROSTER_TOP = 330,
	ROSTER_HEADER = 46,
	ROSTER_ROW = 36,
	-- The carry panel: 640x196, inset 48 px from the bottom-left corner.
	CARRY_WIDTH = 640,
	CARRY_HEIGHT = 196,
	CARRY_INSET = 48,
	-- The empty strip kept between neighbouring columns.
	GAP = 16,
	-- The crew roster's most rows (the shift's crew cap).
	ROSTER_MAX_ROWS = 4,
	-- The widest centred piece, the clock-out slip.
	SLIP_WIDTH = 500,
})

local UIPaperConstants = {
	HUD = HUD,
	COLOR = COLOR,
	FONT = FONT,
	TEXT = TEXT,
	SAFE = SAFE,
	MOTION = MOTION,
	-- The screen every desktop px is designed for (the Figma desktop frames are 1920x1080).
	REFERENCE = Vector2.new(1920, 1080),
	-- The desktop UI scales with the window (PaperHudScaleViewModel): never below HUD_SCALE_MIN (a small laptop or a
	-- tablet still draws TEXT_MIN.desktop at READABLE_PX) and never above HUD_SCALE_MAX (a 4K monitor draws the
	-- 1920x1080 design at 2x).
	HUD_SCALE_MIN = 0.75,
	HUD_SCALE_MAX = 2,
	-- The tallest desktop column (the hub's profile card and four menu tiles) in design px: a window too short to
	-- hold it at HUD_SCALE_MIN is drawn smaller, down to HUD_SCALE_FLOOR, rather than cutting the column off.
	HUD_FIT_HEIGHT = 900,
	HUD_SCALE_FLOOR = 0.4,
	-- The smallest real px any text is drawn at: the floor of fitted (TextScaled) text (PaperScaleContext.floor).
	READABLE_PX = 12,
	-- The smallest design text size per layout: desktop text is drawn at >= 0.75 of it, phone text at 1.
	TEXT_MIN = table.freeze({ desktop = 16, phone = 12 }),
	-- Every tilt the kit uses, in degrees.
	STAMP_TILT = -3,
	STICKY_TILT = 2,
	-- Touch targets (Components 5:2): small >= 48 (72 drawn), large 104.
	BUTTON_SMALL = 72,
	BUTTON_LARGE = 104,
	inkColor = inkColor,
}

return table.freeze(UIPaperConstants)
