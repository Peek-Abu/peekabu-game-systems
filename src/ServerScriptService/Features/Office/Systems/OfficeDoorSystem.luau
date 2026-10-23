--!strict
--[=[
	OfficeDoorSystem: the office's real doors. For every layout door of kind "solid" or "glass" a leaf players open
	and close (an anchored part tagged for Interaction, kind OfficeConstants.DOOR_KIND, swung about its hinge with
	TweenService), and for every facade a closed, flush, non-interactable leaf on the room side of the wall it fronts
	(attribute `OfficeFacade` = its kind; a stairwell is one solid leaf, an entrance a pair of glass leaves, each half
	its width, hinged at the outer edges: a double door). Door ids are "<a>|<b>".

	A leaf is CanQuery, and CanCollide only while closed (an open leaf neither blocks walkers nor Mr. Harlow's sight
	ray, which respects CanCollide). Its PathfindingModifier (Label DOOR_PATH_LABEL, PassThrough) keeps closed doors
	from blocking his paths; he opens them with `openNear`. Glass leaves are tagged SightThrough. Attributes:
	OfficeDoorId and OfficeDoorOpen (mirrors the state; flips as a swing starts).

	Bodies: a doorway is clear to close only with no Humanoid's root in it, players and NPCs alike (Mr. Harlow is
	never shut in or knocked by a closing leaf): player roots from Players, every other Humanoid model's root from a
	spatial query of the doorway. A player's close is also refused while any NPC root is within
	DOOR_REACH of the door (he would reopen it at once), so a player can neither close a door on him nor
	stall him by spamming it, and no false slam is heard. `openNear` opens only the closed doors he is walking
	through: within DOOR_REACH and ahead of the given heading (OfficeDoorUtils.reach; a nil heading counts every
	door as ahead). Doors behind him, beside him or farther off stay as they are.

	Facades are locked: each leaf is tagged for Interaction as OfficeConstants.FACADE_KIND ("Locked"), and `rattle`
	gives it a short yaw jiggle about its own centre (OfficeDoorUtils.rattle) that returns exactly to its frame, with
	no noise; a rattle ignores interacts while it runs.

	The swing tweens a fraction (0 closed .. 1 open) and places the leaf with OfficeDoorUtils.leafFrame each step,
	so it travels the hinge's arc (tweening the CFrame itself would cut a chord). A door ignores toggles mid-swing.

	A leaf is the clear opening inside the casing (OfficeDoorUtils.leafSize), so it swings clear of the oak jambs.

	Art: a leaf takes the kit's `doorLeaf` (solid) or `doorLeafGlass` (glass) template through OfficeArtKeyUtils; the
	visual welds to the leaf, so it swings with it and stays non-colliding while the leaf keeps its collision and tags
	(attaching hides the leaf's own plastic or glass; with no template the greybox leaf stays as it was). ArtVisualSystem
	flags a colliding art leaf as a camera occluder (CameraOccluderConstants.ATTRIBUTE); a glass leaf never occludes, and
	a solid one only while closed (cleared as an opening swing starts, restored when a close completes).

	Instance/TweenService shell; the door maths is the specced OfficeDoorUtils.

	@class OfficeDoorSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local ArtVisualSystem = require(ServerScriptService.Features.Art.Systems.ArtVisualSystem)
local CameraOccluderConstants = require(ReplicatedStorage.Shared.Features.Camera.Data.CameraOccluderConstants)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local OfficeServer = ServerScriptService.Features.Office
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeDoorUtils = require(OfficeServer.Utils.OfficeDoorUtils)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)
local OfficeArtKeyUtils = require(OfficeServer.Utils.OfficeArtKeyUtils)

type DoorState = OfficeDoorUtils.DoorState

type Record = {
	state: DoorState,
	door: OfficeTypes.Door,
	edge: OfficeTypes.Edge,
	sign: number,
	leaf: BasePart,
	fraction: NumberValue,
	-- A solid leaf wearing art: it occludes the camera while closed.
	occluder: boolean,
	busy: boolean,
	tween: Tween?,
	connection: RBXScriptConnection?,
	-- The doorway (opening x wall thickness x DOOR_HEIGHT) in the world, min and max corners.
	boxMin: Vector3,
	boxMax: Vector3,
}

-- A facade leaf's rattle: its resting frame, the 0 .. 1 progress being tweened and the running tween.
type Rattle = { frame: CFrame, progress: NumberValue, tween: Tween? }

export type DoorSet = {
	-- Opens a closed door or closes an open one. False when it is mid-swing, unknown, someone (player or NPC)
	-- stands in the doorway of a door being closed, or, for a player's close, an NPC is within
	-- DOOR_REACH of it. `by` is the player who asked (nil: Harlow / the harness).
	toggle: (id: string, by: Player?) -> boolean,
	-- Opens every closed door within OfficeConstants.DOOR_REACH of `point` (XZ) and ahead of `heading`
	-- (OfficeDoorUtils.ahead; a nil heading counts every door as ahead). True if it opened one.
	openNear: (point: Vector3, heading: Vector3?) -> boolean,
	-- Rattles a locked facade leaf. False when `leaf` is not one or is already rattling.
	rattle: (leaf: BasePart) -> boolean,
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

-- Attaches the leaf's door art; true when it did and the leaf is solid (so it occludes while closed).
local function dress(art: ArtVisualSystem.Controller, leaf: BasePart, glass: boolean): boolean
	local visual = OfficeArtKeyUtils.attachFirst(
		art,
		leaf,
		"building",
		OfficeArtKeyUtils.candidates(if glass then "doorLeafGlass" else "doorLeaf", nil, nil)
	)
	if visual ~= nil and glass then
		leaf:SetAttribute(CameraOccluderConstants.ATTRIBUTE, nil)
	end
	return visual ~= nil and not glass
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
	Builds every leaf under a "Doors" folder in `parent` (the office model), laid out relative to `origin`. `visuals`
	supplies the leaf art (default: the live ArtVisualSystem).
]=]
function OfficeDoorSystem.build(
	layout: OfficeTypes.Layout,
	origin: CFrame,
	parent: Instance,
	visuals: ArtVisualSystem.Controller?
): DoorSet
	local art = visuals or ArtVisualSystem
	local folder = Instance.new("Folder")
	folder.Name = "Doors"
	folder.Parent = parent
	local records: { [string]: Record } = {}
	local rattles: { [BasePart]: Rattle } = {}
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

	-- The roots of the NPCs within DOOR_REACH of `record`'s door.
	local function npcsNear(record: Record): { Vector3 }
		local found: { Vector3 } = {}
		rootsIn(Workspace:GetPartBoundsInRadius(record.state.position, OfficeConstants.DOOR_REACH), true, found)
		return found
	end

	for _, door in layout.doors do
		local kind = door.kind
		local room = OfficeLayoutUtils.room(layout, door.a)
		local edge: OfficeTypes.Edge? = if room ~= nil then OfficeLayoutUtils.doorEdge(room, door) else nil
		if (kind == "solid" or kind == "glass") and room ~= nil and edge ~= nil then
			local id = `{door.a}|{door.b}`
			local horizontal = edge == "minZ" or edge == "maxZ"
			local leaf = leafPart("DoorLeaf", OfficeDoorUtils.leafSize(door), kind == "glass", folder)
			local occluder = dress(art, leaf, kind == "glass")
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
				occluder = occluder,
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

	-- Facades: locked fake doors on unbroken walls (closed, flush, locked: tagged FACADE_KIND, they only rattle). An entrance is a double glass
	-- door: two leaves of half its width side by side, each hinged at its outer edge (the template's hinge is its local
	-- +X, so the leaf on the frame's -X side is turned half way); a stairwell is one solid leaf.
	local facades: { OfficeTypes.Facade } = layout.facades or {}
	for index, facade in facades do
		local room = OfficeLayoutUtils.room(layout, facade.room)
		-- An elevator is its own front (OfficeDecorSystem): no leaf, no prompt.
		local frame = if room ~= nil and facade.kind ~= "elevator"
			then OfficeDoorUtils.facadeFrame(facade, room, origin)
			else nil
		if frame ~= nil then
			local entrance = facade.kind == "entrance"
			for leafIndex, spec in OfficeDoorUtils.facadeLeaves(facade) do
				local leaf = leafPart(
					if entrance then `Facade{index}_{leafIndex}` else `Facade{index}`,
					spec.size,
					entrance,
					folder
				)
				leaf.CFrame = frame
					* CFrame.new(spec.offset)
					* CFrame.Angles(0, if spec.side < 0 then math.pi else 0, 0)
				dress(art, leaf, entrance)
				leaf:SetAttribute("OfficeFacade", facade.kind)
				leaf:SetAttribute(InteractionConstants.KIND_ATTRIBUTE, OfficeConstants.FACADE_KIND)
				CollectionService:AddTag(leaf, InteractionConstants.TAG)
				rattles[leaf] = { frame = leaf.CFrame, progress = Instance.new("NumberValue"), tween = nil }
			end
		end
	end

	-- Starts a swing to open or shut. A close that ends with someone in the doorway reopens instead of shutting them in.
	local function swing(record: Record, opening: boolean)
		record.busy = true
		setOpen(record, opening)
		if opening then
			record.leaf.CanCollide = false
			if record.occluder then
				record.leaf:SetAttribute(CameraOccluderConstants.ATTRIBUTE, nil)
			end
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
					if record.occluder then
						record.leaf:SetAttribute(CameraOccluderConstants.ATTRIBUTE, true)
					end
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
				local radius = OfficeConstants.DOOR_REACH
				if by ~= nil and OfficeDoorUtils.npcNear(npcsNear(record), record.state.position, radius) then
					return false
				end
			end
			swing(record, opening)
			return true
		end,

		openNear = function(point, heading)
			local opened = false
			for _, id in OfficeDoorUtils.reach(states, point, heading, OfficeConstants.DOOR_REACH) do
				if set.toggle(id, nil) then
					opened = true
				end
			end
			return opened
		end,

		rattle = function(leaf)
			local rattle = rattles[leaf]
			if rattle == nil or rattle.tween ~= nil then
				return false
			end
			local tween = TweenService:Create(
				rattle.progress,
				TweenInfo.new(OfficeConstants.DOOR_RATTLE_SECONDS, Enum.EasingStyle.Linear),
				{ Value = 1 }
			)
			rattle.tween = tween
			rattle.progress.Value = 0
			local connection = rattle.progress.Changed:Connect(function(value)
				leaf.CFrame = rattle.frame * OfficeDoorUtils.rattle(value)
			end)
			tween.Completed:Once(function()
				connection:Disconnect()
				leaf.CFrame = rattle.frame
				rattle.tween = nil
				tween:Destroy()
			end)
			tween:Play()
			return true
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
				if record.occluder then
					record.leaf:SetAttribute(CameraOccluderConstants.ATTRIBUTE, true)
				end
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
			for leaf, rattle in rattles do
				local tween = rattle.tween
				if tween ~= nil then
					rattle.tween = nil
					tween:Cancel()
					tween:Destroy()
					leaf.CFrame = rattle.frame
				end
				rattle.progress:Destroy()
			end
			table.clear(records)
			table.clear(rattles)
			table.clear(states)
		end,
	}
	return set
end

return OfficeDoorSystem
