--!strict
--[=[
	NoiseServiceClient: the ripple ring (Cleanup Crew spec §7: "any noise: faint ripple ring on the floor at the
	radius Harlow hears it"). Each `Ripple` becomes a flat neon disc on the floor under the noise that spreads
	to the heard radius and fades. Client-local parts (never replicated). Placeholder look; M3 restyles it.

	Spec-exempt shell (Instances, tweens, raycasts).

	@class NoiseServiceClient
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local NoiseConstants = require(ReplicatedStorage.Shared.Features.Noise.Data.NoiseConstants)
local NoiseEvents = require(ReplicatedStorage.Shared.Features.Noise.Net.NoiseEvents)

local stoppers: { () -> () } = {}
local drawn = 0

-- The floor under a noise (characters and non-colliding parts ignored), or the noise itself.
local function floorBelow(position: Vector3): Vector3
	local ignore: { Instance } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character ~= nil then
			table.insert(ignore, character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local hit =
		Workspace:Raycast(position + Vector3.new(0, 1, 0), Vector3.new(0, -NoiseConstants.FLOOR_PROBE, 0), params)
	return if hit ~= nil then hit.Position else position
end

local function ripple(position: Vector3, radius: number)
	if radius <= 0 then
		return
	end
	local thickness = NoiseConstants.RIPPLE_THICKNESS
	local floor = floorBelow(position)
	local ring = Instance.new("Part")
	ring.Name = NoiseConstants.RIPPLE_NAME
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = NoiseConstants.RIPPLE_COLOR
	ring.Transparency = NoiseConstants.RIPPLE_TRANSPARENCY
	ring.Size = Vector3.new(thickness, 1, 1)
	-- A cylinder's axis is its X: roll it upright so the disc lies flat on the floor.
	ring.CFrame = CFrame.new(floor + Vector3.new(0, thickness / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = Workspace
	local diameter = radius * 2
	local tween = TweenService:Create(
		ring,
		TweenInfo.new(NoiseConstants.RIPPLE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(thickness, diameter, diameter), Transparency = 1 }
	)
	tween.Completed:Once(function()
		ring:Destroy()
	end)
	tween:Play()
	drawn += 1
end

export type NoiseServiceClient = {
	dependencies: { string },
	start: (self: NoiseServiceClient) -> (),
	stop: (self: NoiseServiceClient) -> (),
	getState: (self: NoiseServiceClient) -> { [string]: any },
}

local NoiseServiceClient: NoiseServiceClient = {
	dependencies = {},

	start = function(_self)
		table.insert(
			stoppers,
			NoiseEvents.packets.Ripple.listen(function(data)
				ripple(data.position, data.radius)
			end)
		)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
	end,

	getState = function(_self)
		return { drawn = drawn }
	end,
}

return NoiseServiceClient
