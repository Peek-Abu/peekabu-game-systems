--!strict
--[=[
	CustomizationSliceRules: the PURE data-layer invariants for the customization slices.

	`validateAppearance` and `validateEntitlements` are registered as the per-slice validators
	(customization design spec, Decision 11), so they hold for ANY write path into the slice —
	a service method, an admin command, or a raw `transaction()` op none of them anticipated.

	Deliberately does NOT check OWNERSHIP. A per-slice validator receives only its own slice's value,
	so the per-slot `appearance` cannot see the account-wide `entitlements`; "is this lockable cosmetic
	unlocked" is enforced at the equip METHOD instead. Same split Inventory already uses: SHAPE in the
	validator, POLICY in the service.

	Everything here is driven by the CustomizationCosmeticRegistry descriptor rows (Decision 10) — adding a cosmetic
	category or a body-color channel needs no edit in this module.

	Parameters are TYPED (not `unknown`) and still runtime-guarded, matching validateBank /
	validateInventory: the data layer's PathValidator contract hands over a raw persisted value, so the
	annotation describes the expected shape while the `type(...)` checks are what actually defend
	against malformed data. `Color` is a TAGGED union, so narrowing on `source` needs no cast.

	@class CustomizationSliceRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomizationShared = ReplicatedStorage.Shared.Features.Customization
local CustomizationCosmeticRegistry = require(CustomizationShared.Data.CustomizationCosmeticRegistry)
local CustomizationWearRules = require(CustomizationShared.Rules.CustomizationWearRules)
local CustomizationSoulColorRegistry = require(CustomizationShared.Data.CustomizationSoulColorRegistry)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

-- The generic accessory slots live in `appearance.accessories`, never in the single-selection
-- `appearance.cosmetics` map — listing "accessory" there would give a player an extra, unslotted one.
local ACCESSORY_CATEGORY = "accessory"

local CustomizationSliceRules = {}

-- One RGB component: an integer in [0, 255] (the single convention — see PlayerDataTypes.Color).
local function rgbComponentOk(value: number): boolean
	return type(value) == "number" and value == math.floor(value) and value >= 0 and value <= 255
end

--[[
	Length of a table that MUST be a dense array (keys 1..n, no holes), or nil + a reason.

	Deliberately NOT the `#` operator: `#` is undefined on a sparse table, so a raw op writing
	`{ [1] = a, [5] = b }` could report a length of 1 and slip straight past a capacity check — while
	generalized iteration still validates and PERSISTS every entry. That is precisely the bypass a
	slice invariant exists to prevent, so density is enforced here rather than assumed.

	Counts integer keys and compares the highest against the count: for a dense 1..n sequence those
	are equal, and any hole makes maxIndex exceed count. No indexing, so nothing depends on `#`.
]]
local function sequenceLength<T>(value: { T }, label: string): (number?, string?)
	local count = 0
	local maxIndex = 0
	for key in value do
		if type(key) ~= "number" or key ~= math.floor(key) or key < 1 then
			return nil, `{label} has a non-sequential key {tostring(key)}`
		end
		count += 1
		if key > maxIndex then
			maxIndex = key
		end
	end
	if maxIndex ~= count then
		return nil, `{label} is a sparse array ({count} entries but highest index {maxIndex})`
	end
	return count
end

-- Validates one Color of the tagged union. `allowFreeRgb` is the channel's policy (Decision 7): a
-- palette-only channel refuses a free triple even though the shape is otherwise well-formed.
local function validateColor(color: PlayerDataTypes.Color, label: string, allowFreeRgb: boolean): (boolean, string?)
	if type(color) ~= "table" then
		return false, `{label} must be a table, got {type(color)}`
	end
	if color.source == "dye" then
		if type(color.id) ~= "string" or color.id == "" then
			return false, `{label} dye id must be a non-empty string`
		end
		if not CustomizationCosmeticRegistry.isDyeRegistered(color.id) then
			return false, `{label} references unregistered dye "{color.id}"`
		end
		return true
	end
	if color.source == "rgb" then
		if not allowFreeRgb then
			return false, `{label} does not permit a free rgb value (palette dyes only)`
		end
		if not rgbComponentOk(color.r) then
			return false, `{label}.r must be an integer in [0, 255], got {tostring(color.r)}`
		end
		if not rgbComponentOk(color.g) then
			return false, `{label}.g must be an integer in [0, 255], got {tostring(color.g)}`
		end
		if not rgbComponentOk(color.b) then
			return false, `{label}.b must be an integer in [0, 255], got {tostring(color.b)}`
		end
		return true
	end
	return false, `{label} has unknown color source {tostring(color.source)}`
end

-- Validates one chosen cosmetic against its registry entry: the id must be registered in `category`,
-- carry no more colors than that cosmetic declares channels for, and be wearable with the appearance's
-- head type. That last check is CROSS-FIELD and only possible here because `cosmetics` and `headType`
-- live in the SAME slice — the ownership gate, needing the account slice, cannot be enforced this way.
local function validateSelection(
	selection: PlayerDataTypes.CosmeticSelection,
	category: string,
	label: string,
	headType: string
): (boolean, string?)
	if type(selection) ~= "table" then
		return false, `{label} must be a table, got {type(selection)}`
	end
	if type(selection.id) ~= "string" or selection.id == "" then
		return false, `{label}.id must be a non-empty string`
	end
	-- A RETIRED id is tolerated, matching the lenient-on-retired-keys rule affixes already follow.
	--
	-- This validator runs against the WHOLE resulting appearance on every write, so rejecting here does
	-- not merely refuse the bad id — it freezes the entire slice. A player holding a since-retired hat
	-- could not change their head type, their colours, or anything else until that hat was cleared,
	-- which is a live-ops trap the moment anything is ever retired.
	--
	-- Nothing is lost by allowing it: services pre-check registration on equip, so a retired id cannot
	-- be newly CHOSEN, and the plan-builder already skips retired ids so the character still renders.
	-- Entitlements stay strict by contrast — a retired id there is dead weight, not a rendering concern.
	-- STRUCTURE is checked before the registry, and for retired ids too. A malformed `colors` is
	-- corruption whatever the id says, and letting it through would hand callers a value they are
	-- entitled to treat as a table — `customizationsetcosmeticcolor` does exactly that.
	if type(selection.colors) ~= "table" then
		return false, `{label}.colors must be a table, got {type(selection.colors)}`
	end
	local entry = CustomizationCosmeticRegistry.get(category, selection.id)
	if not entry then
		-- Only the REGISTRY-derived checks are skipped: how many colour channels the cosmetic has, and
		-- which head types it allows, are unanswerable once its entry is gone.
		return true
	end
	-- AT MOST, not exactly: supplying fewer colors than the cosmetic has channels means "leave the
	-- remaining channels at the model's authored colors", which is what equipping without picking a
	-- color should do. More colors than channels is still a real error (they would go nowhere).
	local colorCount, colorReason = sequenceLength(selection.colors, `{label}.colors`)
	if not colorCount then
		return false, colorReason
	end
	if colorCount > entry.colorChannels then
		return false, `{label} accepts at most {entry.colorChannels} color(s) for "{selection.id}", got {colorCount}`
	end
	for index, color in selection.colors do
		-- Cosmetic colors accept either a palette dye or a free value; the palette-only restriction is
		-- a BODY-channel policy, expressed on those descriptors.
		local ok, reason = validateColor(color, `{label}.colors[{index}]`, true)
		if not ok then
			return false, reason
		end
	end
	if not CustomizationWearRules.isCompatible(category, selection.id, headType) then
		return false, `{label} ("{selection.id}") cannot be worn with head type "{headType}"`
	end
	return true
end

--[=[
	The `appearance` (per-slot) slice invariant: every referenced cosmetic/dye/body channel is
	registered, every Color is well-formed and permitted on its channel, and the accessory slots are
	not overfilled. Ownership is NOT checked here (see the class doc).
	@param appearance PlayerDataTypes.Appearance -- the raw slice value
	@return boolean -- ok
	@return string? -- reason on failure
]=]
function CustomizationSliceRules.validateAppearance(appearance: PlayerDataTypes.Appearance): (boolean, string?)
	if type(appearance) ~= "table" then
		return false, `appearance must be a table, got {type(appearance)}`
	end
	if type(appearance.cosmetics) ~= "table" then
		return false, `appearance.cosmetics must be a table, got {type(appearance.cosmetics)}`
	end
	if type(appearance.accessories) ~= "table" then
		return false, `appearance.accessories must be a table, got {type(appearance.accessories)}`
	end
	if type(appearance.body) ~= "table" then
		return false, `appearance.body must be a table, got {type(appearance.body)}`
	end
	-- REQUIRED (not absent-means-none like every other channel): a character always has a head, so an
	-- absent value would leave the facemask parts in an undefined state.
	if not CustomizationCosmeticRegistry.isHeadType(appearance.headType) then
		return false, `appearance.headType must be a registered head type, got {tostring(appearance.headType)}`
	end

	for category, selection in appearance.cosmetics do
		if type(category) ~= "string" then
			return false, `appearance.cosmetics has a non-string category key {tostring(category)}`
		end
		if category == ACCESSORY_CATEGORY then
			return false, `appearance.cosmetics must not carry "{ACCESSORY_CATEGORY}" — use appearance.accessories`
		end
		local ok, reason =
			validateSelection(selection, category, `appearance.cosmetics.{category}`, appearance.headType)
		if not ok then
			return false, reason
		end
	end

	local accessoryCount, accessoryReason = sequenceLength(appearance.accessories, "appearance.accessories")
	if not accessoryCount then
		return false, accessoryReason
	end
	if accessoryCount > CustomizationCosmeticRegistry.ACCESSORY_SLOTS then
		return false,
			`appearance.accessories holds {accessoryCount} entries, exceeding the {CustomizationCosmeticRegistry.ACCESSORY_SLOTS} slots`
	end
	-- SOCKET OCCUPANCY: an equipped accessory RESERVES every socket it occupies, so no other accessory
	-- may use one. Two hats on `Head` would clip through each other, and a multi-socket cosmetic (the
	-- cowl is a hood on `Head` plus a mantle on `Chest`) has to exclude a separate chest piece.
	--
	-- Deliberately scoped to accessories ONLY. Eyelashes mount on `Eyes` and so do all ten glasses, and
	-- they are worn together today — a Roblox attachment hosts several accessories quite happily — so a
	-- blanket one-cosmetic-per-socket rule would outlaw a combination that already ships. If sockets
	-- ever turn out to differ in kind, the upgrade is a per-socket exclusivity flag in the registry,
	-- and it would replace exactly this loop.
	local claimedBy: { [string]: number } = {}
	for index, selection in appearance.accessories do
		local ok, reason =
			validateSelection(selection, ACCESSORY_CATEGORY, `appearance.accessories[{index}]`, appearance.headType)
		if not ok then
			return false, reason
		end
		if type(selection) == "table" and type(selection.id) == "string" then
			-- A retired id reports no sockets, so it reserves nothing — consistent with the leniency
			-- that keeps a retired cosmetic from freezing the slice.
			-- OCCUPIED sockets, not mount sockets: the cowl binds only at `Head` while its mantle covers
			-- the chest, so what it reserves is wider than where it mounts.
			for _, socket in CustomizationCosmeticRegistry.occupiedSocketsOf(ACCESSORY_CATEGORY, selection.id) do
				local holder = claimedBy[socket]
				if holder then
					return false,
						`appearance.accessories[{index}] ("{selection.id}") wants socket "{socket}", already taken by accessories[{holder}]`
				end
				claimedBy[socket] = index
			end
		end
	end

	-- Optional, unlike headType: a character may simply not have a soul colour yet.
	if appearance.soulColor ~= nil and not CustomizationSoulColorRegistry.isRegistered(appearance.soulColor) then
		return false, `appearance.soulColor "{tostring(appearance.soulColor)}" is not a registered soul colour`
	end
	if type(appearance.surfaces) ~= "table" then
		return false, `appearance.surfaces must be a table, got {type(appearance.surfaces)}`
	end
	for key, selection in appearance.surfaces do
		if type(key) ~= "string" then
			return false, `appearance.surfaces has a non-string channel key {tostring(key)}`
		end
		local channel = CustomizationCosmeticRegistry.surfaceChannel(key)
		if not channel then
			return false, `appearance.surfaces references unregistered surface channel "{key}"`
		end
		if type(selection) ~= "table" then
			return false, `appearance.surfaces.{key} must be a table, got {type(selection)}`
		end
		-- Either field may be absent on its own ("keep the rig's authored surface for that aspect"),
		-- but a present one must name a registered id from THIS channel's pattern catalog.
		if
			selection.pattern ~= nil
			and not CustomizationCosmeticRegistry.isSurfaceId(channel.patterns, selection.pattern)
		then
			return false, `appearance.surfaces.{key} references unregistered pattern "{selection.pattern}"`
		end
		if selection.texture ~= nil and not CustomizationCosmeticRegistry.isSurfaceId("texture", selection.texture) then
			return false, `appearance.surfaces.{key} references unregistered texture "{selection.texture}"`
		end
	end

	for key, color in appearance.body do
		if type(key) ~= "string" then
			return false, `appearance.body has a non-string channel key {tostring(key)}`
		end
		local channel = CustomizationCosmeticRegistry.bodyChannel(key)
		if not channel then
			return false, `appearance.body references unregistered body channel "{key}"`
		end
		local ok, reason = validateColor(color, `appearance.body.{key}`, channel.allowFreeRgb)
		if not ok then
			return false, reason
		end
	end

	return true
end

--[=[
	The `entitlements` (account-wide) slice invariant: every stored id is registered AND actually
	lockable. Storing a free id is rejected rather than tolerated — a free cosmetic needs no entitlement
	row, so its presence means something built the slice wrongly, and silently keeping it would grow the
	slice without bound as the catalog changes.
	@param entitlements PlayerDataTypes.Entitlements -- the raw slice value
	@return boolean -- ok
	@return string? -- reason on failure
]=]
function CustomizationSliceRules.validateEntitlements(entitlements: PlayerDataTypes.Entitlements): (boolean, string?)
	if type(entitlements) ~= "table" then
		return false, `entitlements must be a table, got {type(entitlements)}`
	end
	if type(entitlements.cosmetics) ~= "table" then
		return false, `entitlements.cosmetics must be a table, got {type(entitlements.cosmetics)}`
	end
	for category, owned in entitlements.cosmetics do
		if type(category) ~= "string" then
			return false, `entitlements.cosmetics has a non-string category key {tostring(category)}`
		end
		if type(owned) ~= "table" then
			return false, `entitlements.cosmetics.{category} must be a table, got {type(owned)}`
		end
		for id, flag in owned do
			if type(id) ~= "string" or id == "" then
				return false, `entitlements.cosmetics.{category} has a non-string id {tostring(id)}`
			end
			if flag ~= true then
				return false, `entitlements.cosmetics.{category}."{id}" must be stored as true`
			end
			if not CustomizationCosmeticRegistry.isRegistered(category, id) then
				return false, `entitlements.cosmetics.{category} references unregistered cosmetic "{id}"`
			end
			if not CustomizationCosmeticRegistry.isLockable(category, id) then
				return false, `entitlements.cosmetics.{category}."{id}" is free — free ids are never stored`
			end
		end
	end

	return true
end

return CustomizationSliceRules
