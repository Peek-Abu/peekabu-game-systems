--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local HideServiceServer = require(game:GetService("ServerScriptService").Features.Hide.HideServiceServer)
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
export type World = {
	resting: boolean,
	route: { Vector3 },
	restPoint: Vector3,
	zone: Types.Zone,
	bay: Types.Zone?,
}
-- Marks who in `list` hides (Hide) and whether he saw them go in. Returns `list`.
function System.markHidden(list: { Types.Glimpse }): { Types.Glimpse }
	for _, glimpse in list do
		local player = Players:GetPlayerByUserId(glimpse.userId)
		if player ~= nil and HideServiceServer:isHidden(player) then
			glimpse.hidden = true
			glimpse.seen = HideServiceServer:seenEntering(player)
		end
	end
	return list
end
-- Whether `userId` is in his view in `list`: a clear ray, or hidden where he saw them go in (he knows where they are).
function System.inView(list: { Types.Glimpse }, userId: number): boolean
	for _, glimpse in list do
		if glimpse.userId == userId then
			return glimpse.clear or (glimpse.hidden == true and glimpse.seen == true)
		end
	end
	return false
end
-- What he senses now (no noise yet): from his root and head, his sight, the glimpses and the world he walks.
function System.senses(
	rig: { root: BasePart, head: BasePart },
	sight: { sightRange: number, sightAngle: number },
	now: number,
	players: { Types.Glimpse },
	world: World
): Types.Senses
	return {
		position = rig.root.Position,
		reachTopY = rig.head.Position.Y + rig.head.Size.Y / 2,
		look = rig.root.CFrame.LookVector,
		now = now,
		sightRange = sight.sightRange,
		sightAngle = sight.sightAngle,
		players = players,
		heard = nil,
		resting = world.resting,
		route = world.route,
		restPoint = world.restPoint,
		zone = world.zone,
		bay = world.bay,
	}
end
return System
