--!strict
--[=[
	CustomizationOutfitDiffUtils: the PURE half of dressing a rig (R4 spec, "Section 2 — diff application rules").

	Two steps, both without Instance access:
	- `target(appearance)` resolves a stored Appearance (through CustomizationPlanUtils) into an `Outfit`: the
	  complete look a rig should wear, keyed so two outfits can be compared slot by slot.
	- `compute(worn, target)` lists the operations that turn what a rig wears into the target, and
	  nothing else. Equal outfits give an empty list.

	An `Outfit` is ALSO the worn record: after a diff is applied, the rig's record becomes the target it
	was diffed against (CustomizationRigOutfitTracker.setWorn). So the record always describes the rig, including what a
	pooled rig still wears from its last owner — which is what lets a reused rig take off the old look
	instead of dressing on top of it.

	Absent means "the rig's authored look": a body colour, head part or surface the target does not set
	is emitted with a nil value when the rig currently has one, and the application restores what the
	rig was built with. That is what keeps a reused rig from showing its last owner's colours.

	Mount keys: the category for single-selection cosmetics, `accessory:N` for the Nth accessory. A
	mount whose id differs, or whose fit offset or fallback differs, is removed and added again; one
	whose only change is colours is recoloured in place.

	TOLERANT like CustomizationPlanUtils: retired ids and dyes are already dropped by the plan, so they never
	reach the diff.

	@class CustomizationOutfitDiffUtils
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomizationCosmeticRegistry =
	require(ReplicatedStorage.Shared.Features.Customization.Data.CustomizationCosmeticRegistry)
local CustomizationPlanUtils = require(ReplicatedStorage.Shared.Features.Customization.Utils.CustomizationPlanUtils)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

export type Rgb = CustomizationPlanUtils.Rgb

--[=[
	One mounted cosmetic in an outfit.
	@interface Mount
	.category string
	.id string
	.fallbackId string? -- the category's default for the head type, mounted if `id`'s art is broken
	.colors { [number]: Rgb } -- by channel index; an absent channel keeps the art's authored colour
	.offset CFrame? -- composed fit offset; nil = the art's authored placement
]=]
export type Mount = {
	category: string,
	id: string,
	fallbackId: string?,
	colors: { [number]: Rgb },
	offset: CFrame?,
}

--[=[
	One surface channel's restyle. Both aspects nil = the rig's authored surface.
	@interface Surface
	.part string
	.artFolder string
	.pattern string?
	.texture string?
]=]
export type Surface = {
	part: string,
	artFolder: string,
	pattern: string?,
	texture: string?,
}

--[=[
	A complete look, and the record of what a rig wears.
	@interface Outfit
	.mounts { [string]: Mount } -- by mount key
	.mountOrder { string } -- mount keys in plan order (adds are emitted in this order)
	.bodyColors { [string]: Rgb } -- by rig part name; absent = authored
	.surfaces { [string]: Surface } -- by surface channel key; absent = authored
	.headParts { [string]: boolean } -- by head part name; absent = authored
]=]
export type Outfit = {
	mounts: { [string]: Mount },
	mountOrder: { string },
	bodyColors: { [string]: Rgb },
	surfaces: { [string]: Surface },
	headParts: { [string]: boolean },
}

--[=[
	One change to apply. Nil values mean "restore the rig's authored state".
	@type DiffOp
]=]
export type DiffOp =
	{ kind: "removeCosmetic", mountKey: string }
	| { kind: "addCosmetic", mountKey: string, mount: Mount }
	| { kind: "recolourCosmetic", mountKey: string, colors: { [number]: Rgb } }
	| { kind: "setBodyColour", part: string, color: Rgb? }
	| { kind: "setSurface", channelKey: string, surface: Surface }
	| { kind: "setHeadPart", part: string, visible: boolean? }

local CustomizationOutfitDiffUtils = {}

local function rgbEqual(a: Rgb?, b: Rgb?): boolean
	if a == nil or b == nil then
		return a == b
	end
	return a.r == b.r and a.g == b.g and a.b == b.b
end

local function colorsEqual(a: { [number]: Rgb }, b: { [number]: Rgb }): boolean
	for channel, color in a do
		if not rgbEqual(color, b[channel]) then
			return false
		end
	end
	for channel in b do
		if a[channel] == nil then
			return false
		end
	end
	return true
end

-- CFrame `==` compares components exactly, which is what is wanted: both sides come from the same
-- registry value through the same composeOffset.
local function offsetEqual(a: CFrame?, b: CFrame?): boolean
	return a == b
end

local function surfaceEqual(a: Surface?, b: Surface?): boolean
	if a == nil or b == nil then
		return a == b
	end
	return a.part == b.part and a.artFolder == b.artFolder and a.pattern == b.pattern and a.texture == b.texture
end

local function sortedKeys<V>(map: { [string]: V }): { string }
	local keys: { string } = {}
	for key in map do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

--[=[
	An outfit that wears nothing: a freshly built rig's record.
	@return Outfit
]=]
function CustomizationOutfitDiffUtils.empty(): Outfit
	return { mounts = {}, mountOrder = {}, bodyColors = {}, surfaces = {}, headParts = {} }
end

--[=[
	Resolves a stored appearance into the outfit a rig should wear.
	@param appearance PlayerDataTypes.Appearance
	@return Outfit
]=]
function CustomizationOutfitDiffUtils.target(appearance: PlayerDataTypes.Appearance): Outfit
	local outfit = CustomizationOutfitDiffUtils.empty()
	local plan = CustomizationPlanUtils.build(appearance)
	local headType = if type(appearance) == "table" and type(appearance.headType) == "string"
		then appearance.headType
		else CustomizationCosmeticRegistry.DEFAULT_HEAD_TYPE

	local accessoryIndex = 0
	for _, mount in plan.mounts do
		local mountKey: string
		local fallbackId: string? = nil
		if mount.category == "accessory" then
			accessoryIndex += 1
			mountKey = `accessory:{accessoryIndex}`
		else
			mountKey = mount.category
			local default = CustomizationCosmeticRegistry.defaultCosmetic(mount.category, headType)
			if default ~= nil and default ~= mount.id then
				fallbackId = default
			end
		end
		outfit.mounts[mountKey] = {
			category = mount.category,
			id = mount.id,
			fallbackId = fallbackId,
			colors = mount.colors,
			offset = mount.offset,
		}
		table.insert(outfit.mountOrder, mountKey)
	end

	for _, bodyColor in plan.bodyColors do
		outfit.bodyColors[bodyColor.part] = bodyColor.color
	end

	-- CustomizationPlanUtils emits one surface per registered channel, in `surfaceChannels()` order, so the
	-- two lists line up by index; the part/artFolder check keeps that a checked fact, not an assumption.
	local channels = CustomizationCosmeticRegistry.surfaceChannels()
	for index, surface in plan.surfaces do
		local channel = channels[index]
		if channel ~= nil and channel.part == surface.part and channel.artFolder == surface.artFolder then
			if surface.pattern ~= nil or surface.texture ~= nil then
				outfit.surfaces[channel.key] = {
					part = surface.part,
					artFolder = surface.artFolder,
					pattern = surface.pattern,
					texture = surface.texture,
				}
			end
		end
	end

	for _, headPart in plan.headParts do
		outfit.headParts[headPart.part] = headPart.visible
	end

	return outfit
end

local function mountReplaced(worn: Mount, target: Mount): boolean
	return worn.category ~= target.category
		or worn.id ~= target.id
		or worn.fallbackId ~= target.fallbackId
		or not offsetEqual(worn.offset, target.offset)
end

--[=[
	The operations that turn `worn` into `target`, in a fixed order: removals, then adds and recolours
	(target mount order), body colours (registry order), surfaces (registry order), head parts (sorted).
	@param worn Outfit -- what the rig wears now
	@param target Outfit -- what it should wear
	@return { DiffOp }
]=]
function CustomizationOutfitDiffUtils.compute(worn: Outfit, target: Outfit): { DiffOp }
	local ops: { DiffOp } = {}

	-- Removals first, sorted: a mount gone from the target, or one being replaced.
	for _, mountKey in sortedKeys(worn.mounts) do
		local targetMount = target.mounts[mountKey]
		if targetMount == nil or mountReplaced(worn.mounts[mountKey], targetMount) then
			table.insert(ops, { kind = "removeCosmetic", mountKey = mountKey })
		end
	end

	for _, mountKey in target.mountOrder do
		local targetMount = target.mounts[mountKey]
		local wornMount = worn.mounts[mountKey]
		if wornMount == nil or mountReplaced(wornMount, targetMount) then
			table.insert(ops, { kind = "addCosmetic", mountKey = mountKey, mount = targetMount })
		elseif not colorsEqual(wornMount.colors, targetMount.colors) then
			table.insert(ops, { kind = "recolourCosmetic", mountKey = mountKey, colors = targetMount.colors })
		end
	end

	for _, channel in CustomizationCosmeticRegistry.bodyChannels() do
		local targetColor = target.bodyColors[channel.part]
		if not rgbEqual(worn.bodyColors[channel.part], targetColor) then
			table.insert(ops, { kind = "setBodyColour", part = channel.part, color = targetColor })
		end
	end

	for _, channel in CustomizationCosmeticRegistry.surfaceChannels() do
		local targetSurface = target.surfaces[channel.key]
		if not surfaceEqual(worn.surfaces[channel.key], targetSurface) then
			table.insert(ops, {
				kind = "setSurface",
				channelKey = channel.key,
				surface = targetSurface or { part = channel.part, artFolder = channel.artFolder },
			})
		end
	end

	local headParts: { [string]: boolean } = {}
	for part in worn.headParts do
		headParts[part] = true
	end
	for part in target.headParts do
		headParts[part] = true
	end
	for _, part in sortedKeys(headParts) do
		local visible = target.headParts[part]
		if worn.headParts[part] ~= visible then
			table.insert(ops, { kind = "setHeadPart", part = part, visible = visible })
		end
	end

	return ops
end

return CustomizationOutfitDiffUtils
