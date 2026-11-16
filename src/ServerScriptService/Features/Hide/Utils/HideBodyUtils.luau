--!strict
--[=[
	HideBodyUtils: where a hiding body goes, read from the live character and the world (no state, nothing changed).
	Split out of HideServiceServer.

	- `rootOf` / `humanoidOf`: a player's HumanoidRootPart and Humanoid, when there.
	- `standHeight`: the root's height over the feet.
	- `hideFrame`: where the hiding root goes, a desk or table's hug frame from the measured rig (HideHugFormulas),
	  else the spot's standing-height frame.
	- `exitFrame`: the first exit with room for a body, reachable from the furniture's front, else the entry or the
	  front exit.

	@class HideBodyUtils
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local HideShared = ReplicatedStorage.Shared.Features.Hide
local HideConstants = require(HideShared.Data.HideConstants)
local HideTypes = require(HideShared.Data.HideTypes)
local HideHugFormulas = require(HideShared.Utils.HideHugFormulas)
local HideSpotUtils = require(HideShared.Utils.HideSpotUtils)
local HideRigUtils = require(ServerScriptService.Features.Hide.Utils.HideRigUtils)

type Spot = HideTypes.Spot

local HideBodyUtils = {}

function HideBodyUtils.rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

function HideBodyUtils.humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
end

-- The root's height over the feet: where a standing character's root sits.
function HideBodyUtils.standHeight(root: BasePart, humanoid: Humanoid): number
	return humanoid.HipHeight + root.Size.Y / 2
end

-- Where the hiding root goes: a desk or table's hug frame (the posed body on the floor, back to the furniture) from
-- the character's measured rig, else the spot's standing-height frame (a cabinet, or a rig that cannot be measured).
function HideBodyUtils.hideFrame(spot: Spot, character: Model?, fallback: CFrame): CFrame
	local def = HideConstants.FURNITURE[spot.noun]
	local free = if def ~= nil then def.free else nil
	local rig = if character ~= nil and free ~= nil then HideRigUtils.read(character) else nil
	if free == nil or rig == nil then
		return fallback
	end
	local low, high = HideHugFormulas.extents(rig, HideHugFormulas.pose())
	-- No piece was reachable: extents is (inf, -inf).
	if
		low.X == math.huge
		or low.Y == math.huge
		or low.Z == math.huge
		or high.X == -math.huge
		or high.Y == -math.huge
		or high.Z == -math.huge
	then
		return fallback
	end
	return HideHugFormulas.hugFrame(spot.frame, spot.furniture.Size, free, low, high, HideConstants.HUG_BACK_GAP)
end

-- The first exit with room for a body (nothing collidable but the furniture's own parts), else the front one.
function HideBodyUtils.exitFrame(spot: Spot, root: BasePart, humanoid: Humanoid, entry: CFrame?): CFrame
	local frames =
		HideSpotUtils.frames(spot.noun, spot.frame, spot.furniture.Size, HideBodyUtils.standHeight(root, humanoid))
	local exclude: { Instance } = { spot.furniture }
	for _, other in Players:GetPlayers() do
		if other.Character ~= nil then
			table.insert(exclude, other.Character)
		end
	end
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = exclude
	overlap.RespectCanCollide = true
	local rays = RaycastParams.new()
	rays.FilterType = Enum.RaycastFilterType.Exclude
	rays.FilterDescendantsInstances = exclude
	rays.RespectCanCollide = true
	-- The front of the furniture at waist height: an exit must be reachable from it with no wall between.
	local size = spot.furniture.Size
	local mouth = (spot.frame * CFrame.new(0, -size.Y / 2 + 2, -size.Z / 2)).Position
	local function usable(frame: CFrame): boolean
		local at = frame.Position
		-- Room for a body (clear of the floor and its carpet skin), a floor under it, and no wall in the way.
		local body = frame
			* CFrame.new(0, HideConstants.EXIT_PROBE.Y / 2 - HideBodyUtils.standHeight(root, humanoid) + 0.6, 0)
		return #Workspace:GetPartBoundsInBox(body, HideConstants.EXIT_PROBE, overlap) == 0
			and Workspace:Raycast(at, Vector3.new(0, -(HideBodyUtils.standHeight(root, humanoid) + 3), 0), rays) ~= nil
			and Workspace:Raycast(mouth, Vector3.new(at.X, mouth.Y, at.Z) - mouth, rays) == nil
	end
	-- Back where they went in from first, then in front, behind, either side.
	local candidates = table.clone(frames.exits)
	if entry ~= nil then
		table.insert(candidates, 1, entry)
	end
	for _, frame in candidates do
		if usable(frame) then
			return frame
		end
	end
	return entry or frames.exits[1]
end

return HideBodyUtils
