--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local RankFormulas = require(ReplicatedStorage.Shared.Features.Rank.Utils.RankFormulas)
local TipRegistry = require(ReplicatedStorage.Shared.Features.Tip.Data.TipRegistry)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local ToonStyleViewModel = require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonStyleViewModel)
local VM = {}

-- The live event's chip beside the SHOP tile (owner Y2): your acorns and the days left; it opens the event tab.
export type EventChipView = { text: string }

-- The longest name the profile card prints before it is cut.
local NAME_MAX = 14
local SECONDS_PER_DAY = 86400

export type ProfileView = { name: string, level: string, rank: string, xpText: string, fill: number }
-- `tap`: what pressing the calendar does besides opening the Timecard: "punch" (today is free) punches in too.
export type GiftView = { ready: boolean, text: string, tap: "punch" | "open" }
-- The Tonight card: the place's name and site, its posed photo, and its monster's render breaking the card.
export type TonightView = { title: string, site: string, photo: string, monster: UIAssets.ToonIcon }

-- The hub's profile card (V1): the player's name in caps, their Clearance Level, its name, the XP bar to the next
-- level. `rank` is the published XP (RankViewModel.rankOf), nil until the server publishes it (the first rung).
function VM.profile(name: string, rank: { xp: number, prevXp: number }?): ProfileView
	local progress = RankFormulas.progress(if rank ~= nil then rank.xp else 0)
	local upper = string.upper(name)
	return {
		name = if #upper > NAME_MAX then string.sub(upper, 1, NAME_MAX - 1) .. "." else upper,
		level = tostring(progress.level.level),
		rank = progress.level.name,
		xpText = if progress.next ~= nil then `{progress.xp} / {progress.next.xp} XP` else `{progress.xp} XP`,
		fill = progress.fill,
	}
end

