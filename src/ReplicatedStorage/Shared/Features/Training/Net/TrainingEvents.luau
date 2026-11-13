--!strict
--[=[
	TrainingEvents: the ByteNet packet contract for training. The hub server tells a player who just finished training
	to start the after-training spotlight tour (once per account; the "training" slice's `toured`), and a player whose
	first run just started to show the hotbar tour (once per account; the tips slice's HOTBAR_TIP). On a run (tutorial
	v3) it tells the player they were caught (the catch beat: lives left) and that they finished (the finish screen:
	the Gleam paid, 0 for a repeat run); the player answers the finish screen with Back (ride home now) or Again (run
	training again here).

	Boot-timing note (the AnimationEvents precedent): the client waits for the per-namespace replicated value the
	server creates when IT requires this module (at TrainingServiceServer load).

	@class TrainingEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "TrainingEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local TrainingEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- Server -> the owner only: start the after-training tour.
			Tour = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
			-- Server -> the owner only: their first run started, show the hotbar tour (the vacuum, then the power).
			Hotbar = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
			-- Server -> the owner only: a training catch; the value is the lives left (the catch beat).
			Caught = ByteNet.definePacket({
				value = ByteNet.uint8,
				reliabilityType = "reliable",
			}),
			-- Server -> the owner only: the run is finished; the value is the Gleam paid (0 for a repeat run).
			Finish = ByteNet.definePacket({
				value = ByteNet.uint16,
				reliabilityType = "reliable",
			}),
			-- Client -> server: the finish screen's BACK TO THE DEPOT (ride home now).
			Back = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
			-- Client -> server: the hub card's SKIP TRAINING (the server checks the player is still new).
			Skip = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
			-- Client -> server: the finish screen's PLAY AGAIN (run training again on this server).
			Again = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return TrainingEvents
