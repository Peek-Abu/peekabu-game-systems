--!strict
--[=[
	TrainingEvents: the ByteNet packet contract for training. The hub server tells a player who just finished training
	to start the after-training spotlight tour (once per account; the "training" slice's `toured`), and a player whose
	first run just started to show the hotbar tour (once per account; the tips slice's HOTBAR_TIP).

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
		},
		queries = {},
		structs = {},
	}
end)

return TrainingEvents
