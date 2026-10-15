--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local System = {}
function System.feetY(root: BasePart, humanoid: Humanoid): number
	local legHeight = 0
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		local leg = if root.Parent ~= nil then root.Parent:FindFirstChild("Left Leg") else nil
		if leg ~= nil and leg:IsA("BasePart") then
			legHeight = leg.Size.Y
		end
	end
	return root.Position.Y - humanoid.HipHeight - root.Size.Y / 2 - legHeight
end
function System.glimpses(
	rig: { model: Model, head: BasePart },
	sightRange: number,
	participants: { Player },
	eligible: (Player) -> boolean
): { Types.Glimpse }
	local exclude: { Instance } = { rig.model }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	local list: { Types.Glimpse } = {}
	for _, player in participants do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local h = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if root and root:IsA("BasePart") and h and h.Health > 0 and eligible(player) then
			local offset = root.Position - rig.head.Position
			local clear = offset.Magnitude <= sightRange and Workspace:Raycast(rig.head.Position, offset, params) == nil
			table.insert(
				list,
				{ userId = player.UserId, position = root.Position, feetY = System.feetY(root, h), clear = clear }
			)
		end
	end
	return list
end
return System
