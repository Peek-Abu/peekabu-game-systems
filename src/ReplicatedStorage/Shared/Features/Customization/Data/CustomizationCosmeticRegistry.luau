--!strict
--[=[
	CustomizationCosmeticRegistry: the ONE catalog of customization cosmetics + the channel descriptor table.

	Modernized successor to the old game's scattered `ReplicatedStorage.Customs` folder + the untyped
	`RequireableCustomization` blob. Every cosmetic id, its rig binding (mount socket / dye part name),
	and its unlock gating live here as typed data — so the validator, the plan-builder, and (later) the
	client UI all read one source of truth instead of hardcoding paths.

	Three kinds of entry:
	- MOUNT cosmetics (`hair`, `eyebrows`, `eyelashes`, `accessory`): an id that clones + welds onto a
	  named rig Attachment (`AddAccessory` semantics). Carries its `socket`, `lockable` flag, and how
	  many `colorChannels` (independently-pickable colors) it accepts.
	- DYES: an unlockable named color in the palette (Decision 7, hybrid dye model). A body-color channel
	  value with `source = "dye"` references one of these.
	- BODY-COLOR CHANNELS: descriptors binding a channel key to the rig part-name the application scans
	  for (Decision 10), plus whether the channel accepts a free RGB value.

	Grounded against the live `StarterCharacter` 2026-07-18 (sockets, part names, the `Customs.Locked`
	lockable set). Adding/removing a cosmetic is an edit here, never a schema change; a removed id is
	tolerated everywhere (get returns nil, the validators skip it), matching the disable-don't-delete
	rule affixes already follow.

	@class CustomizationCosmeticRegistry
]=]

--[=[
	A mount-based cosmetic (hair/eyebrows/eyelashes/accessory).
	@interface MountCosmetic
	.socket string -- the rig Attachment name this welds to
	.lockable boolean -- true when gated behind an entitlement unlock (default false = free)
	.colorChannels number -- how many independently-pickable Color values this cosmetic accepts (>= 0)
	.headTypes { [string]: boolean }? -- head modes this works with; ABSENT = both (see
		-- CustomizationWearRules). Populated by 5b's content pass — the old art's `Covered`
		-- StringValues were all empty, so there was nothing to port.
]=]
--[=[
	A per-cosmetic fit adjustment, as PLAIN NUMBERS rather than a CFrame: studs on each axis, degrees
	on each rotation. Data, not geometry — it stays diff-friendly in review, and `CustomizationPlanUtils`
	composes it into a CFrame where that maths is unit-tested.
	@interface Offset
	.x number? .y number? .z number? -- studs
	.rx number? .ry number? .rz number? -- degrees
]=]
export type Offset = {
	x: number?,
	y: number?,
	z: number?,
	rx: number?,
	ry: number?,
	rz: number?,
}

export type MountCosmetic = {
	socket: string,
	-- Fit adjustment applied where this cosmetic meets its socket. ABSENT means "no opinion" — which
	-- is deliberately different from an all-zero offset, where an author decided zero was right.
	offset: Offset?,
	-- Every socket this cosmetic occupies, when it is more than one. ABSENT = just `socket`.
	--
	-- Some cosmetics are several pieces at once: shoes are a Model holding a Left and a Right Accessory
	-- (`ShoeLeft` / `ShoeRight`), and the art's two-tone accessories are a second Accessory on a
	-- DIFFERENT socket — `Cowl 1` mounts on `Head` while its companion `Cowl 1 2` mounts on `Chest`.
	-- Both are the same shape, so neither is a special case.
	sockets: { string }?,
	-- Sockets this cosmetic RESERVES against other accessories, when that differs from where its
	-- pieces mount. The cowl is one Accessory bound at `Head` whose mantle covers the chest: it mounts
	-- at one socket and occupies two. ABSENT = it occupies exactly what it mounts to, which is the
	-- common case. Keeping these separate matters — conflating them made the conformance checker
	-- demand a piece whose Handle carries `Chest`, which no such piece exists to satisfy.
	occupies: { string }?,
	lockable: boolean,
	colorChannels: number,
	headTypes: { [string]: boolean }?,
}

--[=[
	An unlockable palette color (Decision 7).
	@interface DyeEntry
	.color { r: number, g: number, b: number } -- 0..255 integers
	.lockable boolean
]=]
export type DyeEntry = {
	color: { r: number, g: number, b: number },
	lockable: boolean,
}

