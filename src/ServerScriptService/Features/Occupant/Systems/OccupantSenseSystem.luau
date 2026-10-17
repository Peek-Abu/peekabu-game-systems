--!strict
--[=[
	OccupantSenseSystem: what the Manager senses, read from the world for OccupantServiceServer: each crew member's
	glimpse (one line-of-sight ray each), who hides and whether he saw them go in, and (the behaviour set,
	docs/superpowers/specs/2026-10-15-cleanup-crew-manager-behaviours-design.md) the office's furniture as he knows it:
	every hiding spot (`furniture`: its centre, where he stands to stare at it, and whether it is a secure supply
	cabinet) and every desk with its seat frame
	(over its art chair, OfficeDecorSystem's officeChair marked with the desk's id, else where the chair rule puts it),
	and the hiders in their spots (`hiders`).

	@class OccupantSenseSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Types = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local CrouchConstants = require(ReplicatedStorage.Shared.Features.Crouch.Data.CrouchConstants)
local HideTypes = require(ReplicatedStorage.Shared.Features.Hide.Data.HideTypes)
local OccupantBrainRules = require(ServerScriptService.Features.Occupant.Rules.OccupantBrainRules)
local OccupantDeskUtils = require(ServerScriptService.Features.Occupant.Utils.OccupantDeskUtils)
local HideServiceServer = require(ServerScriptService.Features.Hide.HideServiceServer)

-- Office's attributes: a desk's marker id, and an art chair's key and desk (OfficeBuildSystem, OfficeDecorSystem).
local MARKER_ATTRIBUTE = "OfficeMarkerId"
local ART_KEY_ATTRIBUTE = "OfficeArtKey"
local CHAIR_DESK_ATTRIBUTE = "OfficeDeskMarker"
local CHAIR_KEY = "officeChair"
-- A crouching character (CrouchServiceServer's attribute): noticed slower beside him.
local CROUCH_ATTRIBUTE = CrouchConstants.CROUCHING_ATTRIBUTE

-- The body box checked at a stand point (wide and deep as his body, waist to head over the floor).
local STAND_BOX = Vector3.new(2, 4, 1.6)

local System = {}
function System.feetY(root: BasePart, humanoid: Humanoid): number
	local legHeight = 0
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		local leg = if root.Parent ~= nil then root.Parent:FindFirstChild("Left Leg") else nil
		if leg ~= nil and leg:IsA("BasePart") then
			legHeight = leg.Size.Y
		end
	end
	return root.Position.Y - humanoid.HipHeight - root.Size.Y / 2 - legHeight
end
function System.glimpses(
	rig: { model: Model, head: BasePart },
	sightRange: number,
	participants: { Player },
	eligible: (Player) -> boolean
): { Types.Glimpse }
	local exclude: { Instance } = { rig.model }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	local list: { Types.Glimpse } = {}
	for _, player in participants do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local h = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if root and root:IsA("BasePart") and h and h.Health > 0 and eligible(player) then
			local offset = root.Position - rig.head.Position
			local clear = offset.Magnitude <= sightRange and Workspace:Raycast(rig.head.Position, offset, params) == nil
			table.insert(list, {
				userId = player.UserId,
				position = root.Position,
				feetY = System.feetY(root, h),
				clear = clear,
				crouched = character ~= nil and character:GetAttribute(CROUCH_ATTRIBUTE) == true,
			})
		end
	end
	return list
end
export type World = {
	resting: boolean,
	route: { Vector3 },
	restPoint: Vector3,
	zone: Types.Zone,
	bay: Types.Zone?,
}
-- Marks who in `list` hides (Hide) and whether he saw them go in. Returns `list`.
function System.markHidden(list: { Types.Glimpse }): { Types.Glimpse }
	for _, glimpse in list do
		local player = Players:GetPlayerByUserId(glimpse.userId)
		if player ~= nil and HideServiceServer:isHidden(player) then
			glimpse.hidden = true
			glimpse.seen = HideServiceServer:seenEntering(player)
		end
	end
	return list
end
-- Whether `userId` is in his view in `list`: a clear ray, or hidden where he saw them go in (he knows where they are).
function System.inView(list: { Types.Glimpse }, userId: number): boolean
	for _, glimpse in list do
		if glimpse.userId == userId then
			return glimpse.clear or (glimpse.hidden == true and glimpse.seen == true)
		end
	end
	return false
end
-- How far his line-of-sight rays reach: his near sight or his long sight straight ahead, whichever is longer.
function System.rayRange(sightRange: number): number
	return math.max(sightRange, OccupantConstants.LONG_SIGHT_RANGE)
end
-- What he senses now (no noise yet): from his root and head, his sight (near, and long straight ahead), the glimpses and
-- the world he walks.
function System.senses(
	rig: { root: BasePart, head: BasePart },
	sight: { sightRange: number, sightAngle: number },
	now: number,
	players: { Types.Glimpse },
	world: World
): Types.Senses
	return {
		position = rig.root.Position,
		reachTopY = rig.head.Position.Y + rig.head.Size.Y / 2,
		look = rig.root.CFrame.LookVector,
		now = now,
		sightRange = sight.sightRange,
		sightAngle = sight.sightAngle,
		longRange = OccupantConstants.LONG_SIGHT_RANGE,
		longAngle = OccupantConstants.LONG_SIGHT_ANGLE,
		players = players,
		heard = nil,
		resting = world.resting,
		route = world.route,
		restPoint = world.restPoint,
		zone = world.zone,
		bay = world.bay,
	}
end
-- The office model a piece of furniture belongs to (its outermost ancestor under the Workspace).
local function officeOf(part: Instance): Instance?
	local current: Instance? = part
	while current ~= nil and current.Parent ~= nil and current.Parent ~= Workspace do
		current = current.Parent
	end
	return current
end

-- Every art chair under `office`, by the desk id it serves.
local function chairs(office: Instance?): { [string]: BasePart }
	local found: { [string]: BasePart } = {}
	if office == nil then
		return found
	end
	for _, item in office:GetDescendants() do
		if item:IsA("BasePart") and item:GetAttribute(ART_KEY_ATTRIBUTE) == CHAIR_KEY then
			local desk = item:GetAttribute(CHAIR_DESK_ATTRIBUTE)
			if type(desk) == "string" then
				found[desk] = item
			end
		end
	end
	return found
end

-- Whether a body could stand at the floor point `point` (nothing collidable there but characters and NPCs).
local function standable(point: Vector3): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character ~= nil then
			table.insert(ignore, player.Character)
		end
	end
	for _, npc in CollectionService:GetTagged(OccupantConstants.TAG) do
		table.insert(ignore, npc)
	end
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	return #Workspace:GetPartBoundsInBox(CFrame.new(point + Vector3.new(0, 3, 0)), STAND_BOX, params) == 0
end

-- The first stand point a body fits at (the beside-the-chair one when none does).
local function standAt(frame: CFrame, size: Vector3, fits: (point: Vector3) -> boolean): Vector3
	local points = OccupantDeskUtils.standPoints(frame, size, OccupantConstants.STARE_GAP, OccupantConstants.STARE_SIDE)
	for _, point in points do
		if fits(point) then
			return point
		end
	end
	return points[1]
end

--[=[
	The hiding spots and the desks he can sit at, from Hide's spots. `standHeight` is his root's height over his feet.
	Each spot's stand point is the first of OccupantDeskUtils.standPoints a body fits at (`fits`, default a world
	check), so a stare never slides him into furniture (where no path exists and he would never move again).
]=]
function System.furniture(
	spots: { HideTypes.Spot },
	standHeight: number,
	fits: ((point: Vector3) -> boolean)?
): ({ Types.Desk }, { Types.Spot })
	local clear = fits or standable
	local desks: { Types.Desk } = {}
	local views: { Types.Spot } = {}
	local byDesk = chairs(if #spots > 0 then officeOf(spots[1].furniture) else nil)
	for _, spot in spots do
		local part = spot.furniture
		local marker = part:GetAttribute(MARKER_ATTRIBUTE)
		local deskId = if spot.noun == "desk" and type(marker) == "string" then marker else nil
		local stand = standAt(spot.frame, part.Size, clear)
		local across = spot.frame:PointToObjectSpace(stand).X
		table.insert(views, {
			id = spot.id,
			center = part.Position,
			stand = stand,
			side = if math.abs(across) < 1e-3 then 0 elseif across > 0 then 1 else -1,
			deskId = deskId,
			-- A closed supply cabinet (Hide's "inside" spot) is secure: he must open it to look.
			secure = spot.kind == "inside",
		})
		if deskId ~= nil then
			local chair: BasePart? = byDesk[deskId]
			local floorY = part.Position.Y - part.Size.Y / 2
			local at = if chair ~= nil then chair.Position else OccupantDeskUtils.fallbackChair(spot.frame)
			local seat, front = OccupantDeskUtils.seatFrame(at, spot.frame, floorY, standHeight)
			table.insert(
				desks,
				{ id = deskId, seat = seat, front = front, spotId = spot.id, frame = part.CFrame, size = part.Size }
			)
		end
	end
	return desks, views
end

--[=[
	Hide's witness: whether he (`rig`, thinking `mind`) sees `player` right now as they go into a spot, or is chasing
	them (OccupantBrainRules.witnessed). One ray. Never yields.
]=]
function System.witness(
	rig: { model: Model, root: BasePart, head: BasePart },
	mind: Types.Mind,
	sight: { sightRange: number, sightAngle: number },
	world: World,
	player: Player
): boolean
	local seen = System.glimpses(rig, System.rayRange(sight.sightRange), { player }, function(): boolean
		return true
	end)
	return OccupantBrainRules.witnessed(mind, System.senses(rig, sight, os.clock(), seen, world), player.UserId)
end

--[=[
	Who of `participants` hides, where, and whether he saw them go in.
]=]
function System.hiders(participants: { Player }): { Types.Hider }
	local list: { Types.Hider } = {}
	for _, player in participants do
		local info = HideServiceServer:spotOf(player)
		if info ~= nil then
			table.insert(list, { userId = player.UserId, spotId = info.id, seen = info.seenEntering })
		end
	end
	return list
end

return System
