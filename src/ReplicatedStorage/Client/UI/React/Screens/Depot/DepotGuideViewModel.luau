--!strict
--[=[
	DepotGuideViewModel: the hub's GUIDE page (p075 scene menus, owner yes 2026-11-14): two tabs.
	- HOW TO PLAY: four photo steps in the order you play a shift (hop on a truck, vacuum the Gloom, hide, load the
	  truck), each a real posed in-game shot with one short line, its own colour and its number; the vacuum step also
	  carries the player's live vacuum control.
	- MONSTERS: one card per monster (the Manager at the Office, Bramble at the School) with his photo, his place and
	  a little lore, and a coming-soon card for the next one. Lore only: no danger meter and no rules for getting away
	  (the owner, 2026-11-13: monsters are learned by playing).
	Words at a young reader's level. `layout` sizes the sheet to the screen. Pure.

	@class DepotGuideViewModel
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)

export type Tab = "play" | "monsters"

export type TabView = { tab: Tab, label: string, selected: boolean }

export type Step = {
	number: number,
	title: string,
	line: string,
	hue: UIToonConstants.Hue,
	photo: string,
	-- The live control (the vacuum step only), e.g. "Hold the left mouse button near dust to clean."
	hint: string?,
}

export type Monster = {
	name: string,
	place: string,
	lore: { string },
	-- The card's colour: a kit hue, or a colour of its own (Bramble's moss green).
	hue: UIToonConstants.Hue,
	colour: Color3?,
	-- The name band's text gradient (the kit's display type takes a meaning, not a colour).
	nameMeaning: UIToonConstants.Meaning,
	-- The graded backdrop photo and the outlined cut-out that breaks the card's top (nil on the coming-soon card).
	photo: string,
	cut: string?,
	soon: boolean,
}

export type Layout = { width: number, height: number }

-- The sheet's design size (desktop / phone), px.
local SIZE = Vector2.new(1420, 800)
local PHONE_SIZE = Vector2.new(780, 360)

local DEFAULT_TAB: Tab = "play"

local VM = {
	SIZE = SIZE,
	PHONE_SIZE = PHONE_SIZE,
	DEFAULT_TAB = DEFAULT_TAB,
	-- The step photos' source size (px) and where a short frame keeps them (0 = the top rows, 1 = the bottom):
	-- near the top, so a short card on a small screen still shows the employee's head.
	STEP_PHOTO = Vector2.new(592, 720),
	STEP_FOCUS = 0.25,
}

--[=[
	The part of a `source`-sized photo (offset and size, px) a `frame`-shaped picture shows when it fills the frame:
	a wider frame keeps the full width and cuts rows around `focusY` (0..1 down the photo); a narrower one keeps the
	full height and cuts columns from the middle.
]=]
function VM.crop(source: Vector2, frame: Vector2, focusY: number): (Vector2, Vector2)
	if frame.X <= 0 or frame.Y <= 0 then
		return Vector2.zero, source
	end
	local frameAspect = frame.X / frame.Y
	local sourceAspect = source.X / source.Y
	if math.abs(frameAspect - sourceAspect) < 1e-6 then
		return Vector2.zero, source
	elseif frameAspect > sourceAspect then
		local rows = source.X / frameAspect
		return Vector2.new(0, (source.Y - rows) * math.clamp(focusY, 0, 1)), Vector2.new(source.X, rows)
	end
	local columns = source.Y * frameAspect
	return Vector2.new((source.X - columns) / 2, 0), Vector2.new(columns, source.Y)
end

function VM.tabs(selected: Tab): { TabView }
	return {
		{ tab = "play", label = "HOW TO PLAY", selected = selected == "play" },
		{ tab = "monsters", label = "MONSTERS", selected = selected == "monsters" },
	}
end

-- The four steps; `control` is the vacuum's live control sentence (DepotHubScreen reads the player's input).
function VM.steps(control: string?): { Step }
	local photos = UIAssets.toonPhotos
	return {
		{
			number = 1,
			title = "HOP ON",
			line = "Get on a truck with your friends.",
			hue = "sky",
			photo = photos.guideHopOn,
		},
		{
			number = 2,
			title = "VACUUM",
			line = "Suck up the purple Gloom.",
			hue = "grape",
			photo = photos.guideVacuum,
			hint = control,
		},
		{ number = 3, title = "SHH! HIDE!", line = "Something is out there.", hue = "coral", photo = photos.guideHide },
		{
			number = 4,
			title = "LOAD UP",
			line = "Put treasure on the truck. Get paid!",
			hue = "mint",
			photo = photos.guideLoadUp,
		},
	}
end

function VM.monsters(): { Monster }
	local photos = UIAssets.toonPhotos
	return {
		{
			name = "THE MANAGER",
			place = "THE OFFICE",
			lore = { "He never went home.", "He still checks every desk." },
			hue = "coral",
			nameMeaning = "gold",
			photo = photos.guideManagerBack,
			cut = photos.guideManagerCut,
			soon = false,
		},
		{
			name = "BRAMBLE",
			place = "THE SCHOOL",
			lore = { "Maple Hill's old owl mascot.", "He is very, very shy." },
			hue = "mint",
			colour = Color3.fromHex("5E9E2E"),
			nameMeaning = "white",
			photo = photos.guideBrambleBack,
			cut = photos.guideBrambleCut,
			soon = false,
		},
		{
			name = "???",
			place = "A NEW PLACE",
			lore = { "Someone new is moving in.", "Keep your flashlight close." },
			hue = "night",
			nameMeaning = "white",
			photo = photos.guideSoonBack,
			soon = true,
		},
	}
end

-- The sheet's size: its design size, kept inside the screen (16 px each side, 24 top and bottom).
function VM.layout(viewport: Vector2, phone: boolean): Layout
	local size = if phone then PHONE_SIZE else SIZE
	return {
		width = math.min(size.X, math.max(0, viewport.X - 32)),
		height = math.min(size.Y, math.max(0, viewport.Y - 48)),
	}
end

return VM
