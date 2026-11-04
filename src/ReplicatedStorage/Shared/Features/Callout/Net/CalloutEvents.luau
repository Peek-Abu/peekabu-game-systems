--!strict
--[=[
	CalloutEvents: the ByteNet packets for pings and stickers. Client -> server: a Request (shape:
	CalloutRequestRules.Request, checked at the trust boundary). Server -> every client: Shown (who, which callout,
	and where: a ping's spot, a sticker's when `placed`; CalloutRequestRules.shownPacket / shown).

	@class CalloutEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "CalloutEvents"

if not RunService:IsServer() then
	local storage = ReplicatedStorage:WaitForChild("BytenetStorage", 5)
	if storage then
		storage:WaitForChild(NAMESPACE, 5)
	else
		warn(`[CalloutEvents] BytenetStorage not found after 5s — callouts will not send`)
	end
end

local CalloutEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			Request = ByteNet.definePacket({
				value = ByteNet.unknown,
				reliabilityType = "reliable",
			}),
			Shown = ByteNet.definePacket({
				value = ByteNet.struct({
					userId = ByteNet.float64,
					kind = ByteNet.string,
					id = ByteNet.string,
					x = ByteNet.float32,
					y = ByteNet.float32,
					z = ByteNet.float32,
					placed = ByteNet.bool,
				}),
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return CalloutEvents
