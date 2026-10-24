--!strict
--[=[
	ShopEvents: the ByteNet packets for the Shop. Client → server: buy an offer (a discrete REQUEST). Server →
	client: the result (bought, or why not: owned / short / not on sale / locked during a shift), so the button can
	say so. What was granted rides the charm-sync spine (`entitlements`), and the reveal comes from
	CosmeticEvents.Granted.

	Payloads are `ByteNet.unknown` going up (ShopRequestRules enforces the shape at the trust boundary) and typed
	coming down. Boot timing as CosmeticEvents.

	@class ShopEvents
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ByteNet = require(ReplicatedStorage.Packages.ByteNetMax)

local NAMESPACE = "ShopEvents"

if not RunService:IsServer() then
	local storage = ReplicatedStorage:WaitForChild("BytenetStorage", 5)
	if storage then
		storage:WaitForChild(NAMESPACE, 5)
	else
		warn(`[ShopEvents] BytenetStorage not found after 5s — shop requests will not send`)
	end
end

local ShopEvents = ByteNet.defineNamespace(NAMESPACE, function()
	return {
		packets = {
			-- client -> server: buy an offer (shape: ShopRequestRules.BuyRequest)
			BuyRequest = ByteNet.definePacket({
				value = ByteNet.unknown,
				reliabilityType = "reliable",
			}),
			-- server -> client: how a buy went ("" reason = bought)
			BuyResult = ByteNet.definePacket({
				value = ByteNet.struct({
					offer = ByteNet.string,
					reason = ByteNet.string,
				}),
				reliabilityType = "reliable",
			}),
		},
		queries = {},
		structs = {},
	}
end)

return ShopEvents
