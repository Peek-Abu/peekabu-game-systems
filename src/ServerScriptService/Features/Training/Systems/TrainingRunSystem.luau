--!strict
--[=[
	TrainingRunSystem: one player's training run on the Training map, while the shift runs on it (TrainingSiteSystem is
	the site). It follows the run's stops (TrainingStopRules): a stop's piles cleared (Vacuum's pileCleared) or its
	treasure loaded into the truck (Cargo's `banked`, with the treasure's kind; picking it up is not enough) finish that
	stop and open its doors. A stop with `steps` (the first) finishes only once its steps are done in order
	(TrainingStepRules: the Gloom, a run, the power; the server sees the sprint and the power button), the step on now
	published as the STEP_ENTRY world entry for the client's tips; walking into
	the next stop's zone (checked every POLL_SECONDS) moves the player on. The stop is published as the `training` world
	entry for the client's hall effects (signs, lights out, the Gloom creeping, the glowing desk).

	The escape stop (goal "escape") is Mr. Harlow's scripted pass (TrainingHarlowSystem, TrainingPassRules): walking into
	it begins the pass (he waits offstage until then, and after), and the stop is done once he has left without
	catching the player. That publishes the stop in the CLEAR_ENTRY world entry, which the client turns into the
	"He's gone!" cue. A catch there means he comes round again after he has left.

	A catch (ShiftServiceServer.caught) costs a life as usual, but the lives floor (ShiftServiceServer:setLivesFloor)
	means it never knocks the player out: the client plays the catch beat (TrainingEvents.Caught: the goo splat on a
	heart, the red card, a quick dark wipe), and the player is moved back to the start of their stop while still knocked
	down and the screen dark, so they stand up there (one beat). On a training run Harlow ignores them for
	ShiftConstants.TRAINING_GRACE after a catch, so there is no catch straight after.
	Walking into the last stop finishes the run: `finished` is called once (the reward, the finish screen).

	Spec-exempt shell (Instances, signals, Shift, Vacuum, Cargo, Sprint and Ability); the decisions are the specced
	TrainingStopRules, TrainingStepRules and TrainingMapRules.

	@class TrainingRunSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local AbilityRegistry = require(ReplicatedStorage.Shared.Features.Ability.Data.AbilityRegistry)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local TrainingEvents = require(ReplicatedStorage.Shared.Features.Training.Net.TrainingEvents)
local TrainingStepRules = require(ReplicatedStorage.Shared.Features.Training.Rules.TrainingStepRules)
local TrainingStopRules = require(ReplicatedStorage.Shared.Features.Training.Rules.TrainingStopRules)
local AbilityServiceServer = require(ServerScriptService.Features.Ability.AbilityServiceServer)
local CargoServiceServer = require(ServerScriptService.Features.Cargo.CargoServiceServer)
local ShiftServiceServer = require(ServerScriptService.Features.Shift.ShiftServiceServer)
local SprintServiceServer = require(ServerScriptService.Features.Sprint.SprintServiceServer)
local StateSyncWorldStore = require(ServerScriptService.Features.StateSync.State.StateSyncWorldStore)
local TrainingHarlowSystem = require(ServerScriptService.Features.Training.Systems.TrainingHarlowSystem)
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

-- Whether the player's employee has a power (the power step is skipped for one without).
local function hasPower(player: Player): boolean
	local character = player.Character
	local name = if character ~= nil then character:GetAttribute(EmployeeConstants.NAME_ATTRIBUTE) else nil
	return type(name) == "string" and AbilityRegistry.forEmployee(name) ~= nil
end

local TrainingRunSystem = {}

function TrainingRunSystem.new(
	player: Player,
	model: Model,
	plan: TrainingMapRules.Plan,
	finished: (player: Player) -> ()
): Run
	local state = TrainingStopRules.new()
	local steps = TrainingStepRules.new(hasPower(player))
	-- The power button was pressed since the last step tick.
	local pressed = false
	-- The treasure kinds to load, by stop.
	local treasures: { [number]: string } = {}
	local harlow = TrainingHarlowSystem.new(player, model, plan)
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
		StateSyncWorldStore.set(TrainingConstants.STEP_ENTRY, TrainingStepRules.current(steps) or "done")
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

	local function atEscape(): boolean
		local def = TrainingConstants.STOPS[state.stop]
		return def ~= nil and def.goal == "escape"
	end

	-- The escape stop: his pass ending clean completes it (and tells the client he is gone).
	local function escapePoll()
		harlow:poll()
		if atEscape() and not TrainingStopRules.isDone(state, state.stop) and harlow:clean() then
			local at = state.stop
			complete(at, "escape")
			StateSyncWorldStore.set(TrainingConstants.CLEAR_ENTRY, at)
		end
	end

	-- The stops with steps: their piles were cleared (`cleared`) and their steps are all done.
	local function stepsDone()
		if not TrainingStepRules.done(steps) then
			return
		end
		for stop, def in TrainingConstants.STOPS do
			if def.steps == true then
				complete(stop, "piles")
			end
		end
	end

	local function stepTick(dt: number)
		local fired = pressed
		pressed = false
		local moved = TrainingStepRules.tick(steps, {
			dt = dt,
			sprinting = SprintServiceServer:isSprinting(player),
			readyAt = AbilityServiceServer:readyAt(player),
			pressed = fired,
			now = Workspace:GetServerTimeNow(),
		})
		if moved then
			publish()
			stepsDone()
		end
	end

	local function poll(dt: number)
		stepTick(dt)
		escapePoll()
		local root = rootOf()
		if root == nil then
			return
		end
		local zone = plan.zones[state.stop + 1]
		if zone == nil or not TrainingMapRules.inside(zone, root.Position) then
			return
		end
		if TrainingStopRules.enter(state, state.stop + 1) then
			if atEscape() then
				harlow:begin()
			end
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
					local def = TrainingConstants.STOPS[stop]
					if def ~= nil and def.steps == true then
						-- Its steps start now (with the power the player's employee has now).
						if TrainingStepRules.current(steps) == "gloom" then
							steps = TrainingStepRules.new(hasPower(player))
							TrainingStepRules.cleared(steps)
							publish()
							stepsDone()
						end
					else
						complete(stop, "piles")
					end
				end
			end
		end
	end)
	table.insert(stoppers, function()
		clearing:Disconnect()
	end)

	local pressing = AbilityServiceServer.pressed:Connect(function(who: Player)
		if who == player then
			pressed = true
		end
	end)
	-- A treasure counts once the truck takes it (its kind in a Load by this player), never when it is picked up.
	local banking = CargoServiceServer.banked:Connect(function(banker: Player, deposit)
		if banker ~= player or stopped then
			return
		end
		for stop, kind in treasures do
			for _, item in deposit.items do
				if item.kind == kind then
					complete(stop, "banked")
				end
			end
		end
	end)
	table.insert(stoppers, function()
		pressing:Disconnect()
		banking:Disconnect()
	end)

	local catching = ShiftServiceServer.caught:Connect(function(caught: Player, livesLeft: number)
		if caught ~= player or stopped then
			return
		end
		-- The catch's only message on a training run (OccupantCatchUtils.feedback leaves it to training): the beat.
		TrainingEvents.packets.Caught.sendTo(math.clamp(livesLeft, 0, 255), player)
		local back: CFrame? = plan.stops[state.stop]
		-- Caught at the escape stop: he comes round again once he has left.
		if atEscape() then
			harlow:caught()
		end
		task.delay(TrainingConstants.RETURN_DELAY, function()
			local character = player.Character
			if not stopped and back ~= nil and character ~= nil and character.Parent ~= nil then
				character:PivotTo(back * CFrame.new(0, 3, 0))
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
		local dt = elapsed
		elapsed = 0
		poll(dt)
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
					local kind = item.part:GetAttribute(CarryConstants.KIND_ATTRIBUTE)
					if type(kind) == "string" then
						treasures[item.stop] = kind
					else
						log:warn(`treasure {item.part:GetFullName()} has no cargo kind: its stop cannot be banked`)
					end
				end
			end
		end,

		stop = function(_self)
			stopped = true
			harlow:stop()
			for _, stopper in stoppers do
				stopper()
			end
			table.clear(stoppers)
			StateSyncWorldStore.clear(TrainingConstants.WORLD_ENTRY)
			StateSyncWorldStore.clear(TrainingConstants.CLEAR_ENTRY)
			StateSyncWorldStore.clear(TrainingConstants.STEP_ENTRY)
		end,

		state = function(_self)
			return state
		end,
	}
	return run
end

return TrainingRunSystem
