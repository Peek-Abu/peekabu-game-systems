--!strict
--[=[
	TrainingRules: the "training" account slice (whether the player has finished training, how many runs they have
	finished, and whether the hub has shown its after-training tour) and what it means. A player is new until they finish training (owner, 11-06); the first finish pays
	the one-time reward.

	@class TrainingRules
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataTypes = require(ReplicatedStorage.Shared.Data.PlayerDataTypes)

local TrainingRules = {}

--[=[
	A new player's slice.
]=]
function TrainingRules.fresh(): PlayerDataTypes.Training
	return { finished = false, runs = 0, toured = false }
end

--[=[
	The data layer's validator: `finished` and `toured` are booleans, `runs` a whole number >= 0, a finished slice
	has at least one run, and only a finished slice is toured.
]=]
function TrainingRules.validate(value: PlayerDataTypes.Training?): (boolean, string?)
	if value == nil or type(value) ~= "table" then
		return false, "training must be a table"
	end
	if type(value.finished) ~= "boolean" or type(value.toured) ~= "boolean" then
		return false, "training.finished and training.toured must be booleans"
	end
	local runs = value.runs
	if type(runs) ~= "number" or runs < 0 or runs % 1 ~= 0 then
		return false, "training.runs must be a whole number >= 0"
	end
	if value.finished and runs < 1 then
		return false, "a finished training needs a run"
	end
	if value.toured and not value.finished then
		return false, "the tour comes after training"
	end
	return true
end

--[=[
	Whether the player still needs training. A slice not loaded yet counts as not new, so no arrow or spotlight shows
	before the save is known.
]=]
function TrainingRules.isNew(value: PlayerDataTypes.Training?): boolean
	return value ~= nil and not value.finished
end

--[=[
	Whether the hub offers training at all: only when the place holds exactly one Training map (a Model tagged
	TrainingConstants.MAP_TAG). The map is built into both places together, so a place published before it lands
	shows no Training pad rather than one that cannot start a run.
]=]
function TrainingRules.offered(maps: number): boolean
	return maps == 1
end

--[=[
	Records a finished run in place. True when this is the first finish (the reward is due).
]=]
function TrainingRules.finish(value: PlayerDataTypes.Training): boolean
	local first = not value.finished
	value.finished = true
	value.runs += 1
	return first
end

--[=[
	Marks the hub's after-training tour shown, in place. True when it is due now (training finished, tour not shown).
]=]
function TrainingRules.tour(value: PlayerDataTypes.Training): boolean
	if not value.finished or value.toured then
		return false
	end
	value.toured = true
	return true
end

return TrainingRules
