--!strict
--[=[
	UIAssets: the registry of image (and UI sound) asset ids the UI references, by name.

	The single home for `rbxassetid://` literals in UI code — the CI asset-id gate bans them anywhere
	else (asset-id literals may only live under a feature's `Data/` folder). A screen names an asset
	(`UIAssets.bar.fill`), never pastes a number, so a re-skin or a re-upload is one edit here.

	Empty in the base: each game adds its own groups, frozen, e.g.

		UIAssets.bar = table.freeze({
			fill = "rbxassetid://<id>", -- the coloured fill (tinted per resource)
			frame = "rbxassetid://<id>", -- the border drawn over the fill
		})

	@class UIAssets
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local SoundTypes = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundTypes)

local UIAssets = {}

-- The V1 kit's icon names (the keys of UIAssets.toonIcons).
export type ToonIcon =
	"clock"
	| "dust"
	| "fishtank"
	| "flashlight"
	| "gift"
	| "gleam"
	| "gleamPile"
	| "globe"
	| "gloom"
	| "grab"
	| "guide"
	| "jobs"
	| "key"
	| "lock"
	| "locker"
	| "managerCalm"
	| "managerHunt"
	| "monitor"
	| "mop"
	| "pippaHappy"
	| "pippaWorried"
	| "settings"
	| "spray"
	| "stamina"
	| "stapler"
	| "stopwatch"
	| "trophy"
	| "truck"
	| "vacuum"
	| "vacuumBrass"
	| "xp"

-- A tileable texture: its asset id (PENDING "" until the developer uploads it) and its size in px, the TileSize it
-- repeats at. PaperTexture draws nothing while an id is "", so every paper stays a flat colour until then.
export type Texture = { id: string, tile: Vector2 }

-- Cleanup Crew paper textures (M3b world UI; files in assets/ui/textures/), uploaded to the Icey Labs group. Each id is
-- the Image under the uploaded Decal, as "rbxassetid://<number>" (PaperTextureViewModel.spec checks the form).
local PAPER: { [string]: Texture } = {
	cream = table.freeze({ id = "rbxassetid://74559876585601", tile = Vector2.new(160, 160) }), -- paper-cream.png
	manila = table.freeze({ id = "rbxassetid://139836337623266", tile = Vector2.new(160, 160) }), -- paper-manila.png
	manilaDeep = table.freeze({ id = "rbxassetid://105396699555543", tile = Vector2.new(128, 128) }), -- paper-manila-deep.png
	sticky = table.freeze({ id = "rbxassetid://75509377158113", tile = Vector2.new(128, 128) }), -- paper-sticky.png
	cork = table.freeze({ id = "rbxassetid://137899371757107", tile = Vector2.new(192, 192) }), -- cork.png
	wood = table.freeze({ id = "rbxassetid://129212444634345", tile = Vector2.new(256, 128) }), -- wood.png
}
UIAssets.paper = table.freeze(PAPER)

-- Cleanup Crew V1 "Gloom & Gleam" kit (2026-10-17), uploaded to the Icey Labs group. Each id is the Image under the
-- uploaded Decal (characters/ui/shipped-ui-assets.md lists both). Icons are 256 px renders with the 5 px ink outline
-- baked in (their hard drop is a second, ink-tinted copy, never baked).
local TOON_ICONS: { [ToonIcon]: string } = {
	clock = "rbxassetid://97995675031546",
	dust = "rbxassetid://87348303383802",
	fishtank = "rbxassetid://72370733106499",
	flashlight = "rbxassetid://115788026706324",
	gift = "rbxassetid://84976135728496",
	gleam = "rbxassetid://92098466484576",
	gleamPile = "rbxassetid://87196921749527",
	globe = "rbxassetid://105862507048588",
	gloom = "rbxassetid://139797009877972",
	grab = "rbxassetid://128476532358528",
	guide = "rbxassetid://108576171337491",
	jobs = "rbxassetid://72307376362077",
	key = "rbxassetid://99994665542005",
	lock = "rbxassetid://83785061837290",
	locker = "rbxassetid://132365115657905",
	managerCalm = "rbxassetid://79215225592922",
	managerHunt = "rbxassetid://126690679697372",
	monitor = "rbxassetid://115152845494708",
	mop = "rbxassetid://135344307549758",
	pippaHappy = "rbxassetid://83422913842035",
	pippaWorried = "rbxassetid://77310837138468",
	settings = "rbxassetid://112995353478331",
	spray = "rbxassetid://122601719267115",
	stamina = "rbxassetid://82683111969978",
	stapler = "rbxassetid://91446482823859",
	stopwatch = "rbxassetid://79924913809502",
	trophy = "rbxassetid://123624581133724",
	truck = "rbxassetid://114161028640916",
	vacuum = "rbxassetid://95204983643911",
	vacuumBrass = "rbxassetid://70576303094914",
	xp = "rbxassetid://77433204551858",
}
UIAssets.toonIcons = table.freeze(TOON_ICONS)

-- Graded photos and cut-out renders (the map cards are 960x600, the portraits square, the cut-outs outlined PNGs).
UIAssets.toonPhotos = table.freeze({
	officeCard = "rbxassetid://130708209071391",
	hospitalCard = "rbxassetid://76365174293518",
	motelCard = "rbxassetid://104743022093430",
	mallCard = "rbxassetid://108801045193529",
	managerPortrait = "rbxassetid://136047524517573",
	officeWide = "rbxassetid://105469082592765",
	pippaPortrait = "rbxassetid://100337810904422",
	truckCut = "rbxassetid://72922265291902",
	pippaSaluteCut = "rbxassetid://77407692720114",
})

-- The kit's drawn pieces (implemented/tools/make_toon_assets.py, all at 2x). The goo: `capTile` (256x112) and
-- `poolTile` (256x80) are one whole tile each; `gooEnds` is the atlas of their ends (cap ends at y 0, 256x112 each;
-- pool ends at y 128, 256x80 each). `glow` is a 128 px white 9-slice (centre 48..80) tinted per use; `patternSparkle`
-- (144) and `patternBubbles` (120) are white tiles tinted per panel.
UIAssets.toon = table.freeze({
	capTile = "rbxassetid://114961170504517",
	poolTile = "rbxassetid://106249912761815",
	gooEnds = "rbxassetid://70785823038696",
	glow = "rbxassetid://78717613960831",
	rays = "rbxassetid://103836764476829",
	patternSparkle = "rbxassetid://97732926490283",
	patternBubbles = "rbxassetid://90150192373857",
	sparkle = "rbxassetid://79532536364589",
})

-- The CCTV overlay's scanlines (M3 UI). PENDING and not drawn yet.
UIAssets.cctv = table.freeze({
	scanlines = "",
})

-- Cleanup Crew UI sounds (round-2/3 picks, in-house, the paperwork hierarchy: pitch up = yes, down = back, dull =
-- denied), all 2D in the UI group. Minor: hover (a paper tick) and click (tab flick + card), family P. Important: confirm
-- (felt thunk + clip + one vibes note in F, family S), back (lower, shorter) and error (a dull thud + falling minor 2nd),
-- family P. Critical: the CTA (confirm + a time-clock punch + rising F-A-C + a small ding, family S) for Start shift and
-- Clock out. Prompts: the hold wind-up (a pizz F major scale, stretched to the hold) and the done (confirm S's felt and
-- clip + a pizz F chord). Played by UISoundSystem by tier (UISoundFormulas.Tier -> TIERS).
local SOUNDS: { [string]: SoundTypes.SoundDef } = {
	uiHover = { assetId = "rbxassetid://125412787340819", group = "UI", volume = 0.7, maxConcurrent = 2 },
	uiClick = { assetId = "rbxassetid://122165734026820", group = "UI", volume = 0.9, maxConcurrent = 2 },
	uiConfirm = { assetId = "rbxassetid://83738970696959", group = "UI", volume = 0.9, maxConcurrent = 2 },
	uiBack = { assetId = "rbxassetid://130280445606800", group = "UI", volume = 0.9, maxConcurrent = 2 },
	uiError = { assetId = "rbxassetid://139831732223870", group = "UI", volume = 0.9, maxConcurrent = 2 },
	uiCta = { assetId = "rbxassetid://78569365251759", group = "UI", volume = 1, maxConcurrent = 1 },
	uiPromptHold = { assetId = "rbxassetid://105267179969138", group = "UI", volume = 1, maxConcurrent = 1 },
	uiPromptDone = { assetId = "rbxassetid://134811176097827", group = "UI", volume = 1, maxConcurrent = 2 },
}
for id, def in SOUNDS do
	if not SoundRegistry.has(id) then
		SoundRegistry.register(id, def)
	end
end
UIAssets.sounds = table.freeze(SOUNDS)

-- The sound each UI tier plays.
local TIERS: { [string]: string } = {
	hover = "uiHover",
	click = "uiClick",
	confirm = "uiConfirm",
	back = "uiBack",
	error = "uiError",
	cta = "uiCta",
	hold = "uiPromptHold",
	done = "uiPromptDone",
}
UIAssets.soundTiers = table.freeze(TIERS)

return UIAssets
