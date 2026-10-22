--!strict
--[=[
	OfficeDoorSystem: the office's real doors. For every layout door of kind "solid" or "glass" a leaf players open
	and close (an anchored part tagged for Interaction, kind OfficeConstants.DOOR_KIND, swung about its hinge with
	TweenService), and for every facade a closed, flush, non-interactable leaf on the room side of the wall it fronts
	(attribute `OfficeFacade` = its kind; glass for an entrance, solid for a stairwell). Door ids are "<a>|<b>".

	A leaf is CanQuery, and CanCollide only while closed (an open leaf neither blocks walkers nor Mr. Harlow's sight
	ray, which respects CanCollide). Its PathfindingModifier (Label DOOR_PATH_LABEL, PassThrough) keeps closed doors
	from blocking his paths; he opens them with `openNear`. Glass leaves are tagged SightThrough. Attributes:
	OfficeDoorId and OfficeDoorOpen (mirrors the state; flips as a swing starts).

	The swing tweens a fraction (0 closed .. 1 open) and places the leaf with OfficeDoorUtils.leafFrame each step,
	so it travels the hinge's arc (tweening the CFrame itself would cut a chord). A door ignores toggles mid-swing.

	Instance/TweenService shell; the door maths is the specced OfficeDoorUtils.

	@class OfficeDoorSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local OfficeServer = ServerScriptService.Features.Office
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeDoorUtils = require(OfficeServer.Utils.OfficeDoorUtils)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)

type DoorState = OfficeDoorUtils.DoorState

type Record = {
	state: DoorState,
	door: OfficeTypes.Door,
	edge: OfficeTypes.Edge,
	sign: number,
	leaf: BasePart,
	fraction: NumberValue,
	busy: boolean,
	tween: Tween?,
	connection: RBXScriptConnection?,
	-- The doorway (opening x wall thickness x DOOR_HEIGHT) in the world, min and max corners.
	boxMin: Vector3,
	boxMax: Vector3,
}

export type DoorSet = {
	-- Opens a closed door or closes an open one. False when it is mid-swing, unknown, or something stands in the
	-- doorway of a door being closed. `by` is the player who asked (nil: Harlow / the harness).
	toggle: (id: string, by: Player?) -> boolean,
	-- Opens every closed door within OfficeConstants.DOOR_AUTO_OPEN_RADIUS of `point` (XZ). True if any opened.
	openNear: (point: Vector3) -> boolean,
	-- Every door's id, world centre and open flag. Live: read only, do not keep across a rebuild.
	states: () -> { DoorState },
	-- Snaps every door shut (test harness).
	closeAll: () -> (),
	-- Cancels swings and forgets every door.
	destroy: () -> (),
}

local OfficeDoorSystem = {}

local function leafPart(name: string, size: Vector3, glass: boolean, parent: Instance): Part
	local leaf = Instance.new("Part")
	leaf.Name = name
	leaf.Size = size
	leaf.Anchored = true
	leaf.CanCollide = true
	leaf.CanQuery = true
	leaf.CanTouch = false
	leaf.TopSurface = Enum.SurfaceType.Smooth
	leaf.BottomSurface = Enum.SurfaceType.Smooth
	leaf.Color = OfficeConstants.DOOR_COLOR
	if glass then
		leaf.Material = Enum.Material.Glass
		leaf.Transparency = 0.5
		CollectionService:AddTag(leaf, OccupantConstants.SIGHT_THROUGH_TAG)
	else
		leaf.Material = Enum.Material.WoodPlanks
	end
	leaf.Parent = parent
	return leaf
end

local function stopTween(record: Record)
	local tween = record.tween
	if tween ~= nil then
		record.tween = nil
		tween:Cancel()
		tween:Destroy()
	end
end

--[=[
	Builds every leaf under a "Doors" folder in `parent` (the office model), laid out relative to `origin`.
]=]
function OfficeDoorSystem.build(layout: OfficeTypes.Layout, origin: CFrame, parent: Instance): DoorSet
	local folder = Instance.new("Folder")
	folder.Name = "Doors"
	folder.Parent = parent
	local records: { [string]: Record } = {}
	local states: { DoorState } = {}
	local thickness = OfficeConstants.WALL_THICKNESS
	local height = OfficeConstants.DOOR_HEIGHT

	local function setOpen(record: Record, open: boolean)
		record.state.open = open
		record.leaf:SetAttribute("OfficeDoorOpen", open)
	end

	local function place(record: Record)
		record.leaf.CFrame =
			OfficeDoorUtils.leafFrame(record.door, record.edge, record.sign, record.fraction.Value, origin)
	end

	local function bodies(): { Vector3 }
		local found: { Vector3 } = {}
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
			if root ~= nil and root:IsA("BasePart") then
				table.insert(found, root.Position)
			end
		end
		return found
	end

	for _, door in layout.doors do
		local kind = door.kind
		local room = OfficeLayoutUtils.room(layout, door.a)
		local edge = if room ~= nil then OfficeLayoutUtils.doorEdge(room, door) else nil
		if (kind == "solid" or kind == "glass") and room ~= nil and edge ~= nil then
			local id = `{door.a}|{door.b}`
			local horizontal = edge == "minZ" or edge == "maxZ"
			local leaf = leafPart(
				"DoorLeaf",
				Vector3.new(door.width, height, OfficeConstants.DOOR_LEAF_THICKNESS),
				kind == "glass",
				folder
			)
			local modifier = Instance.new("PathfindingModifier")
			modifier.Label = OfficeConstants.DOOR_PATH_LABEL
			modifier.PassThrough = true
			modifier.Parent = leaf
			leaf:SetAttribute("OfficeDoorId", id)
			leaf:SetAttribute("OfficeDoorOpen", false)
			leaf:SetAttribute(InteractionConstants.KIND_ATTRIBUTE, OfficeConstants.DOOR_KIND)
			CollectionService:AddTag(leaf, InteractionConstants.TAG)

			local size = if horizontal
				then Vector3.new(door.width, height, thickness)
				else Vector3.new(thickness, height, door.width)
			local centre = Vector3.new(door.x, 0, door.z)
			local a = origin:PointToWorldSpace(centre - size / 2)
			local b = origin:PointToWorldSpace(centre + size / 2)
			local record: Record = {
				state = {
					id = id,
					position = origin:PointToWorldSpace(Vector3.new(door.x, height / 2, door.z)),
					open = false,
				},
				door = door,
				edge = edge,
				sign = OfficeDoorUtils.swingSign(door, edge, room),
				leaf = leaf,
				fraction = Instance.new("NumberValue"),
				busy = false,
				tween = nil,
				connection = nil,
				boxMin = Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z)),
				boxMax = Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z)),
			}
			record.connection = record.fraction.Changed:Connect(function()
				place(record)
			end)
			place(record)
			records[id] = record
			table.insert(states, record.state)
		end
	end

	-- Facades: locked fake doors on unbroken walls (closed, flush, not interactable).
	for index, facade in layout.facades or {} do
		local room = OfficeLayoutUtils.room(layout, facade.room)
		local frame = if room ~= nil then OfficeDoorUtils.facadeFrame(facade, room, origin) else nil
		if frame ~= nil then
			local leaf = leafPart(
				`Facade{index}`,
				Vector3.new(facade.width, height, OfficeConstants.DOOR_LEAF_THICKNESS),
				facade.kind == "entrance",
				folder
			)
			leaf.CFrame = frame
			leaf:SetAttribute("OfficeFacade", facade.kind)
		end
	end

	local set: DoorSet
	set = {
		toggle = function(id, _by)
			local record = records[id]
			if record == nil or record.busy then
				return false
			end
			local opening = not record.state.open
			if not opening and not OfficeDoorUtils.canClose(record.boxMin, record.boxMax, bodies()) then
				return false
			end
			record.busy = true
			setOpen(record, opening)
			if opening then
				record.leaf.CanCollide = false
			end
			local tween = TweenService:Create(
				record.fraction,
				TweenInfo.new(OfficeConstants.DOOR_SWING_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Value = if opening then 1 else 0 }
			)
			record.tween = tween
			tween.Completed:Once(function()
				if record.tween ~= tween then
					return
				end
				record.tween = nil
				record.busy = false
				tween:Destroy()
				if not record.state.open then
					record.leaf.CanCollide = true
				end
			end)
			tween:Play()
			return true
		end,

		openNear = function(point)
			local opened = false
			for _, id in OfficeDoorUtils.near(states, point, OfficeConstants.DOOR_AUTO_OPEN_RADIUS) do
				if set.toggle(id, nil) then
					opened = true
				end
			end
			return opened
		end,

		states = function()
			return states
		end,

		closeAll = function()
			for _, record in records do
				stopTween(record)
				record.busy = false
				record.fraction.Value = 0
				setOpen(record, false)
				record.leaf.CanCollide = true
			end
		end,

		destroy = function()
			for _, record in records do
				stopTween(record)
				local connection = record.connection
				if connection ~= nil then
					connection:Disconnect()
				end
				record.fraction:Destroy()
			end
			table.clear(records)
			table.clear(states)
		end,
	}
	return set
end

return OfficeDoorSystem
