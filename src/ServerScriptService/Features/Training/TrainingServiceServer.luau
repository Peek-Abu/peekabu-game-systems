--!strict
--[=[
	TrainingServiceServer: training (tutorial design v2). It owns the "training" account slice (TrainingRules; synced
	to its owner for the hub's arrow and spotlight).

	- **The hub** (the depot role), only when this place holds the Training map (TrainingRules.offered; the map is
	  built into both places together, so a place published without it shows no pad): every part tagged TrainingConstants.TRUCK_TAG becomes a one-seat queue pad to the
	  shift place that departs with the training mode in its payload (DepotServiceServer adds it). The code-built
	  depot has no such part, so one is made by its left wall (a Studio-built hub tags its own). A player who has just
	  finished training is sent the after-training tour once (TrainingEvents.Tour), when their save loads or they come
	  back from the run.
	- **The run** (the shift role): a party of one arriving with the training mode plays the shift on the Studio-built
	  Training map (TrainingSiteSystem as Office's site, TrainingRunSystem following the stops), with a lives floor of
	  TrainingConstants.LIVES_FLOOR, so a catch never knocks them out, marked as training (no Manager speed-ups; a catch shows training's one line). Finishing records the run and pays REWARD_GLEAM
	  the first time (one transaction), then rides them home. A map that is missing or does not check out sends them
	  straight home with a note, and logs every problem.
	- **The hotbar tour** (the shift role): when a run starts, each player there who has never had it (the tips slice,
	  TipServiceServer:once) is sent TrainingEvents.Hotbar: the spotlight on the vacuum's slot, then the power.

	Spec-exempt shell (the data layer, Queue, Office, Shift, Instances); the decisions are the specced TrainingRules,
	TrainingStopRules and TrainingMapRules.

	@class TrainingServiceServer
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local Observers = require(ReplicatedStorage.Packages.Observers)
local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local QueueConstants = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueConstants)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local TrainingEvents = require(ReplicatedStorage.Shared.Features.Training.Net.TrainingEvents)
local TrainingRules = require(ReplicatedStorage.Shared.Features.Training.Rules.TrainingRules)
local DepotLayoutConstants = require(ServerScriptService.Features.Depot.Data.DepotLayoutConstants)
local MarketplaceServiceServer = require(ServerScriptService.Features.Marketplace.MarketplaceServiceServer)
local OfficeServiceServer = require(ServerScriptService.Features.Office.OfficeServiceServer)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataServiceServer)
local PlayerDataSliceSystem = require(ServerScriptService.Features.PlayerData.Systems.PlayerDataSliceSystem)
local QueueServiceServer = require(ServerScriptService.Features.Queue.QueueServiceServer)
local ShiftServiceServer = require(ServerScriptService.Features.Shift.ShiftServiceServer)
local TipServiceServer = require(ServerScriptService.Features.Tip.TipServiceServer)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)
local TrainingRunSystem = require(ServerScriptService.Features.Training.Systems.TrainingRunSystem)
local TrainingSiteSystem = require(ServerScriptService.Features.Training.Systems.TrainingSiteSystem)

local trainingSlice = PlayerDataSliceSystem.registerAccount("training", TrainingRules.fresh(), function(account)
	return account.training
end, TrainingRules.validate)

local log = Logger.new("TrainingServiceServer")
local counters = { runs = 0, finished = 0, rewarded = 0, tours = 0, refused = 0 }

-- The code-built depot's Training pad: by its left wall, in front of the first truck (local to the depot's origin).
local DEFAULT_PAD = { x = 5.5, z = 30, size = Vector3.new(7, 0.4, 7) }

local stoppers: { () -> () } = {}
-- The run on this server (a training server is one player's reserved server).
local current: { player: Player, run: TrainingRunSystem.Run }? = nil

local function toast(player: Player, text: string)
	ToastServiceServer:send(player, { text = text, style = ShiftConstants.TOAST_STICKY, duration = 4 })
end

-- Makes `pad` a one-seat queue pad to the shift place (attributes before the Queue tag: Queue reads them once).
local function configurePad(pad: BasePart)
	pad:SetAttribute(QueueConstants.CAPACITY_ATTRIBUTE, TrainingConstants.TRUCK_CAPACITY)
	pad:SetAttribute(QueueConstants.COUNTDOWN_ATTRIBUTE, TrainingConstants.TRUCK_COUNTDOWN)
	pad:SetAttribute(QueueConstants.DESTINATION_ATTRIBUTE, DepotConstants.ROLE_SHIFT)
	CollectionService:AddTag(pad, QueueConstants.TAG)
end

local function defaultPad()
	if #CollectionService:GetTagged(TrainingConstants.TRUCK_TAG) > 0 then
		return
	end
	local pad = Instance.new("Part")
	pad.Name = "TrainingPad"
	pad.Anchored = true
	pad.Size = DEFAULT_PAD.size
	pad.CFrame = DepotLayoutConstants.ORIGIN * CFrame.new(DEFAULT_PAD.x, DEFAULT_PAD.size.Y / 2, DEFAULT_PAD.z)
	pad.Material = Enum.Material.Neon
	pad.Color = Color3.fromRGB(120, 230, 190)
	pad.Transparency = 0.35
	pad.CanCollide = false
	CollectionService:AddTag(pad, TrainingConstants.TRUCK_TAG)
	pad.Parent = workspace
	table.insert(stoppers, function()
		pad:Destroy()
	end)
end

-- The after-training tour, once: marked first, so a refused write shows nothing rather than repeating it later.
local function tourIfDue(player: Player)
	local state: PlayerDataTypes.Training? = trainingSlice.get(player.UserId)
	if state == nil or not state.finished or state.toured then
		return
	end
	local due = false
	trainingSlice.mutate(player.UserId, function(slice)
		due = TrainingRules.tour(slice)
		return due
	end)
	if due then
		counters.tours += 1
		TrainingEvents.packets.Tour.sendTo(true, player)
	end
end

-- Records the finished run; the first time, with the Gleam, in one transaction. Yields.
local function record(player: Player)
	local userId = player.UserId
	local state: PlayerDataTypes.Training? = trainingSlice.get(userId)
	if state == nil then
		return
	end
	counters.finished += 1
	if state.finished then
		trainingSlice.mutate(userId, function(slice)
			TrainingRules.finish(slice)
			return true
		end)
		return
	end
	local committed = PlayerDataService:transaction({
		trainingSlice.op(userId, function(slice)
			return TrainingRules.finish(slice)
		end),
		MarketplaceServiceServer:premiumOp(userId, function(premium: PlayerDataTypes.Premium)
			premium.balance += TrainingConstants.REWARD_GLEAM
			return true
		end),
	})
	if committed then
		counters.rewarded += 1
		toast(player, `{TrainingConstants.TEXT.reward} +{TrainingConstants.REWARD_GLEAM} Gleam`)
	end
end

local function home(player: Player)
	if player.Parent == Players then
		QueueServiceServer:returnParty({ player }, DepotConstants.ROLE_DEPOT, {})
	end
end

local function finishRun()
	local run = current
	current = nil
	if run ~= nil then
		run.run:stop()
	end
	OfficeServiceServer:useSite(nil)
	ShiftServiceServer:setLivesFloor(0)
	ShiftServiceServer:setTraining(false)
end

local function begin(player: Player)
	if current ~= nil then
		log:warn(`a training run is already going: {player.Name} is sent home`)
		home(player)
		return
	end
	local model, plan, errors = TrainingSiteSystem.find()
	if model == nil or plan == nil then
		counters.refused += 1
		log:warn(`the Training map is not usable:\n{table.concat(errors, "\n")}`)
		toast(player, TrainingConstants.TEXT.failed)
		task.delay(TrainingConstants.HOME_DELAY, home, player)
		return
	end
	counters.runs += 1
	local run = TrainingRunSystem.new(player, model, plan, function(done: Player)
		task.spawn(record, done)
		task.delay(TrainingConstants.HOME_DELAY, function()
			home(done)
			finishRun()
		end)
	end)
	current = { player = player, run = run }
	OfficeServiceServer:useSite(TrainingSiteSystem.new(model, plan, function(piles, items)
		run:track(piles, items)
	end))
	ShiftServiceServer:setLivesFloor(TrainingConstants.LIVES_FLOOR)
	-- No speed-ups in training (the Manager keeps his first pace), and a catch's feedback is training's one line.
	ShiftServiceServer:setTraining(true)
	log:info(`training for {player.Name}`)
end

export type TrainingServiceServer = {
	dependencies: { string },
	start: (self: TrainingServiceServer) -> (),
	stop: (self: TrainingServiceServer) -> (),
	getState: (self: TrainingServiceServer) -> { [string]: any },
	isNew: (self: TrainingServiceServer, player: Player) -> boolean,
	isTraining: (self: TrainingServiceServer) -> boolean,
}

local TrainingServiceServer: TrainingServiceServer = {
	dependencies = {
		"PlayerDataServiceServer",
		"MarketplaceServiceServer",
		"QueueServiceServer",
		"OfficeServiceServer",
		"ShiftServiceServer",
		"ToastServiceServer",
		"TipServiceServer",
		"StateSyncServiceServer",
		"DepotServiceServer",
	},

	start = function(_self)
		local maps = 0
		for _, tagged in CollectionService:GetTagged(TrainingConstants.MAP_TAG) do
			if tagged:IsA("Model") then
				maps += 1
			end
		end
		local offered = TrainingRules.offered(maps)
		if QueueServiceServer:runsRole(DepotConstants.ROLE_DEPOT) and not offered then
			log:info(`no single Training map in this place ({maps} found): no Training pad`)
		end
		if QueueServiceServer:runsRole(DepotConstants.ROLE_DEPOT) and offered then
			table.insert(
				stoppers,
				Observers.observeTag(TrainingConstants.TRUCK_TAG, function(pad: Instance)
					if pad:IsA("BasePart") then
						configurePad(pad)
					end
					return nil
				end)
			)
			defaultPad()
			local loaded = PlayerDataService.profileLoaded:Connect(function(userId: number)
				local player = Players:GetPlayerByUserId(userId)
				if player ~= nil then
					tourIfDue(player)
				end
			end)
			local returned = QueueServiceServer.returned:Connect(function(player: Player, _payload)
				tourIfDue(player)
			end)
			table.insert(stoppers, function()
				loaded:Disconnect()
				returned:Disconnect()
			end)
		end
		if QueueServiceServer:runsRole(DepotConstants.ROLE_SHIFT) then
			local arrived = QueueServiceServer.arrived:Connect(
				function(party: { Player }, payload: QueueTypes.QueuePayload)
					if payload[TrainingConstants.MODE_KEY] == TrainingConstants.MODE and #party == 1 then
						begin(party[1])
					end
				end
			)
			-- The hotbar tour, once per account, on a player's first run (training's or a shift's).
			local wasRunning = false
			local following = ShiftServiceServer.changed:Connect(function(state: ShiftTypes.ShiftState)
				local running = state.phase == "running"
				if running and not wasRunning then
					task.delay(TrainingConstants.HOTBAR_DELAY, function()
						for _, player in Players:GetPlayers() do
							if TipServiceServer:once(player, TrainingConstants.HOTBAR_TIP) then
								TrainingEvents.packets.Hotbar.sendTo(true, player)
							end
						end
					end)
				end
				wasRunning = running
			end)
			local leaving = Players.PlayerRemoving:Connect(function(player: Player)
				local run = current
				if run ~= nil and run.player == player then
					finishRun()
				end
			end)
			table.insert(stoppers, function()
				arrived:Disconnect()
				following:Disconnect()
				leaving:Disconnect()
			end)
		end
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
		finishRun()
	end,

	--[=[
		Whether `player` still needs training (has not finished it; false while their save is not loaded).
	]=]
	isNew = function(_self, player)
		return TrainingRules.isNew(trainingSlice.get(player.UserId))
	end,

	--[=[
		Whether a training run is going on this server.
	]=]
	isTraining = function(_self)
		return current ~= nil
	end,

	getState = function(_self)
		local run = current
		return {
			counters = table.clone(counters),
			player = if run ~= nil then run.player.Name else nil,
			stop = if run ~= nil then run.run:state().stop else nil,
		}
	end,
}

return TrainingServiceServer
