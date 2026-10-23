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

	Bodies: a doorway is clear to close only with no Humanoid's root in it, players and NPCs alike (Mr. Harlow is
	never shut in or knocked by a closing leaf): player roots from Players, every other Humanoid model's root from a
	spatial query of the doorway. A player's close is also refused while any NPC root is within
	DOOR_AUTO_OPEN_RADIUS of the door (he would reopen it at once), so a player can neither close a door on him nor
	stall him by spamming it, and no false slam is heard. `openNear` opens every closed door in reach but reports
	true only when one it opened lies ahead of the given heading (OfficeDoorUtils.ahead), so his door beat skips side
	doors and doors behind him.

	The swing tweens a fraction (0 closed .. 1 open) and places the leaf with OfficeDoorUtils.leafFrame each step,
	so it travels the hinge's arc (tweening the CFrame itself would cut a chord). A door ignores toggles mid-swing.

	Instance/TweenService shell; the door maths is the specced OfficeDoorUtils.

	@class OfficeDoorSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
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
	-- Opens a closed door or closes an open one. False when it is mid-swing, unknown, someone (player or NPC)
	-- stands in the doorway of a door being closed, or, for a player's close, an NPC is within
	-- DOOR_AUTO_OPEN_RADIUS of it. `by` is the player who asked (nil: Harlow / the harness).
	toggle: (id: string, by: Player?) -> boolean,
	-- Opens every closed door within OfficeConstants.DOOR_AUTO_OPEN_RADIUS of `point` (XZ). True if a door it opened
	-- lies ahead of `heading` (OfficeDoorUtils.ahead; a nil heading counts every door as ahead).
	openNear: (point: Vector3, heading: Vector3?) -> boolean,
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

	-- The roots among `parts` of Humanoid models (NPCs only when `npcOnly`), appended to `into`.
	local function rootsIn(parts: { BasePart }, npcOnly: boolean, into: { Vector3 })
		for _, part in parts do
			local model = part.Parent
			if
				part.Name == "HumanoidRootPart"
				and model ~= nil
				and model:IsA("Model")
				and model:FindFirstChildOfClass("Humanoid") ~= nil
				and not (npcOnly and Players:GetPlayerFromCharacter(model) ~= nil)
			then
				table.insert(into, part.Position)
			end
		end
	end

	-- Every Humanoid root that could stand in `record`'s doorway: each player's, and any other in the doorway box.
	local function bodies(record: Record): { Vector3 }
		local found: { Vector3 } = {}
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
			if root ~= nil and root:IsA("BasePart") then
				table.insert(found, root.Position)
			end
		end
		-- Covers the box OfficeDoorUtils.canClose tests (grown by its one-stud margin).
		local size = record.boxMax - record.boxMin + Vector3.one * 2
		rootsIn(Workspace:GetPartBoundsInBox(CFrame.new((record.boxMin + record.boxMax) / 2), size), true, found)
		return found
	end

	-- The roots of the NPCs within DOOR_AUTO_OPEN_RADIUS of `record`'s door.
	local function npcsNear(record: Record): { Vector3 }
		local found: { Vector3 } = {}
		rootsIn(
			Workspace:GetPartBoundsInRadius(record.state.position, OfficeConstants.DOOR_AUTO_OPEN_RADIUS),
			true,
			found
		)
		return found
	end

	for _, door in layout.doors do
		local kind = door.kind
		local room = OfficeLayoutUtils.room(layout, door.a)
		local edge: OfficeTypes.Edge? = if room ~= nil then OfficeLayoutUtils.doorEdge(room, door) else nil
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
			local centre = Vector3.new(door.x, height / 2, door.z)
			local a = origin:PointToWorldSpace(centre - size / 2) -- doorway box: floor to DOOR_HEIGHT
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
	local facades: { OfficeTypes.Facade } = layout.facades or {}
	for index, facade in facades do
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

	-- Starts a swing to open or shut. A close that ends with someone in the doorway reopens instead of shutting them in.
	local function swing(record: Record, opening: boolean)
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
			tween:Destroy()
			if opening or OfficeDoorUtils.canClose(record.boxMin, record.boxMax, bodies(record)) then
				record.busy = false
				if not opening then
					record.leaf.CanCollide = true
				end
			else
				swing(record, true)
			end
		end)
		tween:Play()
	end

	local set: DoorSet
	set = {
		toggle = function(id, by)
			local record = records[id]
			if record == nil or record.busy then
				return false
			end
			local opening = not record.state.open
			if not opening then
				if not OfficeDoorUtils.canClose(record.boxMin, record.boxMax, bodies(record)) then
					return false
				end
				-- A player's close with Mr. Harlow about: he would reopen it, so it never starts (and never slams).
				local radius = OfficeConstants.DOOR_AUTO_OPEN_RADIUS
				if by ~= nil and OfficeDoorUtils.npcNear(npcsNear(record), record.state.position, radius) then
					return false
				end
			end
			swing(record, opening)
			return true
		end,

		openNear = function(point, heading)
			local ahead = false
			for _, id in OfficeDoorUtils.near(states, point, OfficeConstants.DOOR_AUTO_OPEN_RADIUS) do
				local record = records[id]
				if
					set.toggle(id, nil)
					and record ~= nil
					and OfficeDoorUtils.ahead(record.state.position, point, heading)
				then
					ahead = true
				end
			end
			return ahead
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
