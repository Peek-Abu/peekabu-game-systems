--!strict
--[=[
	TrainingHubSystem: training in the hub on this client.

	- Every Training pad (TrainingConstants.TRUCK_TAG, made a queue pad by the server only while the place offers
	  training) carries a sign: gold "New here? Start training!" while this
	  player still needs training, plain "TRAINING" once they have done it (anyone can play it again).
	- A player who still needs training gets an arrow to the nearest Training pad (a world spotlight step) until they
	  step on one or finish training.
	- "Play training again" from the Guide (`again`): an arrow to the Training pad.
	- The gold chevron trail on the floor from the player to the nearest Training pad (TrainingTrailSystem's hub
	  goal): while this player still needs training, and after "Play training again" for AGAIN_TRAIL_SECONDS; never
	  while they stand on a pad (TrainingRules.hubTrail).
	- The after-training tour (`tour`, sent once by the server): the Shop button spotlighted with the 100 Gleam line,
	  then an arrow to the real trucks until they step on one.

	Spec-exempt shell (CollectionService, the character, the spotlight); the decisions are the specced TrainingRules.

	@class TrainingHubSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local QueueConstants = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueConstants)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local TrainingRules = require(ReplicatedStorage.Shared.Features.Training.Rules.TrainingRules)
local TrainingSignSystem = require(ReplicatedStorage.Client.Features.Training.Systems.TrainingSignSystem)
local TrainingSpotlightSystem = require(ReplicatedStorage.Client.Features.Training.Systems.TrainingSpotlightSystem)
local TrainingTrailSystem = require(ReplicatedStorage.Client.Features.Training.Systems.TrainingTrailSystem)

local SIGN_LIFT = 7
-- How far over a pad's edge, and above it, still counts as standing on it.
local PAD_SLACK = 1.5
local PAD_HEIGHT = 8
-- How often the hub trail checks whether to show and where the nearest pad is (seconds).
local TRAIL_SECONDS = 0.2

local pads: { [BasePart]: true } = {}
local connections: { RBXScriptConnection } = {}
local isNew = false
local pointed = false
-- "Play training again": the trail leads to the pad until this clock time (nil: not asked).
local againUntil: number? = nil
local trailClock = 0

-- A Training pad the server made a queue pad (it does so only while the place offers training).
local function isTrainingPad(part: BasePart): boolean
	return CollectionService:HasTag(part, TrainingConstants.TRUCK_TAG)
		and CollectionService:HasTag(part, QueueConstants.TAG)
end

local function standingOn(accept: (BasePart) -> boolean): boolean
	local character = Players.LocalPlayer.Character
	if character == nil then
		return false
	end
	local position = character:GetPivot().Position
	for _, tagged in CollectionService:GetTagged(QueueConstants.TAG) do
		if tagged:IsA("BasePart") and accept(tagged) then
			local offset = tagged.CFrame:PointToObjectSpace(position)
			local half = tagged.Size / 2
			if
				math.abs(offset.X) <= half.X + PAD_SLACK
				and math.abs(offset.Z) <= half.Z + PAD_SLACK
				and offset.Y >= -1
				and offset.Y <= PAD_HEIGHT
			then
				return true
			end
		end
	end
	return false
end

-- The top of the Training pad nearest the player.
local function nearestPadTop(): Vector3?
	local character = Players.LocalPlayer.Character
	if character == nil then
		return nil
	end
	local from = character:GetPivot().Position
	local best: BasePart? = nil
	local bestDistance = math.huge
	for pad in pads do
		local distance = (pad.Position - from).Magnitude
		if distance < bestDistance then
			best, bestDistance = pad, distance
		end
	end
	return if best ~= nil then best.Position + Vector3.new(0, best.Size.Y / 2, 0) else nil
end

local function trailTick(deltaTime: number)
	trailClock += deltaTime
	if trailClock < TRAIL_SECONDS then
		return
	end
	trailClock = 0
	local onPad = standingOn(isTrainingPad)
	if onPad then
		-- Reached: "Play training again" is answered, so stepping off does not bring the trail back.
		againUntil = nil
	end
	local show = next(pads) ~= nil and TrainingRules.hubTrail(isNew, againUntil, os.clock(), onPad)
	TrainingTrailSystem.setHub(if show then nearestPadTop() else nil)
end

local function sign(pad: BasePart)
	TrainingSignSystem.show(pad, {
		text = if isNew then TrainingConstants.TEXT.truckSign else TrainingConstants.TEXT.truckTag,
		number = nil,
		active = isNew,
	}, SIGN_LIFT)
end

local function pointToTraining()
	if not isNew or pointed or next(pads) == nil or TrainingSpotlightSystem.active() then
		return
	end
	pointed = true
	TrainingSpotlightSystem.point({
		{
			kind = "world",
			tag = TrainingConstants.TRUCK_TAG,
			line = TrainingConstants.TEXT.truckSign,
			seconds = math.huge,
			accept = isTrainingPad,
			done = function()
				return not isNew or standingOn(isTrainingPad)
			end,
		},
	})
end

local function added(instance: Instance)
	if instance:IsA("BasePart") and isTrainingPad(instance) and pads[instance] == nil then
		pads[instance] = true
		sign(instance)
		pointToTraining()
	end
end

local TrainingHubSystem = {}

function TrainingHubSystem.start()
	if #connections > 0 then
		return
	end
	-- A pad counts once it carries both tags, whichever arrives last.
	table.insert(connections, CollectionService:GetInstanceAddedSignal(TrainingConstants.TRUCK_TAG):Connect(added))
	table.insert(connections, CollectionService:GetInstanceAddedSignal(QueueConstants.TAG):Connect(added))
	table.insert(
		connections,
		CollectionService:GetInstanceRemovedSignal(TrainingConstants.TRUCK_TAG):Connect(function(instance: Instance)
			if instance:IsA("BasePart") then
				pads[instance] = nil
				TrainingSignSystem.hide(instance)
			end
		end)
	)
	for _, instance in CollectionService:GetTagged(TrainingConstants.TRUCK_TAG) do
		added(instance)
	end
	trailClock = TRAIL_SECONDS
	table.insert(connections, RunService.Heartbeat:Connect(trailTick))
end

--[=[
	Whether this player still needs training changed (their save loaded, or they finished it).
]=]
function TrainingHubSystem.setNew(next: boolean)
	if next == isNew then
		return
	end
	isNew = next
	for pad in pads do
		sign(pad)
	end
	pointToTraining()
end

--[=[
	The after-training tour: the Shop, then the trucks.
]=]
function TrainingHubSystem.tour()
	TrainingSpotlightSystem.point({
		{ kind = "gui", tag = TrainingConstants.SPOTLIGHT_TAGS.shop, line = TrainingConstants.TEXT.tourShop },
		{
			kind = "world",
			tag = QueueConstants.TAG,
			line = TrainingConstants.TEXT.tourTrucks,
			seconds = 25,
			accept = function(part: BasePart)
				return not isTrainingPad(part)
			end,
			done = function()
				return standingOn(function(part: BasePart)
					return not isTrainingPad(part)
				end)
			end,
		},
	})
end

--[=[
	Whether this hub has a Training pad (the place offers training).
]=]
function TrainingHubSystem.offered(): boolean
	return next(pads) ~= nil
end

--[=[
	"Play training again" (the Guide): an arrow to the nearest Training pad until the player steps on it, and the
	chevron trail to it for AGAIN_TRAIL_SECONDS (or until they step on it).
]=]
function TrainingHubSystem.again()
	againUntil = os.clock() + TrainingConstants.AGAIN_TRAIL_SECONDS
	TrainingSpotlightSystem.point({
		{
			kind = "world",
			tag = TrainingConstants.TRUCK_TAG,
			line = TrainingConstants.TEXT.again,
			seconds = 30,
			accept = isTrainingPad,
			done = function()
				return standingOn(isTrainingPad)
			end,
		},
	})
end

function TrainingHubSystem.stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	for pad in pads do
		TrainingSignSystem.hide(pad)
	end
	table.clear(pads)
	pointed = false
	againUntil = nil
	TrainingTrailSystem.setHub(nil)
end

return TrainingHubSystem
