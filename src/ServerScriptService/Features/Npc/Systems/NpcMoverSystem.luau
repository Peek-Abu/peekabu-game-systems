--!strict
--[=[
	NpcMoverSystem: walks one NPC's Humanoid to a goal along a PathfindingService path.

	`moveTo(goal, now)` re-paths only when NpcPathRules.shouldRepath says so (the goal moved, or the path
	is old). Path computation yields, so it runs on its own thread and a newer request supersedes an
	older one. With no path (blocked, or the goal is off the navmesh) the Humanoid walks straight at the
	goal. `step()` advances waypoints and jumps where the path says to. `costs` are the kind's pathCosts
	(PathfindingModifier labels or materials).

	Spec-exempt shell (PathfindingService, Humanoid); the decisions are NpcPathRules.

	@class NpcMoverSystem
]=]

local PathfindingService = game:GetService("PathfindingService")
local ServerScriptService = game:GetService("ServerScriptService")

local NpcConstants = require(ServerScriptService.Features.Npc.Data.NpcConstants)
local NpcPathRules = require(ServerScriptService.Features.Npc.Rules.NpcPathRules)

export type NpcMoverSystem = {
	moveTo: (self: NpcMoverSystem, goal: Vector3, now: number) -> (),
	stop: (self: NpcMoverSystem) -> (),
	step: (self: NpcMoverSystem) -> (),
	goal: (self: NpcMoverSystem) -> Vector3?,
	reached: (self: NpcMoverSystem) -> boolean,
	destroy: (self: NpcMoverSystem) -> (),
}

local NpcMoverSystem = {}

function NpcMoverSystem.new(humanoid: Humanoid, root: BasePart, costs: { [string]: number }?): NpcMoverSystem
	local path = PathfindingService:CreatePath({ AgentCanJump = true, Costs = costs or {} })
	local currentGoal: Vector3? = nil
	local computedAt: number? = nil
	local waypoints: { PathWaypoint } = {}
	local index = 0
	local request = 0
	local alive = true

	local function walkTo(position: Vector3)
		humanoid:MoveTo(position)
	end

	local function startPath(goal: Vector3)
		request += 1
		local mine = request
		task.spawn(function()
			local ok = pcall(function()
				path:ComputeAsync(root.Position, goal)
			end)
			if not alive or mine ~= request then
				return
			end
			if ok and path.Status == Enum.PathStatus.Success then
				waypoints = path:GetWaypoints()
				-- Waypoint 1 is where the NPC stands; head for the next one.
				index = math.min(2, #waypoints)
				if index >= 1 then
					walkTo(waypoints[index].Position)
				end
			else
				waypoints = {}
				index = 0
				walkTo(goal)
			end
		end)
	end

	local mover: NpcMoverSystem = {
		moveTo = function(_self, goal, now)
			if
				not NpcPathRules.shouldRepath(
					currentGoal,
					goal,
					computedAt,
					now,
					NpcConstants.REPATH_DISTANCE,
					NpcConstants.REPATH_MAX_AGE
				)
			then
				return
			end
			currentGoal = goal
			computedAt = now
			startPath(goal)
		end,

		stop = function(_self)
			request += 1
			currentGoal = nil
			computedAt = nil
			waypoints = {}
			index = 0
			walkTo(root.Position)
		end,

		step = function(_self)
			-- Bounds-checked rather than nil-checked: PathWaypoint is a datatype that cannot be compared to nil.
			if index < 1 or index > #waypoints then
				return
			end
			local waypoint = waypoints[index]
			local flat = Vector3.new(waypoint.Position.X - root.Position.X, 0, waypoint.Position.Z - root.Position.Z)
			if flat.Magnitude > NpcConstants.REACHED_DISTANCE then
				return
			end
			index += 1
			if index <= #waypoints then
				local nextWaypoint = waypoints[index]
				if nextWaypoint.Action == Enum.PathWaypointAction.Jump then
					humanoid.Jump = true
				end
				walkTo(nextWaypoint.Position)
			end
		end,

		goal = function(_self)
			return currentGoal
		end,

		reached = function(_self)
			local goal = currentGoal
			if goal == nil then
				return true
			end
			local flat = Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z)
			return flat.Magnitude <= NpcConstants.REACHED_DISTANCE
		end,

		destroy = function(_self)
			alive = false
			request += 1
			path:Destroy()
		end,
	}
	return mover
end

return NpcMoverSystem
