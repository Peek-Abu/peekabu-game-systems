--!strict
--[=[
	CargoSpawnSystem: puts graybox cargo in the world. One anchored Part per item, sized and coloured from
	CargoRegistry, carrying its CarryKind / CargoId / CargoValue / CargoImpacts attributes and an empty price tag
	shell (its display data as attributes, tagged CargoPriceTag; the client draws it), then tagged Carryable so Carry (and through it Interaction's "Pick up" prompt) takes over. A hidden
	item (under a pile) is invisible, lets players through, is skipped by raycasts and has its prompt off
	until `reveal`.

	A grimy kind (a valuable) also carries its appraisal (CargoBaseValue / CargoClean / CargoAppraised / CargoVariant,
	docs/superpowers/specs/2026-10-15-cleanup-crew-loot-loop-design.md §3.2): its CargoValue always follows
	CargoAppraisalFormulas.value, and while it is not spotless it is a vacuum target (VacuumConstants.GRIME_TAG and its
	size's grime channel kind). `setClean` and `appraise` move that state on; `reprice` re-reads it after an impact.
	`seal` locks a dirty valuable's grime (its first pick-up: "clean it where you find it"): never a vacuum target again,
	and `setClean` refuses it.

	Instance specs cover catalog authority, kit selection, fallback, reveal lifecycle and grime.

	@class CargoSpawnSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local ArtVisualSystem = require(ServerScriptService.Features.Art.Systems.ArtVisualSystem)

local CargoShared = ReplicatedStorage.Shared.Features.Cargo
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local CargoConstants = require(CargoShared.Data.CargoConstants)
local CargoRegistry = require(CargoShared.Data.CargoRegistry)
local CargoTypes = require(CargoShared.Data.CargoTypes)
local CargoAppraisalFormulas = require(CargoShared.Utils.CargoAppraisalFormulas)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)

export type CargoSpawnSystem = {
	spawn: (
		self: CargoSpawnSystem,
		kind: string,
		floor: CFrame,
		parent: Instance,
		options: CargoTypes.SpawnOptions?
	) -> BasePart,
	reveal: (self: CargoSpawnSystem, item: Instance) -> (),
	reprice: (self: CargoSpawnSystem, item: Instance) -> (),
	setClean: (self: CargoSpawnSystem, item: Instance, clean: number, now: number) -> boolean,
	appraise: (self: CargoSpawnSystem, item: Instance, now: number) -> boolean,
	seal: (self: CargoSpawnSystem, item: Instance) -> boolean,
	floorUnder: (self: CargoSpawnSystem, position: Vector3, ignore: { Instance }) -> CFrame,
}

local function tagOf(item: Instance): BillboardGui?
	local shell = item:FindFirstChild(CargoConstants.LABEL_NAME)
	if shell == nil or not shell:IsA("BillboardGui") then
		return nil
	end
	return shell
end

-- The item's price tag shell (W5): empty and offset-sized at the tag's design size, the item's display data as
-- attributes (CargoConstants.LABEL_KEYS), tagged LABEL_TAG last; CargoBillboardSystem draws it on clients near it. Off
-- while the item is hidden under a pile.
local function makeTag(part: BasePart, def: CargoTypes.ItemDef, value: number, hidden: boolean, grimy: boolean)
	local keys = CargoConstants.LABEL_KEYS
	local shell = Instance.new("BillboardGui")
	shell.Name = CargoConstants.LABEL_NAME
	shell.Size = UDim2.fromOffset(CargoConstants.LABEL_PX.X, CargoConstants.LABEL_PX.Y)
	shell.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 1.5, 0)
	shell.MaxDistance = CargoConstants.LABEL_DISTANCE
	shell.LightInfluence = 0
	shell.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	shell.Enabled = not hidden
	shell:SetAttribute(keys.name, def.name)
	shell:SetAttribute(keys.category, def.category)
	shell:SetAttribute(keys.value, value)
	shell:SetAttribute(keys.fragile, def.fragile)
	shell:SetAttribute(keys.impacts, 0)
	shell:SetAttribute(keys.hidden, hidden)
	shell:SetAttribute(keys.grimy, grimy)
	CollectionService:AddTag(shell, CargoConstants.LABEL_TAG)
	shell.Parent = part
end

local function numberAttribute(item: Instance, name: string, fallback: number): number
	local value = item:GetAttribute(name)
	return if type(value) == "number" then value else fallback
end

-- An item's catalog entry when it is a grimy kind (a valuable), else nil.
local function grimyDef(item: Instance): CargoTypes.ItemDef?
	local kind = item:GetAttribute(CarryConstants.KIND_ATTRIBUTE)
	local def = if type(kind) == "string" then CargoRegistry.get(kind) else nil
	return if def ~= nil and def.grimy then def else nil
end

-- Re-reads an item's appraisal (a valuable), writes its value, and copies everything its price tag shows onto the tag.
local function price(item: Instance)
	local kind = item:GetAttribute(CarryConstants.KIND_ATTRIBUTE)
	local def = if type(kind) == "string" then CargoRegistry.get(kind) else nil
	if def == nil then
		return
	end
	local impacts = numberAttribute(item, CargoConstants.IMPACTS_ATTRIBUTE, 0)
	local value: number
	local name = def.name
	if def.grimy then
		local clean = numberAttribute(item, CargoConstants.CLEAN_ATTRIBUTE, 0)
		local appraised = item:GetAttribute(CargoConstants.APPRAISED_ATTRIBUTE) == true
		local variant = item:GetAttribute(CargoConstants.VARIANT_ATTRIBUTE)
		local base = numberAttribute(item, CargoConstants.BASE_VALUE_ATTRIBUTE, def.value)
		value = CargoAppraisalFormulas.value(def, base, impacts, clean)
		name = CargoAppraisalFormulas.displayName(def, if type(variant) == "string" then variant else nil, appraised)
	else
		value = numberAttribute(item, CargoConstants.VALUE_ATTRIBUTE, def.value)
	end
	item:SetAttribute(CargoConstants.VALUE_ATTRIBUTE, value)
	local shell = tagOf(item)
	if shell == nil then
		return
	end
	local keys = CargoConstants.LABEL_KEYS
	shell:SetAttribute(keys.name, name)
	shell:SetAttribute(keys.value, value)
	shell:SetAttribute(keys.impacts, impacts)
	if def.grimy then
		shell:SetAttribute(keys.clean, numberAttribute(item, CargoConstants.CLEAN_ATTRIBUTE, 0))
		shell:SetAttribute(keys.appraised, item:GetAttribute(CargoConstants.APPRAISED_ATTRIBUTE) == true)
		shell:SetAttribute(keys.appraisedAt, item:GetAttribute(CargoConstants.APPRAISED_AT_ATTRIBUTE))
		shell:SetAttribute(keys.sealed, item:GetAttribute(CargoConstants.SEALED_ATTRIBUTE) == true)
	end
end

-- A valuable is a vacuum target (its size's grime channel, GRIME_TAG) until it is spotless.
local function setCleanable(item: Instance, def: CargoTypes.ItemDef, cleanable: boolean)
	item:SetAttribute(
		InteractionConstants.CHANNEL_KIND_ATTRIBUTE,
		if cleanable then VacuumConstants.GRIME_KINDS[def.size] else nil
	)
	if cleanable then
		CollectionService:AddTag(item, VacuumConstants.GRIME_TAG)
	else
		CollectionService:RemoveTag(item, VacuumConstants.GRIME_TAG)
	end
end

local CargoSpawnSystem = {}

function CargoSpawnSystem.new(visuals: ArtVisualSystem.Controller?): CargoSpawnSystem
	local art = visuals or ArtVisualSystem
	local nextId = 0

	local system: CargoSpawnSystem = {
		--[=[
			Spawns one `kind` standing on `floor` under `parent` and returns its part.
		]=]
		spawn = function(_self, kind, floor, parent, options)
			local def = CargoRegistry.get(kind)
			assert(def ~= nil, `CargoSpawnSystem: unknown cargo "{kind}"`)
			local hidden = options ~= nil and options.hidden == true
			local value = if options ~= nil and options.value ~= nil then options.value else def.value
			local appraisal: CargoTypes.Appraisal? = nil
			if def.grimy then
				appraisal = if options ~= nil and options.appraisal ~= nil
					then options.appraisal
					else { base = def.value, variant = nil, clean = 0, appraised = false }
			end
			nextId += 1
			local part = Instance.new("Part")
			part.Name = def.name
			part.Size = def.partSize
			part.Color = def.color
			part.Material = Enum.Material.SmoothPlastic
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			part.Anchored = true
			part.CanCollide = false
			-- A hidden item must not catch floor probes meant for the pile above it.
			part.CanQuery = not hidden
			part.Transparency = if hidden then 1 else 0
			part.CFrame = floor * CFrame.new(0, def.partSize.Y / 2, 0)
			part:SetAttribute(CarryConstants.KIND_ATTRIBUTE, kind)
			part:SetAttribute(CargoConstants.ID_ATTRIBUTE, nextId)
			part:SetAttribute(CargoConstants.VALUE_ATTRIBUTE, value)
			part:SetAttribute(CargoConstants.IMPACTS_ATTRIBUTE, 0)
			if appraisal ~= nil then
				part:SetAttribute(CargoConstants.BASE_VALUE_ATTRIBUTE, appraisal.base)
				part:SetAttribute(CargoConstants.CLEAN_ATTRIBUTE, math.clamp(appraisal.clean, 0, 1))
				part:SetAttribute(CargoConstants.APPRAISED_ATTRIBUTE, appraisal.appraised)
				part:SetAttribute(CargoConstants.VARIANT_ATTRIBUTE, appraisal.variant)
				if appraisal.sealed == true then
					part:SetAttribute(CargoConstants.SEALED_ATTRIBUTE, true)
				end
			end
			local source = if options ~= nil and options.source ~= nil
				then options.source
				elseif hidden then "pile"
				else "open"
			part:SetAttribute(CargoConstants.SOURCE_ATTRIBUTE, source)
			if hidden then
				part:SetAttribute(CargoConstants.HIDDEN_ATTRIBUTE, true)
				part:SetAttribute(InteractionConstants.ENABLED_ATTRIBUTE, false)
			end
			makeTag(part, def, value, hidden, appraisal ~= nil)
			if appraisal ~= nil then
				price(part)
				setCleanable(part, def, appraisal.clean < 1 and appraisal.sealed ~= true)
			end
			part.Parent = parent
			local kitId = if options ~= nil then options.artKit else nil
			art.attach(part, "cargo", kind, kitId, hidden)
			-- Last: Carry reads the kind, and Interaction the enabled flag, when the tag lands.
			CollectionService:AddTag(part, CarryConstants.TAG)
			return part
		end,

		--[=[
			Uncovers a hidden item: visible, queryable, labelled and pickable. A no-op for one already
			visible.
		]=]
		reveal = function(_self, item)
			if not item:IsA("BasePart") or item:GetAttribute(CargoConstants.HIDDEN_ATTRIBUTE) ~= true then
				return
			end
			item:SetAttribute(CargoConstants.HIDDEN_ATTRIBUTE, nil)
			item.Transparency = 0
			art.setHidden(item, false)
			item.CanCollide = false
			item.CanQuery = true
			item:SetAttribute(InteractionConstants.ENABLED_ATTRIBUTE, nil)
			local shell = tagOf(item)
			if shell ~= nil then
				shell.Enabled = true
				shell:SetAttribute(CargoConstants.LABEL_KEYS.hidden, false)
			end
		end,

		--[=[
			Re-reads an item's value from what it carries (a fragile item took an impact) and copies it, with the item's
			impacts, cleanliness and appraisal, onto its tag. A trash item keeps its price.
		]=]
		reprice = function(_self, item)
			price(item)
		end,

		--[=[
			Moves a valuable's cleanliness up to `clean` (never down), appraises it the first time that reaches
			APPRAISE_AT (`now`, server time, is when), re-prices it, and makes it no vacuum target once spotless.
			True when this call appraised it. A sealed valuable is never cleaned.
		]=]
		setClean = function(_self, item, clean, now)
			local def = grimyDef(item)
			if def == nil or item:GetAttribute(CargoConstants.SEALED_ATTRIBUTE) == true then
				return false
			end
			local current = numberAttribute(item, CargoConstants.CLEAN_ATTRIBUTE, 0)
			local nextClean = math.max(current, math.clamp(clean, 0, 1))
			local was = item:GetAttribute(CargoConstants.APPRAISED_ATTRIBUTE) == true
			local appraised = CargoAppraisalFormulas.isAppraised(nextClean, was)
			item:SetAttribute(CargoConstants.CLEAN_ATTRIBUTE, nextClean)
			if appraised and not was then
				item:SetAttribute(CargoConstants.APPRAISED_ATTRIBUTE, true)
				item:SetAttribute(CargoConstants.APPRAISED_AT_ATTRIBUTE, now)
			end
			price(item)
			if nextClean >= 1 then
				setCleanable(item, def, false)
			end
			return appraised and not was
		end,

		--[=[
			Appraises a valuable without cleaning it (banked unappraised: its value is revealed at the truck). True when
			it was not appraised before.
		]=]
		appraise = function(_self, item, now)
			if grimyDef(item) == nil or item:GetAttribute(CargoConstants.APPRAISED_ATTRIBUTE) == true then
				return false
			end
			item:SetAttribute(CargoConstants.APPRAISED_ATTRIBUTE, true)
			item:SetAttribute(CargoConstants.APPRAISED_AT_ATTRIBUTE, now)
			price(item)
			return true
		end,

		--[=[
			Locks a valuable's grime as it is (its first pick-up while not spotless): it keeps its cleanliness and value,
			stops being a vacuum target, and its tag reads GRIME LOCKED. True when this call sealed it; false for trash, a
			spotless valuable or one already sealed.
		]=]
		seal = function(_self, item)
			local def = grimyDef(item)
			if
				def == nil
				or item:GetAttribute(CargoConstants.SEALED_ATTRIBUTE) == true
				or numberAttribute(item, CargoConstants.CLEAN_ATTRIBUTE, 0) >= 1
			then
				return false
			end
			item:SetAttribute(CargoConstants.SEALED_ATTRIBUTE, true)
			setCleanable(item, def, false)
			price(item)
			return true
		end,

		--[=[
			The floor point below `position` (ignoring `ignore`), or 3 studs below it when nothing is hit.
		]=]
		floorUnder = function(_self, position, ignore)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = ignore
			-- The office's safe-zone volume is queryable but not collidable: land on the real floor, not on it.
			params.RespectCanCollide = true
			local hit = Workspace:Raycast(position, Vector3.new(0, -CargoConstants.FLOOR_PROBE, 0), params)
			return CFrame.new(if hit ~= nil then hit.Position else position - Vector3.new(0, 3, 0))
		end,
	}
	return system
end

return CargoSpawnSystem
