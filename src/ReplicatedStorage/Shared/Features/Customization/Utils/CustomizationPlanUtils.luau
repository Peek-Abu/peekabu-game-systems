--!strict
--[=[
	CustomizationPlanUtils: the PURE resolver from a stored `Appearance` to a concrete application plan.

	This is the testable half of applying a look (customization design spec, Decision 5). It answers
	"WHAT should end up on the character" — which cosmetic mounts on which rig socket, and which
	concrete RGB lands on which rig part-name — with no Instance access at all. The Instance-mutation
	half (clone, weld, recolor) consumes this plan and is the small, spec-exempt shell.

	It lives in Shared, not on the server, deliberately (Decision 9): the client customization UI runs
	the SAME resolver to render a live local preview while the player is still editing, with no server
	round-trip per tweak.

	TOLERANT by design, matching the disable-don't-delete rule affixes already follow: an id that has
	since been retired from the registry (or a dye/channel that no longer exists) is SKIPPED, not an
	error. The data-layer validator is what refuses bad NEW writes; this resolver must keep rendering
	whatever is already persisted.

	DETERMINISTIC: body colors are emitted in CustomizationCosmeticRegistry declaration order and cosmetic
	categories in sorted order, never raw map-iteration order (which Lua does not guarantee) — so the
	plan is stable across calls and comparable in tests.

	@class CustomizationPlanUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomizationCosmeticRegistry =
	require(ReplicatedStorage.Shared.Features.Customization.Data.CustomizationCosmeticRegistry)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

--[=[
	A concrete color, already resolved from the stored Color union (palette dye looked up, free rgb
	passed through). 0..255 integers.
	@interface Rgb
	.r number
	.g number
	.b number
]=]
export type Rgb = {
	r: number,
	g: number,
	b: number,
}

--[=[
	One cosmetic to clone + weld onto the character.
	@interface Mount
	.category string -- the CustomizationCosmeticRegistry category the id came from
	.id string -- the cosmetic id
	.sockets { string } -- every rig Attachment name this cosmetic occupies, in declaration order.
		-- Usually one; shoes are a Model of two Accessories (ShoeLeft/ShoeRight), and the art's
		-- two-tone accessories are a second piece on a different socket, so a LIST is the general case
		-- and a single socket is just the common one.
	.colors { [number]: Rgb } -- resolved colors KEYED BY CHANNEL INDEX; a channel whose color no
		-- longer resolves is absent rather than shifting the others down
	.offset CFrame? -- fit adjustment at the socket; absent = the cosmetic's own authored placement
]=]
export type Mount = {
	category: string,
	id: string,
	sockets: { string },
	colors: { [number]: Rgb },
	offset: CFrame?,
}

--[=[
	One body-color assignment: every rig BasePart named `part` takes `color`.
	@interface BodyColor
	.part string
	.color Rgb
]=]
export type BodyColor = {
	part: string,
	color: Rgb,
}

--[=[
	One head part's visibility under the selected head type. `part` may name a SUBTREE (the shell
	applies visibility recursively).
	@interface HeadPart
	.part string
	.visible boolean
]=]
export type HeadPart = {
	part: string,
	visible: boolean,
}

--[=[
	The full plan handed to the Instance-mutation shell.
	@interface ApplicationPlan
	.mounts { Mount }
	.bodyColors { BodyColor }
	.headParts { HeadPart }
]=]
--[=[
	One surface restyle: every rig part named `part` takes this pattern and/or texture. Either may be
	nil, meaning "restore that aspect to what the rig authored" — a directive is emitted for every
	registered channel, so nil is an instruction to reset, never an absence of one.
	@interface Surface
	.part string
	.artFolder string -- the art folder `pattern` is cloned from (per-channel, not per-category)
	.pattern string?
	.texture string?
]=]
export type Surface = {
	part: string,
	artFolder: string,
	pattern: string?,
	texture: string?,
}

export type ApplicationPlan = {
	mounts: { Mount },
	bodyColors: { BodyColor },
	headParts: { HeadPart },
	surfaces: { Surface },
}

local CustomizationPlanUtils = {}

-- Resolves a stored Color to a concrete Rgb, or nil when it cannot be resolved (a retired dye id).
-- The union is TAGGED, so narrowing on `source` needs no cast.
local function resolveColor(color: PlayerDataTypes.Color): Rgb?
	if type(color) ~= "table" then
		return nil
	end
	if color.source == "dye" then
		local dye = CustomizationCosmeticRegistry.dye(color.id)
		if not dye then
			return nil
		end
		return { r = dye.color.r, g = dye.color.g, b = dye.color.b }
	end
	if color.source == "rgb" then
		return { r = color.r, g = color.g, b = color.b }
	end
	return nil
end

-- Resolves a selection's colors, KEYED BY CHANNEL INDEX. An unresolvable color (a retired dye) leaves
-- its channel absent rather than compacting the rest down: the application shell maps index N onto the
-- part named "Color N", so `table.insert`-style dropping would silently paint channel 2's color onto
-- channel 1. Numeric iteration (not generalized) so channel order is expressed, not assumed — the
-- validator guarantees a dense input, so `#colors` is well-defined here.
local function resolveColors(colors: { PlayerDataTypes.Color }): { [number]: Rgb }
	local resolved: { [number]: Rgb } = {}
	for index = 1, #colors do
		local rgb = resolveColor(colors[index])
		if rgb then
			resolved[index] = rgb
		end
	end
	return resolved
end

--[=[
	Composes a registry Offset into a CFrame, or nil when there is no offset at all.

	Rotation is applied at the origin and then translated, so the two halves stay independent: nudging
	a cosmetic sideways cannot quietly change the angle a previous tuning pass settled on. Degrees in
	the catalog because that is what a human tuning a fit thinks in.
	@param offset CustomizationCosmeticRegistry.Offset?
	@return CFrame?
]=]
function CustomizationPlanUtils.composeOffset(offset: CustomizationCosmeticRegistry.Offset?): CFrame?
	if offset == nil then
		return nil
	end
	local rotation = CFrame.Angles(math.rad(offset.rx or 0), math.rad(offset.ry or 0), math.rad(offset.rz or 0))
	return CFrame.new(offset.x or 0, offset.y or 0, offset.z or 0) * rotation
end

-- Builds one Mount if the cosmetic is still registered; nil for a retired id (skipped, not an error).
local function buildMount(category: string, selection: PlayerDataTypes.CosmeticSelection): Mount?
	if type(selection) ~= "table" or type(selection.id) ~= "string" then
		return nil
	end
	local entry = CustomizationCosmeticRegistry.get(category, selection.id)
	if not entry then
		return nil
	end
	return {
		category = category,
		id = selection.id,
		sockets = CustomizationCosmeticRegistry.socketsOf(category, selection.id),
		colors = resolveColors(selection.colors),
		offset = CustomizationPlanUtils.composeOffset(entry.offset),
	}
end

--[=[
	Resolves a stored appearance into the concrete plan the application shell applies.

	Mount order: the single-selection categories first (sorted by category name for determinism), then
	the generic accessory slots in slot order. Body colors follow CustomizationCosmeticRegistry declaration order.
	@param appearance PlayerDataTypes.Appearance -- the stored slice value
	@return ApplicationPlan
]=]
function CustomizationPlanUtils.build(appearance: PlayerDataTypes.Appearance): ApplicationPlan
	local plan: ApplicationPlan = { mounts = {}, bodyColors = {}, headParts = {}, surfaces = {} }
	if type(appearance) ~= "table" then
		return plan
	end

	-- Head type: resolve the mode's show/hide sets into flat directives, shown-then-hidden in declared
	-- order so the output is deterministic. An unregistered mode emits NOTHING rather than erroring —
	-- the same tolerance retired cosmetic ids get; the validator is what refuses bad new writes.
	local headTypeDef = CustomizationCosmeticRegistry.headTypeDef(appearance.headType)
	if headTypeDef then
		for _, part in ipairs(headTypeDef.show) do
			table.insert(plan.headParts, { part = part, visible = true })
		end
		for _, part in ipairs(headTypeDef.hide) do
			table.insert(plan.headParts, { part = part, visible = false })
		end
	end

	-- Single-selection cosmetics (hair/eyebrows/eyelashes), sorted so the plan is deterministic.
	if type(appearance.cosmetics) == "table" then
		local categories: { string } = {}
		for category in appearance.cosmetics do
			table.insert(categories, category)
		end
		table.sort(categories)
		for _, category in categories do
			local mount = buildMount(category, appearance.cosmetics[category])
			if mount then
				table.insert(plan.mounts, mount)
			end
		end
	end

	-- Generic accessory slots, in slot order. `ipairs` (not generalized iteration) so the ORDERING is
	-- expressed in code rather than assumed: generalized iteration over a table has no guaranteed
	-- order, which would quietly break this module's determinism contract. The validator guarantees a
	-- dense sequence, so stopping at the first gap cannot skip a valid entry.
	if type(appearance.accessories) == "table" then
		for _, selection in ipairs(appearance.accessories) do
			local mount = buildMount("accessory", selection)
			if mount then
				table.insert(plan.mounts, mount)
			end
		end
	end

	-- Surfaces, in registry declaration order. EVERY registered channel is emitted, including ones the
	-- player has not set: the plan is a COMPLETE description of the surface state, not a diff. A
	-- directive with both aspects nil means "restore what the rig authored", which is what makes
	-- clearing a channel take effect immediately instead of surviving until the next respawn.
	local storedSurfaces = if type(appearance.surfaces) == "table" then appearance.surfaces else {}
	for _, channel in ipairs(CustomizationCosmeticRegistry.surfaceChannels()) do
		local selection = storedSurfaces[channel.key]
		local hasSelection = type(selection) == "table"
		table.insert(plan.surfaces, {
			part = channel.part,
			artFolder = channel.artFolder,
			pattern = if hasSelection then selection.pattern else nil,
			texture = if hasSelection then selection.texture else nil,
		})
	end

	-- Body colors, driven by the registry's channel descriptors (Decision 10) rather than by iterating
	-- the stored map — which also makes the emitted order deterministic and drops retired channels.
	if type(appearance.body) == "table" then
		-- `ipairs`, like the accessory loop above: the emitted order IS the registry's declaration
		-- order, and generalized iteration would leave that guarantee to chance.
		for _, channel in ipairs(CustomizationCosmeticRegistry.bodyChannels()) do
			local stored = appearance.body[channel.key]
			if stored ~= nil then
				local rgb = resolveColor(stored)
				if rgb then
					table.insert(plan.bodyColors, { part = channel.part, color = rgb })
				end
			end
		end
	end

	return plan
end

return CustomizationPlanUtils
