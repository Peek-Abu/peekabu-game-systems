--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local NpcService = require(ServerScriptService.Features.Npc.NpcServiceServer)

-- How far in front of the executor the NPC appears (studs).
local SPAWN_DISTANCE = 10

return function(context, kind: string)
	local executor: Player? = context and context.Executor
	local character = if executor ~= nil then executor.Character else nil
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return "You need a character to spawn an NPC in front of."
	end
	local at = root.CFrame * CFrame.new(0, 0, -SPAWN_DISTANCE)
	local model, reason = NpcService:spawn(kind, at * CFrame.Angles(0, math.pi, 0))
	if model == nil then
		return `Could not spawn "{kind}": {reason or "unknown reason"}.`
	end
	return `Spawned "{kind}".`
end
