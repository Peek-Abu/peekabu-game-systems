--!strict
--[=[
	SettingEvents: the ByteNet contract for changing settings (client → server only). The payload is
	`unknown` on the wire (the TitleEvents precedent); SettingRules builds it on the client and parses it at
	the server's trust boundary, and the service checks it against the registry.

	Boot-timing note (the AnimationEvents precedent): the client waits for the per-namespace replicated
	value the server creates when IT requires this module (at SettingServiceServer load).

	@class SettingEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "SettingEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local SettingEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- client -> server: set / reset / resetAll (shape: SettingRules.buildSet and friends)
			Request = ByteNet.definePacket({
				value = ByteNet.unknown,
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return SettingEvents
