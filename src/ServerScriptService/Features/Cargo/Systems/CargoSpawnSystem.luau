--!strict
--[=[
	CargoSpawnSystem: puts graybox cargo in the world. One anchored Part per item, sized and coloured from
	CargoRegistry, carrying its CarryKind / CargoId / CargoValue / CargoImpacts attributes and a name-and-value
	label, then tagged Carryable so Carry (and through it Interaction's "Pick up" prompt) takes over. A hidden
	item (under a pile) is invisible, lets players through, is skipped by raycasts and has its prompt off
	until `reveal`.

	Spec-exempt shell (Instances, raycasts); the catalog is the specced CargoRegistry.

	@class CargoSpawnSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CargoShared = ReplicatedStorage.Shared.Features.Cargo
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local CargoConstants = require(CargoShared.Data.CargoConstants)
local CargoRegistry = require(CargoShared.Data.CargoRegistry)
local CargoTypes = require(CargoShared.Data.CargoTypes)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)

export type CargoSpawnSystem = {
	spawn: (
		self: CargoSpawnSystem,
		kind: string,
		floor: CFrame,
		parent: Instance,
		options: CargoTypes.SpawnOptions?
	) -> BasePart,
	reveal: (self: CargoSpawnSystem, item: Instance) -> (),
	setValue: (self: CargoSpawnSystem, item: Instance, value: number) -> (),
	floorUnder: (self: CargoSpawnSystem, position: Vector3, ignore: { Instance }) -> CFrame,
}

local function labelText(kind: string, value: number): string
	local def = CargoRegistry.get(kind)
	return `{if def ~= nil then def.name else kind} ({value})`
end

local function labelOf(item: Instance): (BillboardGui?, TextLabel?)
	local billboard = item:FindFirstChild(CargoConstants.LABEL_NAME)
	if billboard == nil or not billboard:IsA("BillboardGui") then
		return nil, nil
	end
	local text = billboard:FindFirstChildOfClass("TextLabel")
	return billboard, text
end

local function makeLabel(part: BasePart, text: string, visible: boolean)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = CargoConstants.LABEL_NAME
	billboard.Size = UDim2.fromOffset(200, 30)
	billboard.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 1.5, 0)
	billboard.MaxDistance = CargoConstants.LABEL_DISTANCE
	billboard.Enabled = visible
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Font = Enum.Font.SourceSansSemibold
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard
	billboard.Parent = part
end

local CargoSpawnSystem = {}

function CargoSpawnSystem.new(): CargoSpawnSystem
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
			nextId += 1
			local part = Instance.new("Part")
			part.Name = def.name
			part.Size = def.partSize
			part.Color = def.color
			part.Material = Enum.Material.SmoothPlastic
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			part.Anchored = true
			part.CanCollide = not hidden
			-- A hidden item must not catch floor probes meant for the pile above it.
			part.CanQuery = not hidden
			part.Transparency = if hidden then 1 else 0
			part.CFrame = floor * CFrame.new(0, def.partSize.Y / 2, 0)
			part:SetAttribute(CarryConstants.KIND_ATTRIBUTE, kind)
			part:SetAttribute(CargoConstants.ID_ATTRIBUTE, nextId)
			part:SetAttribute(CargoConstants.VALUE_ATTRIBUTE, value)
			part:SetAttribute(CargoConstants.IMPACTS_ATTRIBUTE, 0)
			if hidden then
				part:SetAttribute(CargoConstants.HIDDEN_ATTRIBUTE, true)
				part:SetAttribute(InteractionConstants.ENABLED_ATTRIBUTE, false)
			end
			makeLabel(part, labelText(kind, value), not hidden)
			part.Parent = parent
			-- Last: Carry reads the kind, and Interaction the enabled flag, when the tag lands.
			CollectionService:AddTag(part, CarryConstants.TAG)
			return part
		end,

		--[=[
			Uncovers a hidden item: visible, solid, queryable, labelled and pickable. A no-op for one already
			visible.
		]=]
		reveal = function(_self, item)
			if not item:IsA("BasePart") or item:GetAttribute(CargoConstants.HIDDEN_ATTRIBUTE) ~= true then
				return
			end
			item:SetAttribute(CargoConstants.HIDDEN_ATTRIBUTE, nil)
			item.Transparency = 0
			item.CanCollide = true
			item.CanQuery = true
			item:SetAttribute(InteractionConstants.ENABLED_ATTRIBUTE, nil)
			local billboard = labelOf(item)
			if billboard ~= nil then
				billboard.Enabled = true
			end
		end,

		--[=[
			Sets an item's value (a fragile item dropped a tier) and its label.
		]=]
		setValue = function(_self, item, value)
			item:SetAttribute(CargoConstants.VALUE_ATTRIBUTE, value)
			local kind = item:GetAttribute(CarryConstants.KIND_ATTRIBUTE)
			local _, text = labelOf(item)
			if text ~= nil and type(kind) == "string" then
				text.Text = labelText(kind, value)
			end
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
