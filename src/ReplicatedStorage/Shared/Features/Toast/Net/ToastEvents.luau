--!strict
--[=[
	ToastEvents: the ByteNet packet that shows a toast (server to client). Already normalized by the
	server (ToastRules).

	@class ToastEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "ToastEvents"

if not RunService:IsServer() then
	ReplicatedStorage:WaitForChild("BytenetStorage"):WaitForChild(NAMESPACE)
end

local ToastEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			Show = ByteNet.definePacket({
				value = ByteNet.struct({
					text = ByteNet.string,
					style = ByteNet.string,
					duration = ByteNet.float32,
				}),
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return ToastEvents
