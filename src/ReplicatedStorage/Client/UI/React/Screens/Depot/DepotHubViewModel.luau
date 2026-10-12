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
			subtitle = "CLEANUP CREW / NEW STARTER BRIEFING",
			sections = {
				{
					title = "01 / GET THE JOB",
					body = "Walk into a company truck bed. Bring up to three friends; anyone aboard can depart.",
				},
				{
					title = "02 / CLEAR & BANK",
					body = `Equip your vacuum. {cleanControl or "Hold the cleaning action near dust."} Full canisters produce dust bags. Load dust bags, rubbish and salvage at the truck.`,
				},
				{
					title = "03 / WATCH YOUR NOISE",
					body = "The occupant hears vacuums and dropped cargo. Put things down carefully. Empty hands let you run faster.",
				},
				{
					title = "04 / CLOCK OFF",
					body = "Meet the clearance quota, then clock out at the truck. Review your crew's awards and vote for another shift or the depot.",
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
				body = "Your vacuum is issued when a shift starts. Equip it through the Roblox hotbar; cleaning fills the canister.",
			},
			{
				title = "FULL CANISTER → DUST BAG",
				body = "A full canister automatically produces a dust bag and resets, so you can keep cleaning. Carry the bag to the truck and load it to bank clearance.",
			},
			{
				title = "HANDS & LOAD",
				body = "Bulky salvage needs both hands. Your vacuum stows while you carry it; put the load down to use your equipment again.",
			},
			{
				title = "TRAVEL LIGHT",
				body = "Heavy cargo slows you down. Bank valuable salvage, keep a clear escape route, and help crew members get back.",
			},
		},
	}
end
return VM
