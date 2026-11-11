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
	"abilityLetsGo"
	| "abilityPottedPlant"
	| "abilitySpotIt"
	| "bell"
	| "brambleCalm"
	| "brambleHunt"
	| "clock"
	| "coffee"
	| "dust"
	| "fishtank"
	| "flashlight"
	| "friendsLock"
	| "friendsLockOpen"
	| "gift"
	| "credits"
	| "gleam"
	| "gleamBucket"
	| "gleamCrate"
	| "gleamPile"
	| "gleamTruck"
	| "globe"
	| "gloom"
	| "grab"
	| "guide"
	| "heart"
	| "heartGloomed"
	| "hostCrown"
	| "invite"
	| "jobs"
	| "key"
	| "lock"
	| "lockNight"
	| "locker"
	| "managerCalm"
	| "managerHunt"
	| "monitor"
	| "mop"
	| "pippaHappy"
	| "pippaWorried"
	| "radio"
	| "settings"
	| "shopGift"
	| "spray"
	| "stamina"
	| "statQuiet"
	| "statSpeed"
	| "statStamina"
	| "statStrength"
	| "statSuction"
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
	-- Ability renders (character step 4, 2026-10-24; decals in characters/ui/shipped-ui-assets.md). Let's Go! is
	-- Pippa's own foot (owner pick).
	abilityLetsGo = "rbxassetid://110925040898866",
	abilityPottedPlant = "rbxassetid://120058837938191",
	abilitySpotIt = "rbxassetid://72513443568229",
	-- Gleam bundle renders, smallest to biggest, made from the Gleam gem itself (v2, 2026-10-24), and the Shop's gift.
	gleamPile = "rbxassetid://112951566480973",
	gleamBucket = "rbxassetid://120954864254019",
	gleamCrate = "rbxassetid://71294352475481",
	gleamTruck = "rbxassetid://86130539333417",
	shopGift = "rbxassetid://116419935164686",
	-- The hub's station renders (2026-11-12): the shift bell and the radio from their models, the coffee mug from the
	-- break room's (decals 127753490073652, 135622491578671, 132800978467871).
	bell = "rbxassetid://85494966459975",
	clock = "rbxassetid://97995675031546",
	coffee = "rbxassetid://115766343705043",
	radio = "rbxassetid://81820573675358",
	dust = "rbxassetid://87348303383802",
	fishtank = "rbxassetid://72370733106499",
	flashlight = "rbxassetid://115788026706324",
	gift = "rbxassetid://84976135728496",
	credits = "rbxassetid://120886772987647", -- the Credits ticket (2026-10-21, decal 72265330733611)
	gleam = "rbxassetid://138856527532184", -- the premium Gleam crystal (2026-10-21, decal 98003345456608)
	globe = "rbxassetid://105862507048588",
	gloom = "rbxassetid://81350628293272", -- the Gloom goo splat, satin (2026-10-21, decal 80798571772047)
	grab = "rbxassetid://128476532358528",
	guide = "rbxassetid://108576171337491",
	heart = "rbxassetid://75866312534437",
	heartGloomed = "rbxassetid://85905766239276",
	jobs = "rbxassetid://72307376362077",
	key = "rbxassetid://99994665542005",
	lock = "rbxassetid://83785061837290",
	-- Padlock C, the night lock (owner pick for now, 2026-10-24; decal 135775868127022): a not-owned-yet card.
	lockNight = "rbxassetid://102433972832334",
	locker = "rbxassetid://132365115657905",
	-- Bramble's portraits (the School's owl; its calm face and its chasing one), PENDING "" until rendered and
	-- uploaded: OccupantPortraitAssets shows a neutral stand-in while a slot is "", never Harlow's.
	brambleCalm = "",
	brambleHunt = "",
	managerCalm = "rbxassetid://79215225592922",
	managerHunt = "rbxassetid://126690679697372",
	monitor = "rbxassetid://115152845494708",
	mop = "rbxassetid://135344307549758",
	pippaHappy = "rbxassetid://83422913842035",
	pippaWorried = "rbxassetid://77310837138468",
	settings = "rbxassetid://112995353478331",
	spray = "rbxassetid://122601719267115",
	stamina = "rbxassetid://82683111969978",
	-- The 5 employee stat icons (GPT renders, ink outline; 2026-10-24; decals in characters/ui/character-ui/upload/assets.json).
	statQuiet = "rbxassetid://129311765575014",
	statSpeed = "rbxassetid://140399231291202",
	statStamina = "rbxassetid://83409994495361",
	statStrength = "rbxassetid://135861991084173",
	statSuction = "rbxassetid://81351809446614",
	stapler = "rbxassetid://91446482823859",
	stopwatch = "rbxassetid://79924913809502",
	-- Crew hosting (GPT renders, ink outline; 2026-10-29; decals in characters/ui/crew-hosting-icons/assets.json): the
	-- host's crown, the friends-only heart lock and its open twin (one canvas, so they swap without a jump), Invite.
	hostCrown = "rbxassetid://96399141220976",
	friendsLock = "rbxassetid://92886567928655",
	friendsLockOpen = "rbxassetid://111986114299986",
	invite = "rbxassetid://85689612944793",
	trophy = "rbxassetid://123624581133724",
	truck = "rbxassetid://114161028640916",
	vacuum = "rbxassetid://95204983643911",
	vacuumBrass = "rbxassetid://70576303094914",
	xp = "rbxassetid://77433204551858",
}
UIAssets.toonIcons = table.freeze(TOON_ICONS)

