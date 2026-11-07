--!strict
--[=[
	TrainingHubSystem: training in the hub on this client.

	- Every Training pad (TrainingConstants.TRUCK_TAG, made a queue pad by the server only while the place offers
	  training) carries a sign: gold "New here? Start training!" while this
	  player still needs training, plain "TRAINING" once they have done it (anyone can play it again).
	- A player who still needs training gets an arrow to the nearest Training pad (a world spotlight step) until they
	  step on one or finish training.
	- "Play training again" from the Guide (`again`): an arrow to the Training pad.
	- The after-training tour (`tour`, sent once by the server): the Shop button spotlighted with the 100 Gleam line,
	  then an arrow to the real trucks until they step on one.

	Spec-exempt shell (CollectionService, the character, the spotlight); the decisions are the specced TrainingRules.

	@class TrainingHubSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QueueConstants = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueConstants)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local TrainingSignSystem = require(ReplicatedStorage.Client.Features.Training.Systems.TrainingSignSystem)
local TrainingSpotlightSystem = require(ReplicatedStorage.Client.Features.Training.Systems.TrainingSpotlightSystem)

local SIGN_LIFT = 7
-- How far over a pad's edge, and above it, still counts as standing on it.
local PAD_SLACK = 1.5
local PAD_HEIGHT = 8

local pads: { [BasePart]: true } = {}
local connections: { RBXScriptConnection } = {}
local isNew = false
local pointed = false

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
	"Play training again" (the Guide): an arrow to the nearest Training pad until the player steps on it.
]=]
function TrainingHubSystem.again()
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
end

return TrainingHubSystem