--[=[
	A body-color channel descriptor (Decision 10): binds a channel key to the rig part-name the
	application scans for, plus whether the channel accepts a free RGB value.
	@interface BodyChannel
	.key string -- the Appearance.body field key (e.g. "color1")
	.part string -- the rig BasePart name to color (uniform across every part with that name)
	.allowFreeRgb boolean -- whether a free RGB value (not just a dye id) is permitted here
]=]
export type BodyChannel = {
	key: string,
	part: string,
	allowFreeRgb: boolean,
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CustomizationRegistryCheck =
	require(ReplicatedStorage.Shared.Features.Customization.Rules.CustomizationRegistryCheck)

-- Number of generic, independently-selectable accessory slots on a character (the old game's 3).
local ACCESSORY_SLOTS = 3

-- The character's head modes. The rig implements these as paired parts toggled against each other
-- (`Head.Skin Color-Covered` / `Skin Color-Uncovered`, plus the `FacemaskLower` subtree), so this set is
-- a contract with the ART, not free-form content — growing it means authoring new rig parts.
--
-- Unlike every other channel, head type is NOT optional on an Appearance: a character always has a
-- head, and an absent value would leave the facemask in an undefined state. Hence a DEFAULT that the
-- profile skeleton stamps.
--
-- Each mode declares which named head parts it SHOWS and HIDES. Derived from the old game's head-type block, but
-- expressed as DATA instead of an imperative transparency dance: the two modes must be exact
-- complements (a part visible in both would leave two face meshes overlapping), which the spec asserts.
--
-- `FacemaskLower` and `Color 1` are SUBTREES, not single parts — the application shell applies
-- visibility recursively, and touches ONLY these named entries: the rig's head also carries
-- ParticleEmitters, an OxygenUI BillboardGui, HeadHitbox and ClimbPart that are not ours to toggle.
export type HeadTypeDef = {
	show: { string },
	hide: { string },
}
local HEAD_TYPES: { [string]: HeadTypeDef } = {
	Uncovered = {
		show = { "Skin Color-Uncovered", "FacemaskLower" },
		hide = { "Skin Color-Covered", "Color 1" },
	},
	Covered = {
		show = { "Skin Color-Covered", "Color 1" },
		hide = { "Skin Color-Uncovered", "FacemaskLower" },
	},
}
local DEFAULT_HEAD_TYPE = "Uncovered"

-- Sorted for deterministic iteration (Cmdr enums, UI lists) — map order is not guaranteed.
local HEAD_TYPE_NAMES: { string } = {}
for name in HEAD_TYPES do
	table.insert(HEAD_TYPE_NAMES, name)
end
table.sort(HEAD_TYPE_NAMES)

assert(
	HEAD_TYPES[DEFAULT_HEAD_TYPE],
	`[CustomizationCosmeticRegistry] DEFAULT_HEAD_TYPE "{DEFAULT_HEAD_TYPE}" is not a registered head type`
)

-- Where customization art lives, as a PATH from ReplicatedStorage. Declared here so the shell, the
-- conformance checker and any future tooling all resolve the same root instead of each carrying a
-- literal — the folder was renamed once already (`Customs` -> `Assets/Customization`, 2026-07-20) and
-- a second copy of that string would have been missed.
--
-- Domain-first, not type-first: a domain's assets stay together, so customization gaining a sound
-- later does not split it across `Models/` and `Sounds/`. Siblings under `Assets` are other domains.
local ART_ROOT: { string } = { "Assets", "Customization" }

-- The art folder each category's models live in, under ART_ROOT.
--
-- Lookup reads the DECLARED folder as a direct child; it is never a recursive search of the art root.
-- That recursion is what let the old inconsistent layout work at all, and it is actively unsafe:
-- catalogs deliberately reuse ids across folders (clothing1 and clothing2 both contain "Skin2"), so a
-- root-wide search returns whichever duplicate it reaches first — a bug we have already shipped once.
-- Declaring the folder makes "which art is this?" answerable by reading this table instead of by
-- guessing at tree order.
local CATEGORY_ART_FOLDERS: { [string]: string } = {
	hair = "Hair",
	eyebrows = "Eyebrows",
	eyelashes = "Eyelashes",
	accessory = "Accessories",
	shoes = "Shoes",
	-- Not a mount category: the texture catalog's StringValues live here, and the shell resolves them
	-- the same way, so the folder name belongs in the same table rather than as a literal in the shell.
	texture = "Textures",
}

-- The mount-cosmetic catalog, by category. Hair/eyebrows/eyelashes share one socket per category and
-- are generated below; the accessory catalog (per-id socket) is folded from ACCESSORY_ROWS.
local CATALOG: { [string]: { [string]: MountCosmetic } } = {
	hair = {},
	eyebrows = {},
	eyelashes = {},
	accessory = {},
	shoes = {},
}

-- Head cosmetics: index 1 of each is the deliberate "None" option (modeled as id = nil, never a
-- catalog entry), so the real ids start at 2. One color channel each; none lockable.
--
-- `headTypes` is the 5b content pass's authored data (observed in Studio, since the old art's `Covered`
-- StringValues were all empty). Hair is STRICTLY PARTITIONED — every style belongs to exactly one head
-- mode, none work with both — so a head-type switch always invalidates the equipped hair. That is a
-- real property of the art, not a modelling choice.
local function fillHeadCategory(
	category: string,
	socket: string,
	firstId: number,
	lastId: number,
	prefix: string,
	headTypes: { [string]: boolean }?
)
	for i = firstId, lastId do
		CATALOG[category][prefix .. i] = { socket = socket, lockable = false, colorChannels = 1, headTypes = headTypes }
	end
end
local COVERED_ONLY: { [string]: boolean } = { Covered = true }
local UNCOVERED_ONLY: { [string]: boolean } = { Uncovered = true }

fillHeadCategory("hair", "Hair", 2, 8, "Hair", COVERED_ONLY)
fillHeadCategory("hair", "Hair", 9, 11, "Hair", UNCOVERED_ONLY)
-- Eyebrows/eyelashes are left UNRESTRICTED pending observation — absent means "works with both", the
-- permissive default, so nothing is wrongly forbidden while their verdicts are outstanding.
fillHeadCategory("eyebrows", "Eyebrows", 2, 4, "Eyebrows")
fillHeadCategory("eyelashes", "Eyes", 2, 3, "Eyelashes")

-- Shoes: ONE cosmetic occupying two sockets. The art (`Shoes/Shoes1`) is a Model holding a `Left` and
-- a `Right` Accessory, each with its own Handle and socket Attachment — so the shell mounts both
-- pieces and the conformance checker verifies both. Content is a single option today, a known gap.
for _, id in { "Boots1", "Shoes1" } do
	CATALOG.shoes[id] = {
		socket = "ShoeLeft",
		sockets = { "ShoeLeft", "ShoeRight" },
		lockable = false,
		colorChannels = 1,
	}
end

-- The cosmetic a category falls back to, per head type. Serves two jobs: seeding a NEW character so
-- nobody starts bald, and substituting after a head-type switch clears a now-invalid cosmetic.
--
-- An ABSENT head type means "no default" — deliberately so for Covered, where the developer's call is
-- that a hood/mask makes a default hair pointless. Absence is the way to express that, not a sentinel.
local DEFAULT_COSMETICS: { [string]: { [string]: string } } = {
	hair = { Uncovered = "Hair9" },
	-- Eyebrows are unrestricted (no `headTypes`), so the same default holds in both modes — declared
	-- per head type anyway, because that is the shape a head-type switch reads when refilling a
	-- category it had to clear.
	eyebrows = { Uncovered = "Eyebrows4", Covered = "Eyebrows4" },
	-- The rig used to ship wearing boots as fixed geometry inside each foot, which made footwear the
	-- one visible thing that was half rig and half cosmetic — and made equipping any shoe produce two
	-- overlapping pairs. The boots were extracted into `Boots1` art and the rig left bare, so
	-- defaulting to them keeps every character shod exactly as before while the catalog now describes
	-- footwear completely. Barefoot is deliberately NOT a resting state, the same call made for bald;
	-- clearing stays expressible for a future mutation or feature.
	shoes = { Uncovered = "Boots1", Covered = "Boots1" },
}

-- Load-time guard: a default must be REGISTERED and COMPATIBLE with the head type it is declared
-- under. Without this, declaring `Covered = "Hair9"` (Hair9 is Uncovered-only) would quietly seed every
-- new profile with a value the validator then rejects — a boot-time failure is far cheaper than that.
-- Checked against the raw `headTypes` field rather than CustomizationWearRules, which requires this
-- module and would be a dependency cycle.
for category, byHeadType in DEFAULT_COSMETICS do
	for headType, id in byHeadType do
		assert(
			HEAD_TYPES[headType] ~= nil,
			`[CustomizationCosmeticRegistry] DEFAULT_COSMETICS.{category} declares unknown head type "{headType}"`
		)
		local entry = CATALOG[category] and CATALOG[category][id]
		assert(
			entry,
			`[CustomizationCosmeticRegistry] DEFAULT_COSMETICS.{category}.{headType} = "{id}" is not registered`
		)
		assert(
			entry.headTypes == nil or entry.headTypes[headType] == true,
			`[CustomizationCosmeticRegistry] DEFAULT_COSMETICS.{category}.{headType} = "{id}" cannot be worn with "{headType}"`
		)
	end
end

-- Accessory catalog rows. `colorChannels` is 2 ONLY where the art was observed to carry a second
-- colour part (2026-07-20): channel 1 falls back to the Handle when there is no `Color 1` mesh, and
-- channel 2 paints the `Color2`/`Color 2` mesh. Every OTHER count here is still a default rather than
-- an observed fact — cosmetics whose parts are named `Part`/`MeshPart` (Shades, Tabard, Cowl 2) cannot
-- be multi-channel until their art names the parts, which is the asset passthrough's call.
-- Accessory catalog rows. `lockable`/`colorChannels` default to false/1. Seeded from the live Customs
-- catalog (2026-07-18); `-- REVIEW` marks entries to curate later (a one-line delete). Two-tone items
-- whose second color lived on a SEPARATE `X 2` object in the old art (FaceWrap2, Cowl 1 2, …) are kept
-- single-color here and flagged — how their second color is authored is an art/application call made at
-- Task 3 (the mounting shell), not a schema concept.
type AccessoryRow = {
	id: string,
	socket: string,
	-- Every socket the accessory OCCUPIES, when more than one (the cowl is a hood on Head plus a mantle
	-- on Chest). Absent = just `socket`. Occupancy is what reserves those sockets against another
	-- accessory being worn through this one.
	sockets: { string }?,
	-- See MountCosmetic.occupies: what the accessory RESERVES, when that is wider than where it mounts.
	occupies: { string }?,
	lockable: boolean?,
	colorChannels: number?,
	headTypes: { [string]: boolean }?,
}
local ACCESSORY_ROWS: { AccessoryRow } = {
	-- Head
	{ id = "FishingHat", socket = "Head" },
	{ id = "PaperboyHat", socket = "Head" },
	{ id = "Hat Wrap", socket = "Head" },
	{ id = "Face Veil", socket = "Head", colorChannels = 2 },
	{ id = "Desert Hat", socket = "Head", colorChannels = 2 },
	{ id = "Hat 1", socket = "Head" },
	{ id = "Headband", socket = "Head" },
	{ id = "Headband 1", socket = "Head" },
	-- Merged with its old "Cowl 1 2" companion during the 5c asset passthrough: one Accessory, a hood on
	-- Head and a mantle on Chest. Declaring BOTH sockets is what reserves the chest against a separate
	-- chest accessory being worn through it.
	{ id = "Cowl 1", socket = "Head", occupies = { "Head", "Chest" } },
	{ id = "Cowl 2", socket = "Head" }, -- REVIEW: two-tone in old art (separate "Cowl 2 2" object) — revisit at Task 3
	{ id = "WizardHat", socket = "Head", lockable = true },
	{ id = "WoodMask", socket = "Head", lockable = true, colorChannels = 2 },
	-- Eyes
	{ id = "Round Glasses", socket = "Eyes", colorChannels = 2 },
	{ id = "UFrame Glasses", socket = "Eyes", colorChannels = 2 },
	{ id = "Goggles", socket = "Eyes", colorChannels = 2 },
	{ id = "Glasses 2", socket = "Eyes" },
	{ id = "Shades1", socket = "Eyes" },
	{ id = "Shades 2", socket = "Eyes" },
	{ id = "Shades 3", socket = "Eyes" },
	{ id = "Blind Fold", socket = "Eyes" },
	-- "BlindFold1" was catalogued here too and resolves to NO art: it is a typo'd duplicate of
	-- "Blindfold 1", confirmed against the art tree 2026-07-20. Dropped rather than left to report as a
	-- permanent conformance failure.
	{ id = "Blindfold 1", socket = "Eyes" }, -- REVIEW: two-tone in old art (separate "Blindfold 2" object) — revisit at Task 3
	-- "Mechanics Goggles" is catalogued nowhere on purpose: the art is UNASSEMBLED — loose Models,
	-- Unions and Parts inside the Accessory, with no Handle and no socket Attachment (confirmed by the
	-- conformance checker 2026-07-20, which is what turned 5a's "REVIEW: no Handle in source" comment
	-- into a fact). Nothing in code can mount that. Re-add this row the moment the art gains a Handle
	-- with an "Eyes" Attachment; until then a permanently-failing check would only teach people to
	-- ignore the report.
	{ id = "MagicGoggles", socket = "Eyes", lockable = true, colorChannels = 2 },
	-- Mouth
	{ id = "FaceWrap", socket = "Mouth" }, -- REVIEW: two-tone in old art (separate "FaceWrap2" object) — revisit at Task 3
	{ id = "Face Mask 1", socket = "Mouth" },
	{ id = "Face Mask 2", socket = "Mouth" },
	-- Chest
	{ id = "Poncho 1", socket = "Chest" },
	{ id = "Poncho 2", socket = "Chest" },
	{ id = "Tabard", socket = "Chest", lockable = true },
}
for _, row in ACCESSORY_ROWS do
	CATALOG.accessory[row.id] = {
		socket = row.socket,
		sockets = row.sockets,
		occupies = row.occupies,
		lockable = row.lockable == true,
		colorChannels = row.colorChannels or 1,
		headTypes = row.headTypes,
	}
end

-- Starter dye palette (Decision 7). Provisional — the real palette is a later curation pass; body-color
-- channels also allow free RGB, so 5a is usable without expanding this. None lockable yet.
local DYES: { [string]: DyeEntry } = {
	white = { color = { r = 255, g = 255, b = 255 }, lockable = false },
	black = { color = { r = 20, g = 20, b = 20 }, lockable = false },
	crimson = { color = { r = 150, g = 30, b = 40 }, lockable = false },
	azure = { color = { r = 45, g = 90, b = 170 }, lockable = false },
	forest = { color = { r = 45, g = 105, b = 60 }, lockable = false },
	amber = { color = { r = 200, g = 160, b = 60 }, lockable = false },
}

--[=[
	A SURFACE channel: a rig part-group whose material/pattern and texture the player can restyle.

	Distinct from a mount cosmetic (no socket, nothing welded) and from a body-color channel (no Color):
	patterns are `SurfaceAppearance` swaps and textures are `Texture` id assignments, both applied to
	every rig part of the named group. Modelled as descriptor rows so adding a channel stays data.
	@interface SurfaceChannel
	.key string -- the Appearance.surfaces key
	.part string -- the rig BasePart name group to restyle
	.patterns string -- the catalog category its pattern ids are validated against
	.artFolder string -- the art folder the pattern instance is cloned FROM
]=]
export type SurfaceChannel = {
	key: string,
	part: string,
	patterns: string,
	artFolder: string,
}

-- Valid ids for the non-mount catalogs. Content is THIN by inheritance, not by oversight: the live art
-- has one real clothing pattern, five backpack patterns and eleven textures ("None" is not carried —
-- absent already means none). Adding options is an edit here once the art exists.
local SURFACE_CATALOG: { [string]: { [string]: boolean } } = {
	clothingPattern = { Skin2 = true },
	backpackPattern = { Back1 = true, Back2 = true, Back3 = true, Back4 = true, Skin2 = true },
	texture = {
		["Fish Net 1"] = true,
		["Fish Net 2"] = true,
		Fern = true,
		Floral = true,
		["Grunge 1"] = true,
		["Grunge 2"] = true,
		["Grunge 3"] = true,
		["Star 1"] = true,
		["Star 2"] = true,
		["Royal 1"] = true,
		["Royal 2"] = true,
	},
}

-- The restyleable part-groups, grounded against the live rig (2026-07-18).
-- `artFolder` is per-CHANNEL, not per-category: the primary and secondary variants share a validation
-- catalog but live in DIFFERENT art folders, and both contain an id called "Skin2". Looking up by
-- category alone would resolve to whichever copy a recursive search reached first.
local SURFACE_CHANNELS: { SurfaceChannel } = {
	{ key = "clothing1", part = "Color 1", patterns = "clothingPattern", artFolder = "ClothingPrimary" },
	{ key = "clothing2", part = "Color 2", patterns = "clothingPattern", artFolder = "ClothingSecondary" },
	{
		key = "backpack1",
		part = "Backpack Color 1",
		patterns = "backpackPattern",
		artFolder = "BackpackPrimary",
	},
	{ key = "backpack2", part = "Backpack Color 2", patterns = "backpackPattern", artFolder = "BackpackSecondary" },
}

local SURFACE_CHANNEL_BY_KEY: { [string]: SurfaceChannel } = {}
for _, channel in SURFACE_CHANNELS do
	assert(
		SURFACE_CHANNEL_BY_KEY[channel.key] == nil,
		`[CustomizationCosmeticRegistry] surface channel key "{channel.key}" is declared more than once`
	)
	assert(
		SURFACE_CATALOG[channel.patterns] ~= nil,
		`[CustomizationCosmeticRegistry] surface channel "{channel.key}" names unknown pattern catalog "{channel.patterns}"`
	)
	SURFACE_CHANNEL_BY_KEY[channel.key] = channel
end

-- Body-color channels: the uniform name-scan targets (grounded 2026-07-18). Head/facemask parts that
-- share a channel name are colored the same (correct — same outfit color); their covered/uncovered
-- VISIBILITY is a head-type concern (5b), not a coloring one — so there is no exclusion rule here.
--
-- `part` is matched as a PREFIX over the art's "-N" suffix convention, so one channel can cover a group
-- of parts: `Color 1` also claims `Color 1-2`, and `Skin Color` claims `Skin Color-Covered` and
-- `Skin Color-Uncovered`. Those two skin parts are hyphenated ON PURPOSE — the hyphen is what lets one
-- skin channel color both while the names stay DISTINCT, which head-type visibility requires (it looks
-- them up by exact name in HEAD_TYPES above). Removing the hyphen would silently unhook the skin
-- channel from the head; merging them into one name would break the covered/uncovered toggle.
local BODY_CHANNELS: { BodyChannel } = {
	{ key = "color1", part = "Color 1", allowFreeRgb = true },
	{ key = "color2", part = "Color 2", allowFreeRgb = true },
	{ key = "skin", part = "Skin Color", allowFreeRgb = true },
	{ key = "belt", part = "Belt Color", allowFreeRgb = true },
	{ key = "eye", part = "Eye Color", allowFreeRgb = true },
	{ key = "rope", part = "Rope Color", allowFreeRgb = true },
}

-- Body-channel lookup by key, and a guard that every declared key is unique.
local BODY_CHANNEL_BY_KEY: { [string]: BodyChannel } = {}
for _, channel in BODY_CHANNELS do
	assert(
		BODY_CHANNEL_BY_KEY[channel.key] == nil,
		`[CustomizationCosmeticRegistry] body channel key "{channel.key}" is declared more than once`
	)
	assert(
		channel.part ~= "",
		`[CustomizationCosmeticRegistry] body channel "{channel.key}" has an empty rig part name`
	)
	BODY_CHANNEL_BY_KEY[channel.key] = channel
end

-- Load-time validation: fail LOUD at boot rather than at apply time. Every mount cosmetic needs a
-- real socket + a sane color-channel count; every dye color is an in-range integer triple. The
-- individual rules live in CustomizationRegistryCheck, where they are testable.
for category, entries in CATALOG do
	-- A category with no declared folder would be unresolvable at apply time, and SILENTLY so — the
	-- shell skips art it cannot find. Fail at load instead: this is data this repo owns.
	assert(
		CATEGORY_ART_FOLDERS[category] ~= nil,
		`[CustomizationCosmeticRegistry] category "{category}" has no entry in CATEGORY_ART_FOLDERS`
	)
	for id, entry in entries do
		assert(entry.socket ~= "", `[CustomizationCosmeticRegistry] {category}."{id}" has an empty socket`)
		CustomizationRegistryCheck.assertSocketList(entry.sockets, `{category}."{id}".sockets`)
		CustomizationRegistryCheck.assertSocketList(entry.occupies, `{category}."{id}".occupies`)
		assert(
			entry.colorChannels == math.floor(entry.colorChannels) and entry.colorChannels >= 0,
			`[CustomizationCosmeticRegistry] {category}."{id}" has an invalid colorChannels {entry.colorChannels}`
		)
	end
end
for id, dye in DYES do
	assert(dye.color ~= nil, `[CustomizationCosmeticRegistry] dye "{id}" has no color`)
	CustomizationRegistryCheck.assertColorComponent(dye.color.r, `dye "{id}".r`)
	CustomizationRegistryCheck.assertColorComponent(dye.color.g, `dye "{id}".g`)
	CustomizationRegistryCheck.assertColorComponent(dye.color.b, `dye "{id}".b`)
end
assert(
	ACCESSORY_SLOTS >= 1 and ACCESSORY_SLOTS % 1 == 0,
	"[CustomizationCosmeticRegistry] ACCESSORY_SLOTS must be a positive integer"
)

-- Categories that declare a fallback, sorted so callers seeding a new appearance iterate
-- deterministically rather than in map order.
local DEFAULTED_CATEGORIES: { string } = {}
for category in DEFAULT_COSMETICS do
	table.insert(DEFAULTED_CATEGORIES, category)
end
table.sort(DEFAULTED_CATEGORIES)

local CustomizationCosmeticRegistry = {
	ACCESSORY_SLOTS = ACCESSORY_SLOTS,
	DEFAULT_HEAD_TYPE = DEFAULT_HEAD_TYPE,
}

--[=[
	True iff `value` is a registered head type.
	@param value string
	@return boolean
]=]
function CustomizationCosmeticRegistry.isHeadType(value: string): boolean
	return HEAD_TYPES[value] ~= nil
end

--[=[
	Every category that declares a fallback cosmetic, sorted.
	@return { string }
]=]
function CustomizationCosmeticRegistry.defaultedCategories(): { string }
	return DEFAULTED_CATEGORIES
end

--[=[
	The cosmetic `category` falls back to under `headType`, or nil when that mode has no default (a
	deliberate "start bald here", not an oversight).
	@param category string
	@param headType string
	@return string? -- a registered cosmetic id
]=]
function CustomizationCosmeticRegistry.defaultCosmetic(category: string, headType: string): string?
	local byHeadType = DEFAULT_COSMETICS[category]
	if not byHeadType then
		return nil
	end
	return byHeadType[headType]
end

--[=[
	The show/hide part sets for a head type, or nil if unregistered.
	@param value string
	@return HeadTypeDef?
]=]
function CustomizationCosmeticRegistry.headTypeDef(value: string): HeadTypeDef?
	return HEAD_TYPES[value]
end

--[=[
	Every registered head type, sorted for deterministic iteration.
	@return { string }
]=]
function CustomizationCosmeticRegistry.headTypes(): { string }
	return HEAD_TYPE_NAMES
end

--[=[
	The MountCosmetic for `id` in `category`, or nil if either the category or the id is unregistered.
	@param category string -- "hair" | "eyebrows" | "eyelashes" | "accessory"
	@param id string
	@return MountCosmetic?
]=]
function CustomizationCosmeticRegistry.get(category: string, id: string): MountCosmetic?
	local entries = CATALOG[category]
	if not entries then
		return nil
	end
	return entries[id]
end

--[=[
	Every socket `id` RESERVES against other accessories, in declaration order. Defaults to the sockets
	it mounts to, which is the common case; a cosmetic only declares `occupies` when it covers ground
	it does not bind to. Returns a COPY.
	@param category string
	@param id string
	@return { string }
]=]
function CustomizationCosmeticRegistry.occupiedSocketsOf(category: string, id: string): { string }
	local entry = CustomizationCosmeticRegistry.get(category, id)
	if entry and entry.occupies then
		return table.clone(entry.occupies)
	end
	return CustomizationCosmeticRegistry.socketsOf(category, id)
end

--[=[
	The art folder `category`'s models live in, under the art root, or nil for an unknown
	category. Callers read that folder's DIRECT children — see CATEGORY_ART_FOLDERS for why lookup is
	never recursive.
	@param category string
	@return string?
]=]
function CustomizationCosmeticRegistry.artFolder(category: string): string?
	return CATEGORY_ART_FOLDERS[category]
end

--[=[
	The path to the art root, from ReplicatedStorage — e.g. `{ "Assets", "Customization" }`. Callers
	walk it rather than hardcoding the folder names, so a future move is one edit here.
	@return { string }
]=]
function CustomizationCosmeticRegistry.artRootPath(): { string }
	return table.clone(ART_ROOT)
end

--[=[
	True iff `id` is a registered cosmetic in `category`.
	@param category string
	@param id string
	@return boolean
]=]
function CustomizationCosmeticRegistry.isRegistered(category: string, id: string): boolean
	return CustomizationCosmeticRegistry.get(category, id) ~= nil
end

--[=[
	True iff the cosmetic is registered AND gated behind an entitlement unlock. An unregistered id is
	reported as not lockable (so callers treat "unknown" and "free" alike at the ownership gate; the
	validator is what actually rejects an unregistered id).
	@param category string
	@param id string
	@return boolean
]=]
function CustomizationCosmeticRegistry.isLockable(category: string, id: string): boolean
	local entry = CustomizationCosmeticRegistry.get(category, id)
	return entry ~= nil and entry.lockable
end

--[=[
	Every socket `id` occupies, in declaration order; a single-socket cosmetic yields a one-entry list,
	and an unregistered id yields an empty one. Returns a COPY — the catalog is not a caller's to edit.
	@param category string
	@param id string
	@return { string }
]=]
function CustomizationCosmeticRegistry.socketsOf(category: string, id: string): { string }
	local entry = CustomizationCosmeticRegistry.get(category, id)
	if not entry then
		return {}
	end
	if entry.sockets then
		return table.clone(entry.sockets)
	end
	return { entry.socket }
end

--[=[
	How many Color values the cosmetic accepts, or nil if unregistered.
	@param category string
	@param id string
	@return number?
]=]
function CustomizationCosmeticRegistry.colorChannelsOf(category: string, id: string): number?
	local entry = CustomizationCosmeticRegistry.get(category, id)
	return entry and entry.colorChannels
end

--[=[
	The palette dye for `id`, or nil if unregistered.
	@param id string
	@return DyeEntry?
]=]
function CustomizationCosmeticRegistry.dye(id: string): DyeEntry?
	return DYES[id]
end

--[=[
	True iff `id` is a registered dye.
	@param id string
	@return boolean
]=]
function CustomizationCosmeticRegistry.isDyeRegistered(id: string): boolean
	return DYES[id] ~= nil
end

--[=[
	True iff the dye is registered AND gated behind an unlock. Unregistered → false (see isLockable).
	@param id string
	@return boolean
]=]
function CustomizationCosmeticRegistry.isDyeLockable(id: string): boolean
	local entry = DYES[id]
	return entry ~= nil and entry.lockable
end

--[=[
	Every surface channel descriptor, in declaration order.
	@return { SurfaceChannel }
]=]
function CustomizationCosmeticRegistry.surfaceChannels(): { SurfaceChannel }
	return SURFACE_CHANNELS
end

--[=[
	The surface channel for `key`, or nil if there is no such channel.
	@param key string
	@return SurfaceChannel?
]=]
function CustomizationCosmeticRegistry.surfaceChannel(key: string): SurfaceChannel?
	return SURFACE_CHANNEL_BY_KEY[key]
end

--[=[
	Every catalogued mount category, sorted. Sorted (like every other list accessor here) so callers
	that iterate — the conformance checker, tooling — produce stable, comparable output.
	@return { string }
]=]
function CustomizationCosmeticRegistry.categories(): { string }
	local categories: { string } = {}
	for category in CATALOG do
		table.insert(categories, category)
	end
	table.sort(categories)
	return categories
end

--[=[
	Every registered mount-cosmetic id in `category`, sorted; empty for an unknown category.
	@param category string
	@return { string }
]=]
function CustomizationCosmeticRegistry.ids(category: string): { string }
	local ids: { string } = {}
	local entries = CATALOG[category]
	if entries then
		for id in entries do
			table.insert(ids, id)
		end
		table.sort(ids)
	end
	return ids
end

--[=[
	Every registered id in a non-mount catalog, sorted — the value list a Cmdr enum or UI picker offers.
	@param category string
	@return { string }
]=]
function CustomizationCosmeticRegistry.surfaceIds(category: string): { string }
	local ids: { string } = {}
	local catalog = SURFACE_CATALOG[category]
	if catalog then
		for id in catalog do
			table.insert(ids, id)
		end
		table.sort(ids)
	end
	return ids
end

--[=[
	Every registered surface channel KEY, sorted — the value list a Cmdr enum offers.
	@return { string }
]=]
function CustomizationCosmeticRegistry.surfaceChannelKeys(): { string }
	local keys: { string } = {}
	for _, channel in SURFACE_CHANNELS do
		table.insert(keys, channel.key)
	end
	table.sort(keys)
	return keys
end

--[=[
	True iff `id` is registered in a non-mount catalog (`clothingPattern`, `backpackPattern`, `texture`).
	@param category string
	@param id string
	@return boolean
]=]
function CustomizationCosmeticRegistry.isSurfaceId(category: string, id: string): boolean
	local ids = SURFACE_CATALOG[category]
	return ids ~= nil and ids[id] == true
end

--[=[
	Every body-color channel descriptor, in declaration order.
	@return { BodyChannel }
]=]
function CustomizationCosmeticRegistry.bodyChannels(): { BodyChannel }
	return BODY_CHANNELS
end

--[=[
	The body-color channel for `key`, or nil if there is no such channel.
	@param key string
	@return BodyChannel?
]=]
function CustomizationCosmeticRegistry.bodyChannel(key: string): BodyChannel?
	return BODY_CHANNEL_BY_KEY[key]
end

return CustomizationCosmeticRegistry
