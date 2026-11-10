--!strict
--[=[
	CoffeeEvents: the ByteNet packet contract for Coffee for the crew. The client asks to buy a coffee with Gleam (the
	"250 Gleam" choice); the server checks the price and the balance itself (CoffeeRules.affords / payGleam). The
	Robux path is Roblox's purchase prompt, the PA and refusals are server toasts, and the badge reads the
	CoffeeConstants.WORLD_ENTRY world entry, so nothing else is sent.

	Boot-timing note (the AnimationEvents precedent): the client waits for the per-namespace replicated value the
	server creates when IT requires this module (at CoffeeServiceServer load).

	@class CoffeeEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "CoffeeEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local CoffeeEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- Client -> server: buy one coffee (30 minutes) with Gleam. The value carries nothing (always true).
			BuyGleam = ByteNet.definePacket({
				value = ByteNet.bool,
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return CoffeeEvents
