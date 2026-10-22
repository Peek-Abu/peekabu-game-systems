--!strict
--[=[
	OfficeTraversalHarness: proves Mr. Harlow can walk every generated layout with every door shut.

	For each seed, `run` generates the layout (OfficeLayoutGenerationUtils.generate over OfficeLayoutConstants.LAYOUT),
	builds the office and its decor at `origin` in the Workspace, snaps every door shut (the leaves keep CanQuery on and
	carry a PassThrough PathfindingModifier labelled OfficeDoor, so a path should run through them), lets the navmesh
	settle, then asks PathfindingService for a path from the loading bay's patrol point to every other patrol marker
	and to the centre of every room but the bay. The path parameters are Harlow's own (NpcMoverSystem: AgentCanJump,
	costs { [SAFE_ZONE_LABEL] = math.huge }, no other agent settings).

	A target fails when the status is not Success, or when a Success path ends more than END_TOLERANCE studs (XZ) short
	of the goal (ComputeAsync can return a partial path to the nearest reachable point). Failures read
	"<seed> <targetId>: <status>" or "<seed> <targetId>: ends <d> studs short".

	A room centre that sits inside a colliding part of the built model (a conference table, a supply cabinet; a 2x4x2
	box query that ignores the room's floor and ceiling) cannot be a goal, so that room is judged 2 studs inside its
	first door instead ("<room>.door-side"): a dead end must stay reachable.

	Seed number i (1-based position in `seeds`) is built at origin offset (i - 1) * 1000 studs in X, and the navmesh
	gets 1 s to settle after each build: rebuilding at one origin right after destroying the previous model left a
	stale navmesh (NoPath on reachable rooms).

	Each seed's build is destroyed after a pcall, so a failing or erroring seed leaves nothing in the Workspace.
	Runs sequentially; ComputeAsync yields. Needs a real runtime (TestEZ in Studio).

	@class OfficeTraversalHarness
]=]
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

