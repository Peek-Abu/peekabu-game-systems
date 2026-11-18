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
	| "acorns"
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
	| "daily"
	| "featured"
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
	| "inventory"
	| "pippaHappy"
	| "pippaSkins"
	| "priceTag"
	| "pippaWorried"
	| "radio"
	| "settings"
	| "shop"
	| "stickers"
	| "spray"
	| "stamina"
	| "statQuiet"
	| "statSpeed"
	| "statStamina"
	| "statStrength"
	| "statSuction"
	| "stapler"
	| "stopwatch"
	| "temperature"
	| "trophy"
	| "truck"
	| "vacuum"
	| "vacuumBrass"
	| "weatherClear"
	| "weatherCloudy"
	| "weatherWindy"
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
	-- Pippa's own foot (owner pick); redrawn 2026-11-13 with simpler fur and motion lines, no stars (decal
	-- 139460474011465).
	abilityLetsGo = "rbxassetid://124538881139374",
	abilityPottedPlant = "rbxassetid://120058837938191",
	abilitySpotIt = "rbxassetid://72513443568229",
	-- Gleam bundle renders, smallest to biggest, made from the Gleam gem itself (v2, 2026-10-24).
	gleamPile = "rbxassetid://112951566480973",
	gleamBucket = "rbxassetid://120954864254019",
	gleamCrate = "rbxassetid://71294352475481",
	gleamTruck = "rbxassetid://86130539333417",
	-- The hub's station renders (2026-11-12): the shift bell and the radio from their models, the coffee mug from the
	-- break room's (decals 127753490073652, 135622491578671, 132800978467871).
	bell = "rbxassetid://85494966459975",
	clock = "rbxassetid://97995675031546",
	coffee = "rbxassetid://115766343705043",
	radio = "rbxassetid://81820573675358",
	dust = "rbxassetid://87348303383802",
	fishtank = "rbxassetid://72370733106499",
	flashlight = "rbxassetid://115788026706324",
	-- Owner picks 2026-11-13 (one picture per job, no more shared gift): the daily reward's calendar with a gold tick and
	-- the Shop's Featured spotlight (GPT renders, ink outline, floor shadow cut away before the outline; Icey Labs v2
	-- decals 87370888087827 / 94822868730395).
	daily = "rbxassetid://97644014132156",
	featured = "rbxassetid://94219536392095",
	-- Round 3 (glossy, softer shine; owner picks 2026-11-13): the Inventory's backpack and the price tag on what you
	-- can buy (decals 108925873210186 / 79687435541286).
	inventory = "rbxassetid://81160659671419",
	priceTag = "rbxassetid://140520500336666",
	-- Round 2 (glossy family, softer shine; owner picks 2026-11-13): the Shop's stall and the sticker sheet for sticker
	-- packs, stickers and the chat wheel (Icey Labs decals 106048651825814 / 104162197575790). They replace the shared
	-- gift box.
	shop = "rbxassetid://78344221274424",
	stickers = "rbxassetid://114382938678176",
	acorns = "rbxassetid://116086695828146", -- the Thanksgiving event's matte acorn (owner A4 yes 2026-11-16, decal 108178476017281)
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
	-- Bramble's portraits (the School's owl; its calm face and its chasing one): owner picks Calm A and Hunt A
	-- (2026-11-12, Icey Labs; decals 107616608770271 / 72204075980314), rendered from the v4 model through Harlow's
	-- iconize.py. OccupantPortraitAssets shows a neutral stand-in for any slot left "", never Harlow's.
	brambleCalm = "rbxassetid://113499760594559",
	brambleHunt = "rbxassetid://113099808413297",
	managerCalm = "rbxassetid://79215225592922",
	managerHunt = "rbxassetid://126690679697372",
	monitor = "rbxassetid://115152845494708",
	mop = "rbxassetid://135344307549758",
	-- Today's Pippa waving (owner picks 2026-11-13, rendered from her v13 model with no hand in her head): coral, the
	-- default employee, for the crew icons; lavender with glasses (her Owner Special skin) for Skins (decals
	-- 89385811608046 / 70701119889101).
	pippaHappy = "rbxassetid://126227546924097",
	pippaSkins = "rbxassetid://97692146860492",
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
	-- Today's truck (characters/truck v3, the purple WE CLEAN UP THE NIGHT band), rendered and ink-outlined like the
	-- other kit icons (P1 placeholders, owner yes 2026-11-15; Icey Labs, decal 133086114130489).
	truck = "rbxassetid://107674041401017",
	vacuum = "rbxassetid://95204983643911",
	vacuumBrass = "rbxassetid://70576303094914",
	xp = "rbxassetid://77433204551858",
	-- The landing readout's renders (ShiftLandingReadout): a thermometer and the night's weather (clear night, clouds,
	-- wind). Local Flux + iconize, 256 px, ink outline baked, no drop baked, no face, no 4-point sparkle; owner picks
	-- 2026-11-18 (T4, C2, K1, W4; reports/threat-maps/icons). Icey Labs; decals 121508007017554, 135053246137181,
	-- 113222859411399, 116178114931214. The readout draws a line with no icon while its slot is "".
	temperature = "rbxassetid://123287956488424",
	weatherClear = "rbxassetid://94381949907537",
	weatherCloudy = "rbxassetid://93629359480804",
	weatherWindy = "rbxassetid://76996302988307",
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
	-- The Office's places card: a real Studio Play shot of today's Office, the Manager waiting in his office doorway
	-- with the lights low, graded like the School card (P1 placeholders, owner pick "Lights low" 2026-11-15; Icey Labs,
	-- decal 81502937170609; source in characters/ui/implemented/upload/photos/office-2026-11-15).
	officeCard = "rbxassetid://98404010123546",
	-- The three SOON places' cards: each front built from our own yard pieces in Studio, taped shut, shot at dusk and
	-- graded like the School card (P1 placeholders, owner yes 2026-11-15; Icey Labs, decals 126741071058199 /
	-- 101057075096880 / 124768571529726; source in characters/ui/implemented/upload/photos/sites-2026-11-15).
	hospitalCard = "rbxassetid://70554632250088",
	motelCard = "rbxassetid://106881096176586",
	mallCard = "rbxassetid://120948393336511",
	managerPortrait = "rbxassetid://136047524517573",
	-- The Office's trip-card picture: a real Studio Play shot of today's Office, Pippa from behind with her vacuum and
	-- the Manager across the open-plan room, graded 16:9 like schoolWide (P1 placeholders, owner yes 2026-11-15; Icey
	-- Labs, decal 93654867486186; source in characters/ui/implemented/upload/photos/office-2026-11-15).
	officeWide = "rbxassetid://112756914310404",
	-- The School's trip-card picture (the Office's is officeWide): a real Studio shot of Pippa from behind with Bramble
	-- down a Maple Hill locker hall, graded like officeWide (owner K5 yes 2026-11-13, replacing the AI picture; Icey
	-- Labs, decal 93629730256648). An empty slot would draw the School map card's look instead (ShiftTransitViewModel.slip).
	schoolWide = "rbxassetid://124690567292753",
	-- The School's places-menu card: a real Studio shot of Bramble in a Maple Hill locker hall, graded like the other
	-- place cards (owner K3 yes 2026-11-13; Icey Labs, decal 87857217997292; source in
	-- characters/ui/implemented/upload/photos/school-card-2026-11-13).
	schoolCard = "rbxassetid://111071270210494",
	pippaPortrait = "rbxassetid://100337810904422",
	-- Today's truck, a big ink-outlined cut-out (P1 placeholders, owner yes 2026-11-15; Icey Labs, decal 122771971955055).
	truckCut = "rbxassetid://108315866600994",
	-- Today's coral Pippa cheering, both arms up, on the empty award card (owner 2026-11-13: the old salute pressed her
	-- hand into her head; decal 102894946805091).
	pippaCheerCut = "rbxassetid://89228375154099",
	-- The GUIDE page (p075 scene menus, owner yes 2026-11-14; DepotGuideViewModel): four real posed Studio Play shots
	-- for HOW TO PLAY (592x720, the place-card grade) and the MONSTERS cards' graded backdrops and outlined cut-outs
	-- (the live Manager facing the camera, Bramble's head turned). Icey Labs, owner OK 2026-11-14; each id is the Image
	-- under the uploaded decal named beside it (upload.log in the p075 notes folder).
	guideHopOn = "rbxassetid://134935606275101", -- decal 106143816706920
	guideVacuum = "rbxassetid://90108017151840", -- decal 134684012238364
	guideHide = "rbxassetid://93863428782398", -- decal 127988143607985
	guideLoadUp = "rbxassetid://135811094128961", -- decal 89585096801660
	guideManagerBack = "rbxassetid://91345355678790", -- decal 99766470767209
	guideManagerCut = "rbxassetid://118067372604187", -- decal 108126864461604
	guideBrambleBack = "rbxassetid://93014438530395", -- decal 85093706450462
	guideBrambleCut = "rbxassetid://131353849368499", -- decal 100407953750316
	guideSoonBack = "rbxassetid://129093281003077", -- decal 95751654599901
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
	-- The Thanksgiving Harvest Pack (owner A3/A7 yes 2026-11-16; decals in
	-- characters/ui/stickers/harvest-2026-11-16/final/upload.log).
	["HarvestPack.Thanks"] = "rbxassetid://111662959105450",
	["HarvestPack.Cozy"] = "rbxassetid://86795819097019",
	["HarvestPack.Yum"] = "rbxassetid://80592040818757",
}
UIAssets.stickers = table.freeze(STICKERS)

