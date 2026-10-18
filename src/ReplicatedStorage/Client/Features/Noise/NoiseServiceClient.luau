--!strict
--[=[
	NoiseServiceClient: the ripple ring (Cleanup Crew spec §7: "any noise: faint ripple ring on the floor at the
	radius Harlow hears it"). Each `Ripple` becomes a thin, pale ring lying on the floor under the noise: a
	CylinderHandleAdornment with an inner radius, on an invisible anchor, that spreads out to the heard radius,
	thins and fades (NoiseRippleFormulas), driven every frame until it is gone. Ripples whose ring stays far from
	the camera are not drawn. Client-local instances (never replicated).

	Spec-exempt shell (Instances, raycasts, RunService); the ring's shape over time is the specced
	NoiseRippleFormulas.

	@class NoiseServiceClient
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local NoiseConstants = require(ReplicatedStorage.Shared.Features.Noise.Data.NoiseConstants)
local NoiseEvents = require(ReplicatedStorage.Shared.Features.Noise.Net.NoiseEvents)
local NoiseRippleFormulas = require(ReplicatedStorage.Client.Features.Noise.Utils.NoiseRippleFormulas)

type Ripple = {
	anchor: Part,
	ring: CylinderHandleAdornment,
	radius: number,
	started: number,
}

local ripples: { Ripple } = {}
local stoppers: { () -> () } = {}
local counters = { drawn = 0, skipped = 0 }

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

local function shape(ring: CylinderHandleAdornment, radius: number, alpha: number)
	local frame = NoiseRippleFormulas.ring(radius, alpha)
	-- Radius before InnerRadius when growing, so the inner never exceeds the outer for a frame.
	ring.Radius = frame.outer
	ring.InnerRadius = frame.inner
	ring.Transparency = frame.transparency
end

local function draw(position: Vector3, radius: number)
	local camera = Workspace.CurrentCamera
	if camera == nil or not NoiseRippleFormulas.shown(camera.CFrame.Position, position, radius) then
		counters.skipped += 1
		return
	end
	local floor = floorBelow(position)
	local anchor = Instance.new("Part")
	anchor.Name = NoiseConstants.RIPPLE_NAME
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(floor + Vector3.new(0, NoiseConstants.RIPPLE_LIFT, 0))
	anchor.Parent = Workspace
	local ring = Instance.new("CylinderHandleAdornment")
	ring.Adornee = anchor
	-- A handle cylinder's axis is its Z: tip it up so the ring lies flat on the floor.
	ring.CFrame = CFrame.Angles(math.rad(90), 0, 0)
	ring.Height = NoiseConstants.RIPPLE_HEIGHT
	ring.Color3 = NoiseConstants.RIPPLE_COLOR
	ring.AlwaysOnTop = false
	shape(ring, radius, 0)
	ring.Parent = anchor
	table.insert(ripples, { anchor = anchor, ring = ring, radius = radius, started = os.clock() })
	counters.drawn += 1
end

local function step()
	local now = os.clock()
	for index = #ripples, 1, -1 do
		local ripple = ripples[index]
		local alpha = (now - ripple.started) / NoiseConstants.RIPPLE_SECONDS
		if alpha >= 1 then
			ripple.anchor:Destroy()
			table.remove(ripples, index)
		else
			shape(ripple.ring, ripple.radius, alpha)
		end
	end
end

export type NoiseClientState = {
	live: number,
	drawn: number,
	skipped: number,
}

export type NoiseServiceClient = {
	dependencies: { string },
	start: (self: NoiseServiceClient) -> (),
	stop: (self: NoiseServiceClient) -> (),
	getState: (self: NoiseServiceClient) -> NoiseClientState,
}

local NoiseServiceClient: NoiseServiceClient = {
	dependencies = {},

	start = function(_self)
		table.insert(
			stoppers,
			NoiseEvents.packets.Ripple.listen(function(data)
				draw(data.position, data.radius)
			end)
		)
		local connection = RunService.RenderStepped:Connect(function(_deltaTime: number)
			step()
		end)
		table.insert(stoppers, function()
			connection:Disconnect()
		end)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
		for _, ripple in ripples do
			ripple.anchor:Destroy()
		end
		table.clear(ripples)
	end,

	getState = function(_self)
		return { live = #ripples, drawn = counters.drawn, skipped = counters.skipped }
	end,
}

return NoiseServiceClient
