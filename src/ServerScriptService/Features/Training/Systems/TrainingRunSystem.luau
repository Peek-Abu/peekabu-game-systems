--!strict
--[=[
	TrainingRunSystem: one player's training run on the Training map, while the shift runs on it (TrainingSiteSystem is
	the site). It follows the run's stops (TrainingStopRules): a stop's piles cleared (Vacuum's pileCleared) or its
	treasure loaded (the item is destroyed when the truck banks it) finish that stop and open its doors; walking into
	the next stop's zone (checked every POLL_SECONDS) moves the player on. The stop is published as the `training` world
	entry for the client's hall effects (signs, lights out, the Gloom creeping, the glowing desk).

	The escape stop (goal "escape") is passed by getting away from Mr. Harlow, by hiding or by outrunning him: every
	poll senses him (near, chasing this player, a clear line of sight, far) and the player (hidden) into
	TrainingStopRules.escapeStep. Getting away completes the stop and publishes the stop in the CLEAR_ENTRY world entry,
	which the client turns into the "He's gone! Go now!" cue. A catch there starts the count again.

	A catch (ShiftServiceServer.caught) costs a life as usual, but the lives floor (ShiftServiceServer:setLivesFloor)
	means it never knocks the player out: the client plays the catch beat (TrainingEvents.Caught: the goo splat on a
	heart, the red card, a quick dark wipe), and the player is moved back to the start of their stop while still knocked
	down and the screen dark, so they stand up there (one beat). Harlow is then sent off to work at a desk away from
	them (OccupantServiceServer:summonToDesk), so there is no catch straight after.
	Walking into the last stop finishes the run: `finished` is called once (the reward, the finish screen).

	Spec-exempt shell (Instances, signals, Shift and Vacuum); the decisions are the specced TrainingStopRules and
	TrainingMapRules.

	@class TrainingRunSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local TrainingEvents = require(ReplicatedStorage.Shared.Features.Training.Net.TrainingEvents)
local TrainingStopRules = require(ReplicatedStorage.Shared.Features.Training.Rules.TrainingStopRules)
local HideServiceServer = require(ServerScriptService.Features.Hide.HideServiceServer)
local OccupantServiceServer = require(ServerScriptService.Features.Occupant.OccupantServiceServer)
local ShiftServiceServer = require(ServerScriptService.Features.Shift.ShiftServiceServer)
local StateSyncWorldStore = require(ServerScriptService.Features.StateSync.State.StateSyncWorldStore)
local TrainingMapRules = require(ServerScriptService.Features.Training.Rules.TrainingMapRules)
local TrainingSiteSystem = require(ServerScriptService.Features.Training.Systems.TrainingSiteSystem)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)

export type Run = {
	-- The run's piles and items, once the site has spawned them.
	track: (self: Run, piles: { TrainingSiteSystem.Spawned }, items: { TrainingSiteSystem.Spawned }) -> (),
	stop: (self: Run) -> (),
	state: (self: Run) -> TrainingStopRules.State,
}

local POLL_SECONDS = 0.2

local log = Logger.new("TrainingRunSystem")

-- What the escape stop senses of Mr. Harlow and the player at `root` (TrainingStopRules.Sense). No Harlow: far and
-- unseen.
local function sense(player: Player, root: BasePart): TrainingStopRules.Sense
	local rules = TrainingConstants.ESCAPE
	local hidden = HideServiceServer:isHidden(player)
	local harlow = OccupantServiceServer:getHarlow()
	local head = if harlow ~= nil then harlow:FindFirstChild("Head") else nil
	local from = if head ~= nil and head:IsA("BasePart")
		then head.Position
		elseif harlow ~= nil then harlow:GetPivot().Position
		else nil
	if harlow == nil or from == nil then
		return { near = false, chasing = false, hidden = hidden, seen = false, far = true }
	end
	local mind = OccupantServiceServer:getMind()
	local chasing = mind ~= nil and (mind.mode == "chase" or mind.mode == "search") and mind.target == player.UserId
	local distance = (root.Position - from).Magnitude
	local params = RaycastParams.new()
	local ignore: { Instance } = { harlow }
	if player.Character ~= nil then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local blocked = Workspace:Raycast(from, root.Position - from, params) ~= nil
	return {
		near = distance < rules.near,
		chasing = chasing,
		hidden = hidden,
		seen = not hidden and not blocked,
		far = distance >= rules.far,
	}
end

-- Opens a door: it and everything in it stops blocking and fades out.
local function clearOut(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.Transparency = 1
end

local function open(door: BasePart)
	clearOut(door)
	for _, part in door:GetDescendants() do
		if part:IsA("BasePart") then
			clearOut(part)
		end
	end
	door:SetAttribute("TrainingOpen", true)
end

local TrainingRunSystem = {}

function TrainingRunSystem.new(
	player: Player,
	model: Model,
	plan: TrainingMapRules.Plan,
	finished: (player: Player) -> ()
): Run
	local state = TrainingStopRules.new()
	local escape = TrainingStopRules.newEscape()
	local stoppers: { () -> () } = {}
	local remaining: { [number]: { [BasePart]: true } } = {}
	local stopped = false

	local doors: { [number]: { BasePart } } = {}
	for _, part in model:GetDescendants() do
		local stop = part:GetAttribute(TrainingConstants.STOP_ATTRIBUTE)
		if
			part:IsA("BasePart")
			and part:GetAttribute(TrainingConstants.ROLE_ATTRIBUTE) == "door"
			and type(stop) == "number"
		then
			local list = doors[stop] or {}
			doors[stop] = list
			table.insert(list, part)
		end
	end

	local function publish()
		StateSyncWorldStore.set(TrainingConstants.WORLD_ENTRY, state.stop)
	end

	local function openDone()
		for _, stop in TrainingStopRules.openDoors(state) do
			local list: { BasePart }? = doors[stop]
			if list ~= nil then
				for _, door in list do
					if door:GetAttribute("TrainingOpen") ~= true then
						open(door)
					end
				end
			end
		end
	end

	local function complete(stop: number, goal: TrainingConstants.Goal)
		if not stopped and TrainingStopRules.complete(state, stop, goal) then
			log:info(`stop {stop} done`)
			openDone()
		end
	end

	local function rootOf(): BasePart?
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		return if root ~= nil and root:IsA("BasePart") then root else nil
	end

	-- The escape stop: getting away from him completes it (and tells the client he is gone).
	local function escapePoll(root: BasePart)
		local def = TrainingConstants.STOPS[state.stop]
		if def == nil or def.goal ~= "escape" or TrainingStopRules.isDone(state, state.stop) then
			return
		end
		if TrainingStopRules.escapeStep(escape, POLL_SECONDS, sense(player, root)) then
			local at = state.stop
			complete(at, "escape")
			StateSyncWorldStore.set(TrainingConstants.CLEAR_ENTRY, at)
		end
	end

	local function poll()
		local root = rootOf()
		if root == nil then
			return
		end
		escapePoll(root)
		local zone = plan.zones[state.stop + 1]
		if zone == nil or not TrainingMapRules.inside(zone, root.Position) then
			return
		end
		if TrainingStopRules.enter(state, state.stop + 1) then
			escape = TrainingStopRules.newEscape()
			publish()
			openDone()
			if state.finished then
				stopped = true
				finished(player)
			end
		end
	end

	local clearing = VacuumServiceServer.pileCleared:Connect(function(pile: BasePart)
		for stop, set in remaining do
			if set[pile] then
				set[pile] = nil
				if next(set) == nil then
					complete(stop, "piles")
				end
			end
		end
	end)
	table.insert(stoppers, function()
		clearing:Disconnect()
	end)

	local catching = ShiftServiceServer.caught:Connect(function(caught: Player, livesLeft: number)
		if caught ~= player or stopped then
			return
		end
		-- The catch's only message on a training run (OccupantCatchUtils.feedback leaves it to training): the beat.
		TrainingEvents.packets.Caught.sendTo(math.clamp(livesLeft, 0, 255), player)
		local back: CFrame? = plan.stops[state.stop]
		-- Caught at the escape stop: the count starts again from the stop's start.
		escape = TrainingStopRules.newEscape()
		task.delay(TrainingConstants.RETURN_DELAY, function()
			local character = player.Character
			if not stopped and back ~= nil and character ~= nil and character.Parent ~= nil then
				character:PivotTo(back * CFrame.new(0, 3, 0))
				-- He walks off to a desk away from the stop start (nothing when he has none free).
				OccupantServiceServer:summonToDesk(player)
			end
		end)
	end)
	table.insert(stoppers, function()
		catching:Disconnect()
	end)

	local elapsed = 0
	local polling = RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed < POLL_SECONDS or stopped then
			return
		end
		elapsed = 0
		poll()
	end)
	table.insert(stoppers, function()
		polling:Disconnect()
	end)
	publish()

	local run: Run = {
		track = function(_self, piles, items)
			for _, pile in piles do
				local set = remaining[pile.stop] or {}
				remaining[pile.stop] = set
				set[pile.part] = true
			end
			for _, item in items do
				if item.treasure then
					local part = item.part
					local folder = part.Parent
					local banking = part.Destroying:Connect(function()
						-- Banked: the truck destroys what it takes. A shift reset destroys the folder first.
						if folder ~= nil and folder.Parent ~= nil then
							complete(item.stop, "banked")
						end
					end)
					table.insert(stoppers, function()
						banking:Disconnect()
					end)
				end
			end
		end,

		stop = function(_self)
			stopped = true
			for _, stopper in stoppers do
				stopper()
			end
			table.clear(stoppers)
			StateSyncWorldStore.clear(TrainingConstants.WORLD_ENTRY)
			StateSyncWorldStore.clear(TrainingConstants.CLEAR_ENTRY)
		end,

		state = function(_self)
			return state
		end,
	}
	return run
end

return TrainingRunSystem