-- The kit's drawn pieces (implemented/tools/make_toon_assets.py, all at 2x). The goo: `capTile` (256x112) and
-- `poolTile` (256x80) are one whole tile each; `gooEnds` is the atlas of their ends (cap ends at y 0, 256x112 each;
-- pool ends at y 128, 256x80 each). `glow` is a 128 px white 9-slice (centre 48..80) tinted per use; `patternBubbles` (120)
-- is a white tile tinted per panel (violet rings on cream, white bubbles on dark; the 4-point sparkle tile was dropped,
-- owner pick 2026-11-13).
UIAssets.toon = table.freeze({
	capTile = "rbxassetid://114961170504517",
	poolTile = "rbxassetid://106249912761815",
	gooEnds = "rbxassetid://70785823038696",
	glow = "rbxassetid://78717613960831",
	rays = "rbxassetid://103836764476829",
	patternBubbles = "rbxassetid://90150192373857",
	-- The "you earned it" mark (ToonSparkle): three soap bubbles, owner pick 2026-11-13 over the 4-point star (Icey Labs
	-- decal 111550379423940).
	sparkle = "rbxassetid://74624776191966",
	-- Character step 4 (2026-10-24): white shapes tinted per use. `stripes` a 128 px 45-degree stripe tile;
	-- `ribbon` a 256x80 flag with a notched right end (9-slice centre 24..200 x 16..64; the notch is the right 56 px);
	-- `burst` a 256 px spiky deal badge with an ink outline; `stamp` a 256 px double ring (the word is text on top).
	stripes = "rbxassetid://81273976323690",
	ribbon = "rbxassetid://91735525983207",
	burst = "rbxassetid://89635821324028",
	stamp = "rbxassetid://110715103243643",
})

