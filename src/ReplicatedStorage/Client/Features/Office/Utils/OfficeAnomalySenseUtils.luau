--!strict
--[=[
	OfficeAnomalySenseUtils: what OfficeAnomalySystem reads from the world about an anomaly slot: its parts by name,
	whether any player is near it (the doors), and whether the silhouette's figure is on screen and in view of this
	client's camera (frustum, SILHOUETTE_RANGE, a ray that passes through at most SEE_THROUGH_HITS see-through parts).
	Reads only; changes nothing.

	Split out of OfficeAnomalySystem.

	@class OfficeAnomalySenseUtils
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local OfficeAnomalyUtils = require(ReplicatedStorage.Client.Features.Office.Utils.OfficeAnomalyUtils)

-- A ray to the figure passes through at most this many see-through parts (glass, invisible walls).
local SEE_THROUGH_HITS = 6

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local OfficeAnomalySenseUtils = {}

--[=[
	Every part under `slot` named `name`.
]=]
function OfficeAnomalySenseUtils.namedParts(slot: Model, name: string): { BasePart }
	local list: { BasePart } = {}
	for _, d in slot:GetDescendants() do
		if d:IsA("BasePart") and d.Name == name then
			table.insert(list, d)
		end
	end
	return list
end

--[=[
	The first part under `slot` named `name`, or nil.
]=]
function OfficeAnomalySenseUtils.firstPart(slot: Model, name: string): BasePart?
	return OfficeAnomalySenseUtils.namedParts(slot, name)[1]
end

-- Whether any player's character is within DOOR_NEAR of the slot.
function OfficeAnomalySenseUtils.someoneNear(slot: Model): boolean
	local centre = slot:GetPivot().Position
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if
			root ~= nil
			and root:IsA("BasePart")
			and (root.Position - centre).Magnitude <= OfficeAnomalyUtils.DOOR_NEAR
		then
			return true
		end
	end
	return false
end

-- A part the eye sees through: it never hides the figure.
function OfficeAnomalySenseUtils.seeThrough(part: BasePart): boolean
	return part.Transparency >= 0.5 or part.Material == Enum.Material.Glass
end

-- The figure against this client's camera: on screen (in the frustum, in front), and in view (on screen, within
-- SILHOUETTE_RANGE and not hidden behind anything solid). A figure not streamed in is off screen.
function OfficeAnomalySenseUtils.views(slot: Model): (boolean, boolean)
	local camera = Workspace.CurrentCamera
	local body = OfficeAnomalySenseUtils.firstPart(slot, "FigureBody")
	if camera == nil or body == nil then
		return false, false
	end
	local point, visible = camera:WorldToViewportPoint(body.Position)
	if not visible or point.Z <= 0 then
		return false, false
	end
	local origin = camera.CFrame.Position
	local offset = body.Position - origin
	if offset.Magnitude > OfficeAnomalyUtils.SILHOUETTE_RANGE then
		return true, false
	end
	local exclude: { Instance } = { slot }
	local character = if Players.LocalPlayer ~= nil then Players.LocalPlayer.Character else nil
	if character ~= nil then
		table.insert(exclude, character)
	end
	for _ = 1, SEE_THROUGH_HITS do
		rayParams.FilterDescendantsInstances = exclude
		local hit = Workspace:Raycast(origin, offset, rayParams)
		if hit == nil then
			return true, true
		end
		local part = hit.Instance
		if not (part:IsA("BasePart") and OfficeAnomalySenseUtils.seeThrough(part)) then
			return true, false
		end
		table.insert(exclude, part)
	end
	return true, false
end

return OfficeAnomalySenseUtils
