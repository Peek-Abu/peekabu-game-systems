--!strict
--[=[
	SkillCheckEvents: the ByteNet packets for the closing-ring skill check. Server -> one client: Ring (a ring the server
	started for that player: id, the opening's centre and width in screen degrees, its arrival on the server clock and
	its travel seconds) and Result (the server's verdict on that ring). Client -> server: Report (the ring's id and the
	icon's angle at its arrival; SkillCheckReportRules checks it at the trust boundary, behind a rate-limited
	RequestHandler).

	@class SkillCheckEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "SkillCheckEvents"

if not RunService:IsServer() then
	local storage = ReplicatedStorage:WaitForChild("BytenetStorage", 5)
	if storage then
		storage:WaitForChild(NAMESPACE, 5)
	else
		warn(`[SkillCheckEvents] BytenetStorage not found after 5s: skill check rings will not arrive`)
	end
end

local SkillCheckEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			Ring = ByteNet.definePacket({
				value = ByteNet.struct({
					id = ByteNet.uint32,
					gap = ByteNet.float32,
					width = ByteNet.float32,
					arriveAt = ByteNet.float64,
					travel = ByteNet.float32,
				}),
				reliabilityType = "reliable",
			}),
			Result = ByteNet.definePacket({
				value = ByteNet.struct({
					id = ByteNet.uint32,
					hit = ByteNet.bool,
				}),
				reliabilityType = "reliable",
			}),
			Report = ByteNet.definePacket({
				value = ByteNet.struct({
					id = ByteNet.uint32,
					angle = ByteNet.float32,
				}),
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return SkillCheckEvents