-- The image of a kit icon named by a plain string (data written outside the UI, like an ability's render), or nil.
function UIAssets.iconImage(name: string): string?
	for key, image in TOON_ICONS do
		if key == name then
			return image
		end
	end
	return nil
end

-- Graded photos and cut-out renders (the map cards are 960x600, the portraits square, the cut-outs outlined PNGs).
UIAssets.toonPhotos = table.freeze({
	officeCard = "rbxassetid://130708209071391",
	hospitalCard = "rbxassetid://76365174293518",
	motelCard = "rbxassetid://104743022093430",
	mallCard = "rbxassetid://108801045193529",
	managerPortrait = "rbxassetid://136047524517573",
	officeWide = "rbxassetid://105469082592765",
	-- The School's trip-card picture (the Office's is officeWide): Bramble at the end of a locker hall (Icey Labs, owner
	-- OK 2026-11-11; decal 90341198768642). An empty slot would draw the School map card's look instead
	-- (ShiftTransitViewModel.slip).
	schoolWide = "rbxassetid://75797686913598",
	pippaPortrait = "rbxassetid://100337810904422",
	truckCut = "rbxassetid://72922265291902",
	pippaSaluteCut = "rbxassetid://77407692720114",
})

-- Chat-wheel sticker art by CosmeticRegistry sticker id (2026-11-03, owner picks; style C, waist up): 512 px
-- die-cut PNGs, Icey Labs. Each id is the Image under the uploaded Decal (decals in
-- characters/ui/stickers/legendary-2026-11-03/v2/final/upload.log). A sticker missing here uses its stand-in.
local STICKERS: { [string]: string } = {
	["BubblePack.Yay"] = "rbxassetid://120902819081466",
	["BubblePack.ThankYou"] = "rbxassetid://109721451516779",
	["BubblePack.UhOh"] = "rbxassetid://128102627826955",
	["BubblePack.GoodJob"] = "rbxassetid://132887262885944",
	["CozyPack.Whatever"] = "rbxassetid://84327838123278",
	["CozyPack.Sleepy"] = "rbxassetid://81036280511510",
	["CozyPack.CocoaBreak"] = "rbxassetid://133758136444250",
	["CozyPack.Facepalm"] = "rbxassetid://87042378842023",
	["SheriffPack.Howdy"] = "rbxassetid://86455381930875",
	["SheriffPack.GotIt"] = "rbxassetid://138267781398143",
	["SheriffPack.Aww"] = "rbxassetid://117243301577418",
	["SheriffPack.Oops"] = "rbxassetid://114811908848269",
}
UIAssets.stickers = table.freeze(STICKERS)

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
	-- Character step 4 (2026-10-24): white shapes tinted per use. `stripes` a 128 px 45-degree stripe tile;
	-- `ribbon` a 256x80 flag with a notched right end (9-slice centre 24..200 x 16..64; the notch is the right 56 px);
	-- `burst` a 256 px spiky deal badge with an ink outline; `stamp` a 256 px double ring (the word is text on top).
	stripes = "rbxassetid://81273976323690",
	ribbon = "rbxassetid://91735525983207",
	burst = "rbxassetid://89635821324028",
	stamp = "rbxassetid://110715103243643",
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
	uiConfirm = { assetId = "rbxassetid://83738970696959", group = "UI", volume = 0.55, maxConcurrent = 2 },
	uiBack = { assetId = "rbxassetid://130280445606800", group = "UI", volume = 0.9, maxConcurrent = 2 },
	uiError = { assetId = "rbxassetid://139831732223870", group = "UI", volume = 0.9, maxConcurrent = 2 },
	uiCta = { assetId = "rbxassetid://78569365251759", group = "UI", volume = 1, maxConcurrent = 1 },
	uiPromptHold = { assetId = "rbxassetid://105267179969138", group = "UI", volume = 1, maxConcurrent = 1 },
	uiPromptDone = { assetId = "rbxassetid://134811176097827", group = "UI", volume = 0.6, maxConcurrent = 2 },
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
