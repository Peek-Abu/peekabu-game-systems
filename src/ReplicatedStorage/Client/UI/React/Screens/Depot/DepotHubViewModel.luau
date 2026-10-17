--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DailyRewardConstants = require(ReplicatedStorage.Shared.Features.DailyReward.Data.DailyRewardConstants)
local DailyRewardRules = require(ReplicatedStorage.Shared.Features.DailyReward.Rules.DailyRewardRules)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local RankFormulas = require(ReplicatedStorage.Shared.Features.Rank.Utils.RankFormulas)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)
local VM = {}

-- The longest name the profile card prints before it is cut.
local NAME_MAX = 14
local SECONDS_PER_DAY = 86400

export type ProfileView = { name: string, level: string, rank: string, xpText: string, fill: number }
export type GiftView = { ready: boolean, text: string }
export type TonightView = { title: string, site: string }

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

-- The render beside each guide / locker section, in VM.copy's order.
function VM.sectionIcons(page: Page): { UIAssets.ToonIcon }
	if page == "guide" then
		return { "truck", "vacuum", "managerHunt", "clock" }
	end
	return { "vacuum", "gloom", "grab", "stamina" }
end

-- The hub page's header title (the gear page is the Locker in the V1 menus).
function VM.pageTitle(page: Page): string
	if page == "guide" then
		return "GUIDE"
	elseif page == "gear" then
		return "LOCKER"
	end
	return "SETTINGS"
end

-- The Tonight card: tonight's building (the board's contract; the first contract until the board is found).
function VM.tonight(id: string?): TonightView
	local contract = DepotConstants.CONTRACTS[1]
	for _, entry in DepotConstants.CONTRACTS do
		if entry.id == id then
			contract = entry
		end
	end
	local client = string.upper(contract.client)
	client = string.gsub(client, "%s+LTD%.?$", "")
	return { title = client, site = DepotConstants.SITE }
end
export type Page = "guide" | "gear" | "settings"
VM.PAGES = { "guide", "gear", "settings" }
VM.SETTINGS = {
	{ id = "musicVolume", label = "Music" },
	{ id = "sfxVolume", label = "Equipment & effects" },
	{ id = "uiVolume", label = "UI feedback" },
	{ id = "ambientVolume", label = "Building ambience" },
	{ id = "cameraShake", label = "Camera shake" },
}
function VM.visible(snapshot: ShiftTypes.ShiftSnapshot?, userId: number): boolean
	return snapshot == nil or snapshot.phase == "lobby" or table.find(snapshot.crew, userId) == nil
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
function VM.adjust(current: number, direction: number): number
	return math.clamp(math.round((current + direction * 0.1) * 100) / 100, 0, 1)
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
					title = "02 / VACUUM & BANK",
					body = `Equip your vacuum. {cleanControl or "Hold the cleaning action near dust."} Every pile you vacuum removes Gloom toward the contract on the spot, and so does cleaning the grime off a valuable. Bank the valuables at the truck (the Mobile Recovery Unit) for Gleam.`,
				},
				{
					title = "03 / WATCH YOUR NOISE",
					body = "The Manager hears vacuums and dropped cargo. Put things down carefully. Empty hands let you run faster.",
				},
				{
					title = "04 / CLOCK OFF",
					body = "Remove the contract's Gloom, then choose: clock out at the truck, or sign the overtime sheet beside it for ×1.5 on valuables and a faster Manager. Every Gloom removed pays 1 Gleam at clock-out. Review your crew's awards and vote for another shift or the depot.",
				},
			},
		}
	end
	return {
		title = "COMPANY EQUIPMENT",
		subtitle = "ISSUED FOR EVERY SHIFT / NO PURCHASE REQUIRED",
		sections = {
			{
				title = "STANDARD VACUUM",
				body = "Your vacuum is issued when a shift starts. Equip it from slot 1 of your hotbar; its canister gauge shows the crew's Gloom against the contract.",
			},
			{
				title = "NO DUST BAGS",
				body = "The canister never fills up and there is nothing to carry back: the Gloom counts the moment it is vacuumed. Clean a valuable before you lift it; once lifted, its grime locks.",
			},
			{
				title = "HANDS & LOAD",
				body = "Bulky assets need both hands. Your vacuum stows while you carry it; put the load down to use your equipment again.",
			},
			{
				title = "TRAVEL LIGHT",
				body = "Heavy cargo slows you down. Bank Recoverable Assets early, keep a clear escape route, and help crew members get back.",
			},
		},
	}
end
return VM