-- The CCTV feed's line strip (CatchCctvPanel): 16x12 px, a white line over a clear gap, tiled once per scan gap and
-- tinted in game. In-house (P1 placeholders, owner yes 2026-11-15; Icey Labs, decal 94783442860335).
UIAssets.cctv = table.freeze({
	scanlines = "rbxassetid://88794528076200",
})

-- Cleanup Crew UI sounds (round-2/3 picks, in-house, the paperwork hierarchy: pitch up = yes, down = back, dull =
-- denied), all 2D in the UI group. Minor: hover (a paper tick) and click (tab flick + card), family P. Important: confirm
-- (felt thunk + clip + one vibes note in F, family S), back (lower, shorter) and error (a dull thud + falling minor 2nd),
-- family P. Critical: the CTA (confirm + a time-clock punch + rising F-A-C + a small ding, family S) for Start shift and
-- Clock out. Prompts: the hold wind-up (a pizz F major scale, stretched to the hold) and the done (confirm S's felt and
-- clip + a pizz F chord). Played by UISoundSystem by tier (UISoundFormulas.Tier -> TIERS).
local SOUNDS: { [string]: SoundTypes.SoundDef } = {
	uiHover = { assetId = "rbxassetid://125412787340819", group = "UI", volume = 0.7, maxConcurrent = 2 },
	-- Click and back +2 dB (owner play-check 11-14: "I dont really hear sounds... clicking shop menu in hub"): the
	-- quietest presses sat 8 dB under the hub radio.
	uiClick = { assetId = "rbxassetid://122165734026820", group = "UI", volume = 1.1, maxConcurrent = 2 },
	uiConfirm = { assetId = "rbxassetid://83738970696959", group = "UI", volume = 0.55, maxConcurrent = 2 },
	uiBack = { assetId = "rbxassetid://130280445606800", group = "UI", volume = 1.1, maxConcurrent = 2 },
	uiError = { assetId = "rbxassetid://139831732223870", group = "UI", volume = 0.9, maxConcurrent = 2 },
	uiCta = { assetId = "rbxassetid://78569365251759", group = "UI", volume = 1, maxConcurrent = 1 },
	uiPromptHold = { assetId = "rbxassetid://105267179969138", group = "UI", volume = 1, maxConcurrent = 1 },
	uiPromptDone = { assetId = "rbxassetid://134811176097827", group = "UI", volume = 0.6, maxConcurrent = 2 },
	-- Creator Store picks (the owner's sound route test, 2026-11-14: the library on every card), played in place:
	-- a scene / menu opening (Roblox GUI - Swipe, the "panel open" pick) and a shop buy that went through (Roblox GUI -
	-- Purchase, the "shop buy" pick). Volumes put them at about -24 and -19 dB (the UI band; the buy's peak under -1).
	uiOpen = { assetId = "rbxassetid://17208405682", group = "UI", volume = 2.7, maxConcurrent = 1 },
	-- The shop buy, replaced by the owner's tryout round-2 pick A (2026-11-17): an old cash register drawer, one bell
	-- ding and two coins (ElevenLabs SFX, Starter plan, Icey Labs; mastered to -20 LUFS short-term, peak -1 dBFS).
	-- Volume 1 is a starting level until the owner's hear-check. Was Roblox GUI - Purchase (17208380755) at volume 2.
	uiPurchase = { assetId = "rbxassetid://96002741326326", group = "UI", volume = 1, maxConcurrent = 1 },
	-- Switching tabs (menu bar, board tabs, shop filter chips): one quiet finger tap on a cardboard folder. Owner
	-- tryout round 3 pick (2026-11-17); ElevenLabs SFX, Starter plan, Icey Labs (-24 LUFS). Was Roblox_UI_Paper_Swipe
	-- (15675037413, the library-round pick B) at volume 1.5; volume 1 is a starting level that awaits the owner's
	-- hear-check.
	uiTab = { assetId = "rbxassetid://72293470737561", group = "UI", volume = 1, maxConcurrent = 2 },
	-- The emote wheel or the chat wheel opening (UISoundFormulas.wheelOpen, played by EmoteServiceClient and
	-- CalloutServiceClient; their scenes open quietly): a paper fan flicks open with a soft whoosh (0.6 s, -22 LUFS).
	-- Owner tryout round 3 pick (2026-11-17); ElevenLabs SFX, Starter plan, Icey Labs. It replaced the menu open
	-- (uiOpen, Roblox GUI - Swipe 17208405682) for those two wheels only. Volume 1 is a starting level that awaits the
	-- owner's hear-check.
	uiWheelOpen = { assetId = "rbxassetid://124416513239859", group = "UI", volume = 1, maxConcurrent = 1 },
	-- A Legendary shop buy (the offer's top rarity; a bundle's highest-rarity item), played by ShopServiceClient on top
	-- of the purchase (uiPurchase stays for every buy; UISoundFormulas.buyExtra over UIAssets.buySounds). One F major
	-- full-orchestra hit with a felt bass drum and a soft crash, hit at 0 s, 2.05 s (-13 LUFS integrated, true peak
	-- -1 dBFS). Owner pick 2026-11-17 ("For legendary purchase - orchestra hit style!"), in-house (ElevenLabs Starter
	-- stems hand-layered with mix_sting.py), Icey Labs. A reward sting, so the Reward bus. Mastered loud: volume 0.6
	-- is a starting level that awaits the owner's hear-check.
	shopBuyLegendary = {
		assetId = "rbxassetid://125716350432533",
		group = "SFX",
		bus = "Reward",
		volume = 0.6,
		maxConcurrent = 1,
	},
	-- The rarity ladder's shop-buy extras (UIAssets.buySounds), played by ShopServiceClient on top of the purchase like
	-- shopBuyLegendary: owner rarity-ladder pick 2026-11-17, in-house (tuned orchestral stings, ElevenLabs Starter stems
	-- hand-layered with mix_sting.py, one family in F major), Icey Labs. Each volume is a starting level that awaits the
	-- owner's hear-check.
	-- A Common or Uncommon buy: the register plus a tiny note (the owner's "cash register + a tiny note"): two rising
	-- notes onto a soft chord with a long ring-out, 2.9 s (-18 LUFS; the same asset as the Locker's Uncommon chime).
	-- Kept quiet under the register.
	shopBuySmall = {
		assetId = "rbxassetid://129210679520094",
		group = "SFX",
		bus = "Reward",
		volume = 0.4,
		maxConcurrent = 1,
	},
	-- A Rare buy: a small flourish into a warm chord, 1.73 s (-16 LUFS; the same asset as the Locker's Rare chime).
	shopBuyRare = {
		assetId = "rbxassetid://116606102485127",
		group = "SFX",
		bus = "Reward",
		volume = 0.6,
		maxConcurrent = 1,
	},
	-- An Epic buy: a fast run into a strong orchestra chord, 2.18 s (-14 LUFS).
	shopBuyEpic = {
		assetId = "rbxassetid://104331550984161",
		group = "SFX",
		bus = "Reward",
		volume = 0.6,
		maxConcurrent = 1,
	},
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
	open = "uiOpen",
	purchase = "uiPurchase",
	tab = "uiTab",
	wheel = "uiWheelOpen",
}
UIAssets.soundTiers = table.freeze(TIERS)

-- The extra sting a shop buy plays on top of the purchase, by the buy's top rarity (UISoundFormulas.buyExtra): the
-- owner's rarity ladder (picks 2026-11-17). Common ("default") and Uncommon share the small note; Odd has no buy pick.
local BUY_SOUNDS: { [string]: string } = {
	default = "shopBuySmall",
	uncommon = "shopBuySmall",
	rare = "shopBuyRare",
	epic = "shopBuyEpic",
	legendary = "shopBuyLegendary",
}
UIAssets.buySounds = table.freeze(BUY_SOUNDS)

return UIAssets