-- The calendar tile (top right) is the hub's one daily button (owner 2026-11-14: the empty daily gift merged into the
-- punch-in): PUNCH IN! while today's punch is free (the phone tile is 66 px: PUNCH), else the time to tomorrow's
-- punch (h:mm:ss, UTC days like the Timecard). A tap always opens the Timecard; while today is free it also punches in,
-- and the stamp lands on the open Timecard.
function VM.daily(canPunch: boolean, now: number, phone: boolean): GiftView
	if canPunch then
		return { ready = true, text = if phone then "PUNCH" else "PUNCH IN!", tap = "punch" }
	end
	local left = math.max(0, math.ceil(SECONDS_PER_DAY - now % SECONDS_PER_DAY))
	return {
		ready = false,
		text = string.format("%d:%02d:%02d", left // 3600, (left % 3600) // 60, left % 60),
		tap = "open",
	}
end

-- The hub page's header title.
function VM.pageTitle(page: Page): string
	return if page == "guide" then "GUIDE" else "SETTINGS"
end

-- Each screen has its own header colour so menus are not all one purple (owner pick 2026-11-13: Shop mint, Inventory
-- sky, Clipboard coral, Settings night, Guide gold). Purple stays for Gloom.
function VM.pageHue(page: Page): "gold" | "night"
	return if page == "guide" then "gold" else "night"
end

-- The Tonight card: the place the reader's truck picked (`map`, nil off a hosted truck: the Office), as tonight's
-- building. The Office's name comes from the board's contract (the first contract until the board is found).
function VM.tonight(id: string?, map: ShiftTypes.MapId?): TonightView
	if map == "school" then
		return {
			title = string.upper(DepotConstants.SCHOOL_CONTRACTS[1].client),
			site = DepotConstants.SCHOOL_SITE.site,
			photo = UIAssets.toonPhotos.schoolCard,
			monster = "brambleHunt",
		}
	end
	local contract = DepotConstants.CONTRACTS[1]
	for _, entry in DepotConstants.CONTRACTS do
		if entry.id == id then
			contract = entry
		end
	end
	local client = string.upper(contract.client)
	client = string.gsub(client, "%s+LTD%.?$", "")
	return {
		title = client,
		site = DepotConstants.SITE,
		photo = UIAssets.toonPhotos.officeCard,
		monster = "managerHunt",
	}
end
-- (The old Company Equipment page is gone: the Inventory's Vacuums tab is the vacuum's page now.)
export type Page = "guide" | "settings"
VM.PAGES = { "guide", "settings" }
VM.SETTINGS = {
	-- musicVolume drives the Music and Ambient groups, sfxVolume the SFX and UI groups (SettingConstants.VOLUME_SETTINGS).
	{ id = "musicVolume", label = "Music & ambience" },
	{ id = "sfxVolume", label = "Sound effects" },
	{ id = "cameraShake", label = "Camera shake" },
	{ id = "brightness", label = "Brightness" },
	-- A switch (TipRegistry registers it): the one-line tips for a player's firsts.
	{ id = TipRegistry.SETTING, label = "Tips" },
}
-- A switch setting's button text.
function VM.switchText(on: boolean): string
	return if on then "ON" else "OFF"
end
-- The settings rows' heights: a wide row (label beside its slider) and a compact one (label over it).
VM.SETTINGS_ROW = 68
VM.SETTINGS_ROW_COMPACT = 88
-- Where RESTORE DEFAULTS sits, a gap under the last settings row (its one-line note follows under the button).
function VM.settingsFooterY(compact: boolean): number
	return #VM.SETTINGS * (if compact then VM.SETTINGS_ROW_COMPACT else VM.SETTINGS_ROW) + 12
end
-- The settings rows' label column on a wide sheet (the slider fills the rest of the row).
VM.SLIDER_LABEL_WIDTH = 280
function VM.visible(snapshot: ShiftTypes.ShiftSnapshot?, userId: number): boolean
	return snapshot == nil or snapshot.phase == "lobby" or table.find(snapshot.crew, userId) == nil
end
--[=[
	The menu tiles, in order (owner 11-16, "final hub cut": one button per screen). Desktop drops JOBS, because the
	Tonight card opens the same Jobs board; a phone has no Tonight card, so it keeps JOBS first. There is no CLIPBOARD
	tile anywhere: the calendar tile opens the same clipboard (its Timecard tab, the Work Order one tap inside).
]=]
function VM.menuTiles(phone: boolean): { string }
	if phone then
		return { "jobs", "inventory", "guide", "settings" }
	end
	return { "inventory", "guide", "settings" }
end

-- Where the new player's NEW sticker goes: the Tonight card on desktop (it is the Jobs button there), the JOBS tile on
-- a phone.
function VM.newJobsOn(phone: boolean): "tonight" | "jobs"
	return if phone then "jobs" else "tonight"
end
-- The menu tiles' labels (JOBS, INVENTORY, GUIDE, SETTINGS). The phone tile's label box is 56 px, and INVENTORY needs
-- 62 px even at the 12 px text floor, so the phone says BAG (its render is a backpack).
local TILE_LABELS: { [string]: string } = {
	jobs = "JOBS",
	inventory = "INVENTORY",
	guide = "GUIDE",
	settings = "SETTINGS",
}
local PHONE_TILE_LABELS: { [string]: string } = { inventory = "BAG" }
function VM.tileLabel(key: string, phone: boolean): string
	local short = if phone then PHONE_TILE_LABELS[key] else nil
	return short or TILE_LABELS[key] or string.upper(key)
end
function VM.cardSize(phone: boolean): Vector2
	return if phone then Vector2.new(62, 72) else Vector2.new(86, 106)
end
export type PanelLayout = {
	width: number,
	height: number,
	compact: boolean,
	padding: number,
	titleWidth: number,
	bodyWidth: number,
	headerHeight: number,
}
function VM.panelLayout(viewport: Vector2, phone: boolean): PanelLayout
	local width = math.min(if phone then 690 else 860, math.max(0, viewport.X - 32))
	local compact = width < 560
	local padding = if compact then 20 else 32
	return {
		width = width,
		height = math.min(660, math.max(0, viewport.Y - 48)),
		compact = compact,
		padding = padding,
		titleWidth = width - (if compact then 148 else 280),
		bodyWidth = width - 2 * padding - 12,
		headerHeight = if compact then 140 else 110,
	}
end
function VM.scene(page: Page): string
	return `depot.{page}`
end
-- The hub's small "Find a truck!" tab (owner 11-11: the full Next shift card got in the way): shown only while the
-- player is not aboard a truck (aboard, the queue pad's full card shows) and hidden while an interaction prompt is
-- up, so it never covers one.
VM.FIND_TRUCK_TEXT = "Find a truck!"

function VM.eventChip(acorns: number, days: number, phone: boolean): EventChipView
	local left = if days <= 1 then "Last day!" elseif phone then `{days}d` else `{days} days left`
	return { text = `{ToonStyleViewModel.grouped(acorns)} · {left}` }
end

function VM.findTruck(aboard: boolean, promptUp: boolean): boolean
	return not aboard and not promptUp
end

return VM
