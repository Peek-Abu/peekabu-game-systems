--!strict
--[=[
	OccupantPerchSpotTracker: every perch part's spot, measured on the map once per part (split out of
	OccupantWatchSystem, which reports the perches and whether a crew camera sees them; OccupantPerchRules decides).
	The props never move during a run, so a part's spot is kept (weakly, by the part) after its first `measure`.

	@class OccupantPerchSpotTracker
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local OccupantConstants = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)
local OccupantTypes = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantTypes)
local OccupantPerchRules = require(ServerScriptService.Features.Occupant.Rules.OccupantPerchRules)

-- The rig as `measure` reads it (OccupantWatchSystem.Rig carries more).
export type Rig = { model: Model }

local OccupantPerchSpotTracker = {}

-- Every perch part's spot, as measured on the map, once per part (the props never move during a run).
local measured: { [BasePart]: OccupantTypes.Perch } = {}
setmetatable(measured, { __mode = "k" })

-- How far up a ceiling is looked for; the heights over the top a landing's line out runs (just over the top surface,
-- where his tucked feet start, and about his body), and the radius of those lines; how far down a floor is looked for;
-- and how high over the top his body sits (for sight checks and distances). The low line rules out a landing along a
-- bank of props: Shift run 11-14, a drop along the lockers passed just over the next locker's top (its hitbox stands
-- 0.26 over the visible top he sits on).
local CEILING_LOOK = 60
local LANDING_RADIUS = 1.2
local LANDING_LINE_HEIGHTS = { LANDING_RADIUS + 0.05, 2 }
local FLOOR_LOOK = 40
local BODY_UP = 2

--[=[
	Measures the perch spot of `instance` (a PERCH_TAG part, a child of its prop's proxy): the centre of the prop's
	visible top (its ArtVisual's box, else the proxy's: the owner's play-check 11-14 had him floating over the hitbox),
	the room over it to the ceiling, and its landings: each OccupantPerchRules.landingCandidate PERCH_LANDING_OUT past
	the prop's edge with clear, body-wide lines out to it from just over the top and higher, and a floor under it, lower
	than the top
	(so the drop never passes through a wall or lands on another prop). Rays skip the prop itself, the rigs and the crew.
]=]
function OccupantPerchSpotTracker.measure(instance: BasePart, rig: Rig): OccupantTypes.Perch
	local known = measured[instance]
	if known ~= nil then
		return known
	end
	local proxy = instance.Parent
	local exclude: { Instance } = { rig.model }
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character ~= nil then
			table.insert(exclude, character)
		end
	end
	local frame, size = instance.CFrame, instance.Size
	if proxy ~= nil and proxy:IsA("BasePart") then
		table.insert(exclude, proxy)
		frame, size = proxy.CFrame, proxy.Size
		local visual = proxy:FindFirstChild("ArtVisual")
		if visual ~= nil and visual:IsA("Model") then
			frame, size = visual:GetBoundingBox()
		end
	end
	local top = (frame * CFrame.new(0, size.Y / 2, 0)).Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	local up = Workspace:Raycast(top + Vector3.new(0, 0.05, 0), Vector3.new(0, CEILING_LOOK, 0), params)
	local landings: { Vector3 } = {}
	local reach = math.max(size.X, size.Z) / 2 + OccupantConstants.PERCH_LANDING_OUT
	for _, spot in OccupantPerchRules.landingCandidates(top, reach) do
		local out = (spot - top) * Vector3.new(1, 0, 1)
		local clear = true
		for _, height in LANDING_LINE_HEIGHTS do
			if Workspace:Spherecast(top + Vector3.new(0, height, 0), LANDING_RADIUS, out, params) ~= nil then
				clear = false
				break
			end
		end
		if not clear then
			continue
		end
		local floor = Workspace:Raycast(spot + Vector3.new(0, 2, 0), Vector3.new(0, -FLOOR_LOOK, 0), params)
		if floor ~= nil and floor.Position.Y < top.Y - 1 then
			table.insert(landings, floor.Position)
		end
	end
	local perch: OccupantTypes.Perch = {
		id = instance:GetFullName(),
		top = top,
		at = top + Vector3.new(0, BODY_UP, 0),
		headroom = if up ~= nil then up.Position.Y - top.Y else math.huge,
		landings = landings,
	}
	measured[instance] = perch
	return perch
end

return OccupantPerchSpotTracker
