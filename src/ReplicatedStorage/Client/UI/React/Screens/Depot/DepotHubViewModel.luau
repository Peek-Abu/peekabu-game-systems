--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local VM = {}
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
