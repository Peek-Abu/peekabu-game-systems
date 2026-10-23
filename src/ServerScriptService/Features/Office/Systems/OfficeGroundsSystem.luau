--!strict
--[=[
	OfficeGroundsSystem: the code parts of a generated office's outside (stage 3: the yard and car park, and two
	Lethal-style teleport entrances). The outside's art is a fixed exterior; this builds only what play needs:

	- **Outdoors** (folder): one invisible volume per ground (named by its id), its box from the floor to
	  OUTSIDE.VOLUME_HEIGHT, non-colliding but queryable (PathfindingService ignores a modifier on a CanQuery=false part),
	  with a PathfindingModifier labelled OccupantConstants.SAFE_ZONE_LABEL (PassThrough off): Mr. Harlow never paths
	  outside.
	- **Entrances** (folder): an invisible 8 x 10 x 1 hit box at each entrance's outside door, turned by its yaw,
	  non-colliding and queryable, tagged for Interaction as OfficeConstants.ENTER_KIND with attribute EntranceId.
	- **Exits** (folder): each entrance's inside exit, a closed door that never swings, on its room's wall. The shell
	  breaks the trim at it and cases it like a facade (OfficeGroundsUtils.exitFacades); its leaves are a facade's
	  (OfficeDoorSystem.facadeLeaves: one solid leaf for the dock, a double glass door for the lobby), each tagged
	  OfficeConstants.LEAVE_KIND with attribute EntranceId; an EXIT sign (OfficeDecorSystem.exitSign) hangs above it on
	  the room side. The exits are not layout doors: no door record, Harlow never opens them.

	A layout without grounds (the authored boot layout) builds nothing.

	Instance shell; the geometry is the specced OfficeGroundsUtils and OfficeDoorUtils.

	@class OfficeGroundsSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ArtVisualSystem = require(ServerScriptService.Features.Art.Systems.ArtVisualSystem)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OfficeDecorConstants = require(ReplicatedStorage.Shared.Features.Office.Data.OfficeDecorConstants)
local OfficeServer = ServerScriptService.Features.Office
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeArtKeyUtils = require(OfficeServer.Utils.OfficeArtKeyUtils)
local OfficeGroundsUtils = require(OfficeServer.Utils.OfficeGroundsUtils)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)
local OfficeDecorSystem = require(script.Parent.OfficeDecorSystem)
local OfficeDoorSystem = require(script.Parent.OfficeDoorSystem)

local OUTSIDE = OfficeConstants.OUTSIDE
local DOOR_SIZE = Vector3.new(8, 10, 1)
-- The EXIT sign's clearance above the exit's casing head (at DOOR_HEIGHT).
local SIGN_CLEARANCE = 0.25

export type Built = {
	-- Each entrance's inside exit leaf (the first of a double door).
	exits: { [OfficeTypes.EntranceId]: BasePart },
	-- Each entrance's outside door hit box.
	doors: { [OfficeTypes.EntranceId]: BasePart },
}

local function folder(name: string, parent: Instance): Folder
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = parent
	return created
end

-- An anchored, invisible, non-colliding part that queries see.
local function ghost(name: string, size: Vector3, cframe: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = true
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

-- Tags `part` for Interaction as `kind`, for entrance `id` (OfficeBuildSystem's attribute pattern).
local function interactable(part: BasePart, kind: string, id: OfficeTypes.EntranceId)
	part:SetAttribute(InteractionConstants.KIND_ATTRIBUTE, kind)
	part:SetAttribute("EntranceId", id)
	CollectionService:AddTag(part, InteractionConstants.TAG)
end

-- The unit vector from `edge`'s wall line into its room.
local function inward(edge: OfficeTypes.Edge): Vector3
	return if edge == "minZ"
		then Vector3.zAxis
		elseif edge == "maxZ" then -Vector3.zAxis
		elseif edge == "minX" then Vector3.xAxis
		else -Vector3.xAxis
end

local OfficeGroundsSystem = {}

--[=[
	Builds the outside's Outdoors volumes, outside door hit boxes and inside exits for `layout` at `origin` under
	`parent` (the office model), and returns the exits and outside doors by entrance id. Empty maps, and nothing
	built, when the layout has no grounds. `visuals` supplies the leaf and sign art (default: the live
	ArtVisualSystem).
]=]
function OfficeGroundsSystem.build(
	layout: OfficeTypes.Layout,
	origin: CFrame,
	parent: Instance,
	visuals: ArtVisualSystem.Controller?
): Built
	local built: Built = { exits = {}, doors = {} }
	local grounds = layout.grounds
	if grounds == nil then
		return built
	end
	local art = visuals or ArtVisualSystem

	local outdoors = folder("Outdoors", parent)
	local height = OUTSIDE.VOLUME_HEIGHT
	for _, ground in grounds do
		local width, depth = ground.maxX - ground.minX, ground.maxZ - ground.minZ
		local volume = ghost(
			ground.id,
			Vector3.new(width, height, depth),
			origin * CFrame.new(ground.minX + width / 2, height / 2, ground.minZ + depth / 2),
			outdoors
		)
		local modifier = Instance.new("PathfindingModifier")
		modifier.Label = OccupantConstants.SAFE_ZONE_LABEL
		modifier.PassThrough = false
		modifier.Parent = volume
	end

	local entrances: { OfficeTypes.Entrance } = layout.entrances or {}
	if #entrances == 0 then
		return built
	end
	local doors = folder("Entrances", parent)
	local exits = folder("Exits", parent)
	local facades = OfficeGroundsUtils.exitFacades(layout)
	for index, entrance in entrances do
		local outside = entrance.outside
		local door = ghost(
			entrance.id,
			DOOR_SIZE,
			origin * CFrame.new(outside.x, DOOR_SIZE.Y / 2, outside.z) * CFrame.Angles(0, outside.yaw, 0),
			doors
		)
		interactable(door, OfficeConstants.ENTER_KIND, entrance.id)
		built.doors[entrance.id] = door

		local facade = facades[index]
		local room = OfficeLayoutUtils.room(layout, entrance.exit.a)
		local edge: OfficeTypes.Edge? = if room ~= nil then OfficeLayoutUtils.facadeEdge(room, facade) else nil
		if room ~= nil and edge ~= nil then
			local leaves = OfficeDoorSystem.facadeLeaves(facade, room, origin, exits, art, `Exit_{entrance.id}`)
			for _, leaf in leaves do
				interactable(leaf, OfficeConstants.LEAVE_KIND, entrance.id)
			end
			built.exits[entrance.id] = leaves[1]

			local size = OfficeDecorConstants.EXIT_SIGN_SIZE
			local at = Vector3.new(facade.x, OfficeConstants.DOOR_HEIGHT + SIGN_CLEARANCE + size.Y / 2, facade.z)
				+ inward(edge) * (OfficeConstants.WALL_THICKNESS / 2 + size.Z / 2)
			local turn = if edge == "minX" or edge == "maxX" then CFrame.Angles(0, math.rad(90), 0) else CFrame.identity
			local sign =
				OfficeDecorSystem.exitSign(origin * CFrame.new(at) * turn, exits, art, OfficeArtKeyUtils.roomType(room))
			sign:SetAttribute("EntranceId", entrance.id)
		end
	end
	return built
end

return OfficeGroundsSystem
