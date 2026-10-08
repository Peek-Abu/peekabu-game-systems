--!strict
--[=[
	CustomizationRigOutfitTracker: what ONE rig wears, as a record that always matches the rig (R4 spec, Section 1).

	- `worn` is the CustomizationOutfitDiffUtils outfit the rig was last dressed to, and `mounted` holds the cosmetic
	  pieces actually parented to it, by mount key. Both live as long as the rig does, INCLUDING while a
	  puppet sits in the pool: a returning owner diffs to nothing, and a new owner's diff takes the old
	  look off. Nothing else may mount or remove cosmetics on the rig, or the record stops being true.
	- `version` is the appearance version the record reflects, for `ownerUserId`. `UNDRESSED` (-1) means
	  "not dressed for this owner yet": the rig is parked until a dress lands (the dressed rule).
	- The part and socket indexes are built once, on creation, from the rig's own parts (never
	  anything inside a mounted Accessory), replacing the old per-entry `GetDescendants` scans.

	@class CustomizationRigOutfitTracker
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomizationOutfitDiffUtils =
	require(ReplicatedStorage.Client.Features.Customization.Utils.CustomizationOutfitDiffUtils)

--[=[
	The pieces one mount put on the rig. `id` is what was actually mounted: the requested id, or its
	fallback when the requested art was broken.
	@interface Mounted
	.id string
	.pieces { Accessory }
]=]
export type Mounted = {
	id: string,
	pieces: { Accessory },
}

export type CustomizationRigOutfitTracker = {
	rig: Model,
	ownerUserId: number,
	version: number,
	worn: CustomizationOutfitDiffUtils.Outfit,
	mounted: { [string]: Mounted },
	-- Why each mount key is not wearing what it asked for (F4); empty when everything bound.
	failures: { [string]: string },
	_parts: { BasePart },
	_sockets: { [string]: Attachment },
	_partsByName: { [string]: { BasePart } },
}

local CustomizationRigOutfitTracker = {}

CustomizationRigOutfitTracker.UNDRESSED = -1

local function inAccessory(instance: Instance): boolean
	return instance:FindFirstAncestorOfClass("Accessory") ~= nil
end

--[=[
	Indexes a rig. The rig must not wear any cosmetics yet (a fresh clone).
	@param rig Model
	@return CustomizationRigOutfitTracker
]=]
function CustomizationRigOutfitTracker.new(rig: Model): CustomizationRigOutfitTracker
	local parts: { BasePart } = {}
	local sockets: { [string]: Attachment } = {}
	for _, descendant in rig:GetDescendants() do
		if inAccessory(descendant) then
			continue
		end
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		elseif descendant:IsA("Attachment") then
			local existing: Attachment? = sockets[descendant.Name]
			if existing == nil then
				sockets[descendant.Name] = descendant
			end
		end
	end
	return {
		rig = rig,
		ownerUserId = 0,
		version = CustomizationRigOutfitTracker.UNDRESSED,
		worn = CustomizationOutfitDiffUtils.empty(),
		mounted = {},
		failures = {},
		_parts = parts,
		_sockets = sockets,
		_partsByName = {},
	}
end

--[=[
	Every rig part a channel names: an exact name match, or a `<name>-<suffix>` variant (the art splits
	one channel across `Skin Color`, `Skin Color-Uncovered`, …). Cached per name.
	@param outfit CustomizationRigOutfitTracker
	@param name string
	@return { BasePart }
]=]
function CustomizationRigOutfitTracker.partsFor(outfit: CustomizationRigOutfitTracker, name: string): { BasePart }
	local cached = outfit._partsByName[name]
	if cached ~= nil then
		return cached
	end
	local prefix = name .. "-"
	local found: { BasePart } = {}
	for _, part in outfit._parts do
		if part.Name == name or part.Name:sub(1, #prefix) == prefix then
			table.insert(found, part)
		end
	end
	outfit._partsByName[name] = found
	return found
end

--[=[
	The rig's own Attachment named `socket` (first found, at any depth), or nil.
	@param outfit CustomizationRigOutfitTracker
	@param socket string
	@return Attachment?
]=]
function CustomizationRigOutfitTracker.socket(outfit: CustomizationRigOutfitTracker, socket: string): Attachment?
	return outfit._sockets[socket]
end

--[=[
	Hands the rig to an owner. A different owner makes it UNDRESSED (its worn record stays: that is what
	the next diff takes off); the same owner keeps its version, so a returning owner needs no redress.
	@param outfit CustomizationRigOutfitTracker
	@param ownerUserId number
]=]
function CustomizationRigOutfitTracker.assign(outfit: CustomizationRigOutfitTracker, ownerUserId: number)
	if outfit.ownerUserId ~= ownerUserId then
		outfit.ownerUserId = ownerUserId
		outfit.version = CustomizationRigOutfitTracker.UNDRESSED
	end
end

--[=[
	True once the rig is dressed for its current owner.
	@param outfit CustomizationRigOutfitTracker
	@return boolean
]=]
function CustomizationRigOutfitTracker.isDressed(outfit: CustomizationRigOutfitTracker): boolean
	return outfit.version ~= CustomizationRigOutfitTracker.UNDRESSED
end

--[=[
	Records that the rig now wears `worn`, at `version`. Called after the diff is applied.
	@param outfit CustomizationRigOutfitTracker
	@param worn CustomizationOutfitDiffUtils.Outfit
	@param version number
]=]
function CustomizationRigOutfitTracker.setWorn(
	outfit: CustomizationRigOutfitTracker,
	worn: CustomizationOutfitDiffUtils.Outfit,
	version: number
)
	outfit.worn = worn
	outfit.version = version
end

return CustomizationRigOutfitTracker
