--!strict
--[=[
	NpcMoverSystem: continuous server-owned Humanoid steering along native paths.
	One ComputeAsync runs at a time. Refreshes retain a usable route and adopt its forward segment using
	the live position, rather than rewinding to waypoint two. No-cost kinds alone may fall back to a direct goal.
	Pure progress/recovery decisions live in NpcPathRules; this native shell is spec-exempt.
	@class NpcMoverSystem
]=]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
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
	local path: Path? = nil
	local blockedConnection: RBXScriptConnection? = nil
	local pending = false
	local invalidated = false
	local progressPosition = root.Position
	local progressAt = os.clock()
	local currentGoal: Vector3? = nil
	local pathGoal: Vector3? = nil
	local computedAt: number? = nil
	local attemptedAt = -math.huge
	local waypoints: { PathWaypoint } = {}
	local index = 0
	local request = 0
	local alive = true
	local hasCosts = costs ~= nil and next(costs) ~= nil

	local function steer(position: Vector3?)
		local delta = if position ~= nil then position - root.Position else Vector3.zero
		local flat = Vector3.new(delta.X, 0, delta.Z)
		-- MoveTo terminates each leg near its destination; Move keeps steering across intermediate points.
		humanoid:Move(if flat.Magnitude > 0.1 then flat.Unit else Vector3.zero, false)
	end

	local function clearPath()
		if blockedConnection ~= nil then
			blockedConnection:Disconnect()
			blockedConnection = nil
		end
		if path ~= nil then
			path:Destroy()
			path = nil
		end
	end

	local function jumpAtWaypoint()
		if index >= 1 and index <= #waypoints and waypoints[index].Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end
	end

	local function supportedGoal(goal: Vector3): Vector3
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local excluded: { Instance } = { root.Parent or root }
		for _, player in Players:GetPlayers() do
			if player.Character ~= nil then
				table.insert(excluded, player.Character)
			end
		end
		for _, npc in CollectionService:GetTagged(NpcConstants.TAG) do
			table.insert(excluded, npc)
		end
		params.FilterDescendantsInstances = excluded
		params.RespectCanCollide = true
		-- Start AT the observed destination: starting above it could select a ceiling during a jump.
		local hit = Workspace:Raycast(goal, Vector3.new(0, -48, 0), params)
		return NpcPathRules.supportedGoal(
			goal,
			if hit ~= nil then hit.Position.Y else nil,
			humanoid.HipHeight + root.Size.Y / 2
		)
	end

	local function startPath(goal: Vector3, now: number)
		request += 1
		local mine = request
		pending = true
		invalidated = false
		attemptedAt = now
		local origin = root.Position
		local candidate = PathfindingService:CreatePath({ AgentCanJump = true, Costs = costs or {} })
		task.spawn(function()
			local ok = pcall(function()
				candidate:ComputeAsync(origin, goal)
			end)
			-- A cancelled compute remains in flight until it returns; stop cannot open a second computation.
			pending = false
			if not alive or mine ~= request then
				candidate:Destroy()
				return
			end
			local points = if ok and candidate.Status == Enum.PathStatus.Success then candidate:GetWaypoints() else {}
			local budget = (root.Position - origin).Magnitude + NpcConstants.PATH_ADOPTION_CORRIDOR
			local nextIndex =
				NpcPathRules.resumeIndex(points, root.Position, budget, NpcConstants.PATH_ADOPTION_CORRIDOR)
			if nextIndex ~= nil then
				clearPath()
				path = candidate
				waypoints = points
				index = nextIndex
				pathGoal = goal
				computedAt = os.clock()
				invalidated = false
				blockedConnection = candidate.Blocked:Connect(function(blockedIndex)
					if NpcPathRules.blockedAhead(blockedIndex, index, #waypoints) then
						invalidated = true
					end
				end)
				jumpAtWaypoint()
			else
				candidate:Destroy()
				invalidated = true
			end
		end)
	end

	local mover: NpcMoverSystem = {
		moveTo = function(_self, goal, now)
			if not alive then
				return
			end
			goal = supportedGoal(goal)
			if currentGoal == nil then
				progressPosition = root.Position
				progressAt = now
			end
			-- Remember the latest allowed goal even while computation yields; never read a hidden quarry here.
			currentGoal = goal
			if pending or now - attemptedAt < NpcConstants.REPATH_MIN_INTERVAL then
				return
			end
			if
				invalidated
				or NpcPathRules.shouldRepath(
					pathGoal,
					goal,
					computedAt,
					now,
					NpcConstants.REPATH_DISTANCE,
					NpcConstants.REPATH_MAX_AGE
				)
			then
				startPath(goal, now)
			end
		end,

		stop = function(_self)
			request += 1
			invalidated = false
			clearPath()
			currentGoal = nil
			pathGoal = nil
			computedAt = nil
			waypoints = {}
			index = 0
			steer(nil)
		end,

		step = function(_self)
			if not alive then
				return
			end
			local now = os.clock()
			local goal = currentGoal
			local remaining = goal ~= nil
				and Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z).Magnitude
					> NpcConstants.REACHED_DISTANCE
			if
				NpcPathRules.stalled(
					progressPosition,
					root.Position,
					progressAt,
					now,
					NpcConstants.STUCK_PROGRESS,
					NpcConstants.STUCK_SECONDS,
					remaining
				)
			then
				invalidated = true
				progressPosition = root.Position
				progressAt = now
			elseif (root.Position - progressPosition).Magnitude >= NpcConstants.STUCK_PROGRESS or not remaining then
				progressPosition = root.Position
				progressAt = now
			end
			-- Drain passed points in one frame: high speeds need not pause one frame per close waypoint.
			while index >= 1 and index <= #waypoints do
				local waypoint = waypoints[index]
				local previous = if index > 1 then waypoints[index - 1].Position else waypoint.Position
				if
					not NpcPathRules.passedWaypoint(
						previous,
						waypoint.Position,
						root.Position,
						NpcConstants.WAYPOINT_REACHED_DISTANCE
					)
				then
					break
				end
				index += 1
				jumpAtWaypoint()
			end
			if goal == nil then
				steer(nil)
			elseif index >= 1 and index <= #waypoints then
				steer(waypoints[index].Position)
			else
				-- An exhausted costed route must refresh immediately rather than wait for maximum age.
				invalidated = remaining
				steer(if remaining and not hasCosts then goal else nil)
			end
		end,

		goal = function(_self)
			return currentGoal
		end,

		reached = function(_self)
			local goal = currentGoal
			return goal == nil
				or Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z).Magnitude
					<= NpcConstants.REACHED_DISTANCE
		end,

		destroy = function(_self)
			alive = false
			request += 1
			clearPath()
			steer(nil)
		end,
	}
	return mover
end

return NpcMoverSystem
