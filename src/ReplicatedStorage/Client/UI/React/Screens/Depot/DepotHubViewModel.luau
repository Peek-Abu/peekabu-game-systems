--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DailyRewardConstants = require(ReplicatedStorage.Shared.Features.DailyReward.Data.DailyRewardConstants)
local DailyRewardRules = require(ReplicatedStorage.Shared.Features.DailyReward.Rules.DailyRewardRules)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local RankFormulas = require(ReplicatedStorage.Shared.Features.Rank.Utils.RankFormulas)
local TipRegistry = require(ReplicatedStorage.Shared.Features.Tip.Data.TipRegistry)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local VM = {}

-- The longest name the profile card prints before it is cut.
local NAME_MAX = 14
local SECONDS_PER_DAY = 86400

export type ProfileView = { name: string, level: string, rank: string, xpText: string, fill: number }
export type GiftView = { ready: boolean, text: string }
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

-- The daily gift tile: OPEN! while today's reward is claimable, else the time to the next day (h:mm:ss).
function VM.gift(state: PlayerDataTypes.DailyReward, now: number): GiftView
	local offset = DailyRewardConstants.DAY_OFFSET_HOURS
	local today = DailyRewardRules.dayOf(now, offset)
	local status = DailyRewardRules.status(state, today, DailyRewardConstants.CYCLE_LENGTH)
	if status.claimable then
		return { ready = true, text = "OPEN!" }
	end
	local left = math.max(0, math.ceil(SECONDS_PER_DAY - (now + offset * 3600) % SECONDS_PER_DAY))
	return {
		ready = false,
		text = string.format("%d:%02d:%02d", left // 3600, (left % 3600) // 60, left % 60),
	}
end

-- The render beside each guide / locker section, in VM.copy's order. The noise section wears the Quiet stat's render:
-- the guide is about every map's monster, so it shows none of their faces.
function VM.sectionIcons(_page: Page): { UIAssets.ToonIcon }
	return { "truck", "vacuum", "statQuiet", "clock" }
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
	Whether the hub shows the CLIPBOARD tile (under SHOP; owner 11-08, layout A): not before training is done. The
	clipboard never opens by itself and its Today tracker lives inside the card.
]=]
function VM.clipboardShown(isNew: boolean): boolean
	return not isNew
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
function VM.copy(
	page: Page,
	cleanControl: string?
): { title: string, subtitle: string, sections: { { title: string, body: string } } }
	if page == "guide" then
		return {
			title = "FIELD GUIDE",
			subtitle = "MORROW & MORROW CLEARANCE / NEW ASSOCIATE BRIEFING",
			sections = {
				{
					title = "01 / GET THE JOB",
					body = "Walk into a company truck bed. Bring up to three friends; anyone aboard can depart.",
				},
				{
					title = "02 / VACUUM & LOAD",
					body = `Equip your vacuum. {cleanControl or "Hold the vacuum button near dust."} Every pile you vacuum takes Gloom away right then, and so does cleaning the grime off a treasure. Load the treasure onto the truck (the Crew Truck) for Credits.`,
				},
				{
					title = "03 / WATCH YOUR NOISE",
					body = "Monsters hear vacuums and dropped cargo. Put things down carefully. Bulky things need both hands, and your vacuum goes on your back while you carry. Empty hands let you run faster.",
				},
				{
					title = "04 / CLOCK OFF",
					body = "Remove the contract's Gloom, then choose: clock out at the truck, or sign the overtime sheet beside it for new shimmering loot worth ×1.5 and faster monsters. Every Gloom removed pays 1 Credit at the end of the shift. Review your crew's awards and vote for another shift or the depot.",
				},
			},
		}
	end
	-- Settings draws its own rows; it has no copy of its own.
	return { title = "SETTINGS", subtitle = "", sections = {} }
end
-- The hub's small "Find a truck!" tab (owner 11-11: the full Next shift card got in the way): shown only while the
-- player is not aboard a truck (aboard, the queue pad's full card shows) and hidden while an interaction prompt is
-- up, so it never covers one.
VM.FIND_TRUCK_TEXT = "Find a truck!"

function VM.findTruck(aboard: boolean, promptUp: boolean): boolean
	return not aboard and not promptUp
end

return VM
