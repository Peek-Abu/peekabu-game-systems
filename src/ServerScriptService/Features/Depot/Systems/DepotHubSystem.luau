--!strict
--[=[
	DepotHubSystem: reads a Studio-built hub (DepotLayoutConstants.HUB). `find` returns the Model tagged MODEL_TAG
	inside the container (Workspace by default), or nil; `markers` turns its tagged truck bay, spawn and board spot
	parts into DepotHubRules markers, each standing on the floor under its part; `hide` makes those parts invisible
	and inert; `bounds` is the whole hub's box. DepotHubRules decides whether the hub is playable.

	@class DepotHubSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local DepotLayoutConstants = require(ServerScriptService.Features.Depot.Data.DepotLayoutConstants)
local DepotHubRules = require(ServerScriptService.Features.Depot.Rules.DepotHubRules)

local HUB = DepotLayoutConstants.HUB

local function number(part: Instance, name: string): number?
	local value = part:GetAttribute(name)
	return if typeof(value) == "number" then value else nil
end

local function tagged(hub: Model, tag: string): { BasePart }
	local parts: { BasePart } = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(hub) then
			table.insert(parts, instance)
		end
	end
	return parts
end

-- The part's CFrame moved down to the floor it stands on.
local function floorOf(part: BasePart): CFrame
	return part.CFrame * CFrame.new(0, -part.Size.Y / 2, 0)
end

local DepotHubSystem = {}

function DepotHubSystem.find(container: Instance?): Model?
	local within = container or Workspace
	for _, instance in CollectionService:GetTagged(HUB.MODEL_TAG) do
		if instance:IsA("Model") and instance:IsDescendantOf(within) then
			return instance
		end
	end
	return nil
end

function DepotHubSystem.markers(hub: Model): { DepotHubRules.Marker }
	local markers: { DepotHubRules.Marker } = {}
	for _, part in tagged(hub, HUB.TRUCK_TAG) do
		table.insert(markers, {
			kind = "truck",
			cframe = floorOf(part),
			truck = number(part, HUB.TRUCK_ATTRIBUTE),
			capacity = number(part, HUB.CAPACITY_ATTRIBUTE),
			countdown = number(part, HUB.COUNTDOWN_ATTRIBUTE),
		})
	end
	for _, part in tagged(hub, HUB.SPAWN_TAG) do
		table.insert(markers, { kind = "spawn", cframe = floorOf(part) })
	end
	for _, part in tagged(hub, HUB.BOARD_TAG) do
		local kind = part:GetAttribute(HUB.BOARD_ATTRIBUTE)
		table.insert(markers, {
			kind = "board",
			cframe = floorOf(part),
			board = if typeof(kind) == "string" then kind else nil,
		})
	end
	return markers
end

function DepotHubSystem.hide(hub: Model)
	for _, tag in { HUB.TRUCK_TAG, HUB.SPAWN_TAG, HUB.BOARD_TAG } do
		for _, part in tagged(hub, tag) do
			part.Transparency = 1
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			for _, child in part:GetDescendants() do
				if child:IsA("Decal") or child:IsA("SurfaceGui") or child:IsA("BillboardGui") then
					child:Destroy()
				end
			end
		end
	end
end

function DepotHubSystem.bounds(hub: Model): DepotHubRules.Bounds
	local cframe, size = hub:GetBoundingBox()
	return { cframe = cframe, size = size }
end

return DepotHubSystem