local OfficeServer = ServerScriptService.Features.Office
local OfficeLayoutConstants = require(OfficeServer.Data.OfficeLayoutConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeBuildSystem = require(OfficeServer.Systems.OfficeBuildSystem)
local OfficeDecorSystem = require(OfficeServer.Systems.OfficeDecorSystem)
local OfficeLayoutGenerationUtils = require(OfficeServer.Utils.OfficeLayoutGenerationUtils)

-- Where Harlow starts, and the most a Success path may end from its goal (XZ studs).
local START_MARKER = "bay.patrol.1"
local END_TOLERANCE = 4
-- A character's root height above the floor: both ends of a path are lifted this far.
local LIFT = 3
-- Seconds the navmesh gets to settle after the build before the first ComputeAsync.
local SETTLE_SECONDS = 1
-- The blocked-centre probe: a box this size, centred PROBE_HEIGHT above the floor.
local PROBE_SIZE = Vector3.new(2, 4, 2)
local PROBE_HEIGHT = 3
-- How far inside a room its door-side target sits.
local DOOR_SIDE_PUSH = 2
-- Each seed builds this far (X) from the previous one, so a fresh navmesh never meets a stale one.
local SEED_SPACING = 1000

export type Result = {
	failures: { string },
	paths: number,
}

local OfficeTraversalHarness = {}

type Target = { id: string, x: number, z: number }

-- True when a colliding part of the built model (other than its floors and ceilings) fills the point (office-local
-- x, z): a 2x4x2 box about 3 studs above the floor, queried against the model's own parts.
local function blocked(model: Model, origin: CFrame, x: number, z: number): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { model }
	params.RespectCanCollide = true
	for _, part in Workspace:GetPartBoundsInBox(origin * CFrame.new(x, PROBE_HEIGHT, z), PROBE_SIZE, params) do
		if part.Name ~= "Floor" and part.Name ~= "FloorUnderlay" and part.Name ~= "Ceiling" then
			return true
		end
	end
	return false
end

-- The room's first door centre pushed DOOR_SIDE_PUSH studs into the room along the door's inward normal.
local function doorSide(layout: OfficeTypes.Layout, room: OfficeTypes.Room): Vector2?
	for _, door in layout.doors do
		if door.a == room.id or door.b == room.id then
			local edges = {
				{ math.abs(door.x - room.minX), 1, 0 },
				{ math.abs(door.x - room.maxX), -1, 0 },
				{ math.abs(door.z - room.minZ), 0, 1 },
				{ math.abs(door.z - room.maxZ), 0, -1 },
			}
			local best = edges[1]
			for _, edge in edges do
				if edge[1] < best[1] then
					best = edge
				end
			end
			return Vector2.new(door.x + best[2] * DOOR_SIDE_PUSH, door.z + best[3] * DOOR_SIDE_PUSH)
		end
	end
	return nil
end

local function targetsFor(layout: OfficeTypes.Layout, model: Model, origin: CFrame): { Target }
	local targets: { Target } = {}
	for _, marker in layout.markers do
		if marker.kind == "patrol" and marker.id ~= START_MARKER then
			table.insert(targets, { id = marker.id, x = marker.x, z = marker.z })
		end
	end
	for _, room in layout.rooms do
		if room.id ~= layout.startRoom then
			local x, z = (room.minX + room.maxX) / 2, (room.minZ + room.maxZ) / 2
			local id = `{room.id}.centre`
			if blocked(model, origin, x, z) then
				-- The centre is inside furniture (a conference table, a supply cabinet): judge the room just inside its
				-- door instead, so a dead end stays reachable.
				local side = doorSide(layout, room)
				if side ~= nil then
					x, z, id = side.X, side.Y, `{room.id}.door-side`
				end
			end
			table.insert(targets, { id = id, x = x, z = z })
		end
	end
	return targets
end

local function checkTargets(
	seed: number,
	layout: OfficeTypes.Layout,
	built: OfficeBuildSystem.Built,
	start: OfficeTypes.Marker,
	origin: CFrame,
	failures: { string }
): number
	OfficeDecorSystem.build(layout, origin, built.model)
	built.doors.closeAll()
	task.wait(SETTLE_SECONDS)
	local path = PathfindingService:CreatePath({
		AgentCanJump = true,
		Costs = { [OccupantConstants.SAFE_ZONE_LABEL] = math.huge },
	})
	local from = (origin * CFrame.new(start.x, LIFT, start.z)).Position
	local computed = 0
	for _, target in targetsFor(layout, built.model, origin) do
		local goal = (origin * CFrame.new(target.x, LIFT, target.z)).Position
		local computeOk, computeErr = pcall(function()
			path:ComputeAsync(from, goal)
		end)
		computed += 1
		if not computeOk then
			table.insert(failures, `{seed} {target.id}: ComputeAsync error {tostring(computeErr)}`)
		elseif path.Status ~= Enum.PathStatus.Success then
			table.insert(failures, `{seed} {target.id}: {path.Status.Name}`)
		else
			local waypoints = path:GetWaypoints()
			local last = waypoints[#waypoints]
			if last == nil then
				table.insert(failures, `{seed} {target.id}: no waypoints`)
			else
				local gap = Vector3.new(last.Position.X - goal.X, 0, last.Position.Z - goal.Z).Magnitude
				if gap > END_TOLERANCE then
					table.insert(failures, `{seed} {target.id}: ends {string.format("%.1f", gap)} studs short`)
				end
			end
		end
	end
	return computed
end

local function checkSeed(seed: number, origin: CFrame, failures: { string }): number
	local layout = OfficeLayoutGenerationUtils.generate(OfficeLayoutConstants.LAYOUT, seed)
	local start: OfficeTypes.Marker? = nil
	for _, marker in layout.markers do
		if marker.id == START_MARKER then
			start = marker
		end
	end
	if start == nil then
		table.insert(failures, `{seed} {START_MARKER}: missing start marker`)
		return 0
	end
	local built = OfficeBuildSystem.build(layout, origin)
	local computed = 0
	local ok, err = pcall(function()
		computed = checkTargets(seed, layout, built, start, origin, failures)
	end)
	-- Clean up whether or not the seed errored.
	built.doors.destroy()
	built.model:Destroy()
	if not ok then
		table.insert(failures, `{seed} harness: {tostring(err)}`)
	end
	return computed
end

--[=[
	Builds each seed's office at `origin` with every door closed and paths Harlow from the bay to every patrol marker
	and room centre. Returns the failures and how many paths were computed.
]=]
function OfficeTraversalHarness.run(seeds: { number }, origin: CFrame): Result
	local failures: { string } = {}
	local paths = 0
	for index, seed in seeds do
		paths += checkSeed(seed, origin * CFrame.new((index - 1) * SEED_SPACING, 0, 0), failures)
	end
	return { failures = failures, paths = paths }
end

return OfficeTraversalHarness
