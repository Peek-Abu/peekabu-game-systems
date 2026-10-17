--!strict
--[=[
	VacuumVfxSystem: the vacuum's polished particles on this client (VacuumVfxConstants presets, played through
	VfxBurstSystem and VfxFunnelSystem), driven by VacuumFeedbackSystem for every pile and grimy valuable anyone is vacuuming, so every
	player sees them:

	- `stream(target, grime)` — while it is channelled: a funnel of dust and Gloom wisps (grime flakes on a valuable)
	  spiralling from the target into the nearest vacuumer's floor head (`aim`, each frame), its rate and spin rising
	  with the suction's strength (VacuumFeedbackFormulas.suctionStrength); a pile coughs a dust puff each PUFF_STEP of
	  progress (`update`), so it shrinks in puffs. `stop` lets the particles in flight finish.
	- `pop(position, size)` — a pile cleared: the dust ring, the pop, the last Gloom and a few sparkles, scaled by
	  its size (VacuumFeedbackFormulas.popScale).
	- `shine(item)` — a valuable come up spotless: a diagonal shine sweep across it (left to right as this client's
	  camera sees it), a twinkle and the last grime flakes.

	Spec-exempt shell (Camera, VfxBurstSystem, VfxFunnelSystem); the decisions are the specced VacuumFeedbackFormulas.

	@class VacuumVfxSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local VfxBurstRegistry = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxBurstRegistry)
local VacuumVfxConstants = require(ReplicatedStorage.Client.Features.Vacuum.Data.VacuumVfxConstants)
local VacuumFeedbackFormulas = require(ReplicatedStorage.Client.Features.Vacuum.Utils.VacuumFeedbackFormulas)
local VfxBurstSystem = require(ReplicatedStorage.Client.Features.Vfx.Systems.VfxBurstSystem)
local VfxFunnelSystem = require(ReplicatedStorage.Client.Features.Vfx.Systems.VfxFunnelSystem)

export type Stream = {
	update: (self: Stream, progress: number, count: number) -> (),
	aim: (self: Stream, nozzle: Vector3) -> (),
	stop: (self: Stream) -> (),
}

-- Registered at load: VfxBurstSystem refuses an unknown burst.
for id, preset in VacuumVfxConstants.PRESETS do
	if not VfxBurstRegistry.has(id) then
		VfxBurstRegistry.register(id, preset)
	end
end

local function popScaleOf(size: number): number
	return VacuumFeedbackFormulas.popScale(
		size,
		VacuumVfxConstants.REFERENCE_SIZE,
		VacuumVfxConstants.POP_SCALE_MIN,
		VacuumVfxConstants.POP_SCALE_MAX
	)
end

-- Where the stream leaves a target: just above its top, so no particle is born hidden inside it.
local function sourceOf(target: BasePart): Vector3
	return target.Position + Vector3.new(0, target.Size.Y / 2 + 0.15, 0)
end

local VacuumVfxSystem = {}

--[=[
	Starts the suction stream for a pile (or, with `grime`, a grimy valuable). Nil when the stream's burst is missing.
]=]
function VacuumVfxSystem.stream(target: BasePart, grime: boolean): Stream?
	local funnel = VfxFunnelSystem.funnel(if grime then "vacuumGrimeSuction" else "vacuumSuction")
	if funnel == nil then
		return nil
	end
	local lastProgress = 0
	local strength = 0
	local handle: Stream = {
		update = function(_self, progress, count)
			strength = VacuumFeedbackFormulas.suctionStrength(progress, count)
			if
				not grime
				and target.Parent ~= nil
				and VacuumFeedbackFormulas.pastStep(lastProgress, progress, VacuumVfxConstants.PUFF_STEP)
			then
				local size = math.max(target.Size.X, target.Size.Z)
				VfxBurstSystem.play("vacuumPuff", sourceOf(target), { scale = math.clamp(size / 4, 0.5, 1.4) })
			end
			lastProgress = math.max(lastProgress, progress)
		end,
		aim = function(_self, nozzle)
			if target.Parent == nil then
				return
			end
			local radius = math.max(target.Size.X, target.Size.Z) * 0.4
			funnel:aim(sourceOf(target), nozzle, radius, strength)
		end,
		stop = function(_self)
			funnel:stop()
		end,
	}
	return handle
end

--[=[
	A pile cleared at `position`, `size` studs across (its spawned size's magnitude).
]=]
function VacuumVfxSystem.pop(position: Vector3, size: number)
	-- A little above the pile's centre, so the pop ring is not cut by the floor.
	local scale = popScaleOf(size)
	VfxBurstSystem.play("vacuumPop", position + Vector3.new(0, 0.5 * scale, 0), { scale = scale })
end

--[=[
	A grimy valuable come up spotless: the shine sweeps across it as this client's camera sees it.
]=]
function VacuumVfxSystem.shine(item: BasePart)
	local camera = Workspace.CurrentCamera
	if camera == nil or item.Parent == nil then
		return
	end
	local scale = math.clamp(item.Size.Magnitude / 3, 0.6, 1.6)
	local look = camera.CFrame.LookVector
	-- Screen-aligned, then turned so the emission direction (+Y) is the camera's right.
	-- In front of the item as this camera sees it, so the bar sweeps over it rather than through it.
	local front = item.Position - look * (item.Size.Magnitude / 2)
	local facing = CFrame.lookAt(front, front + look) * CFrame.Angles(0, 0, -math.pi / 2)
	-- Start half the sweep's travel (speed x lifetime) to the left, so it crosses the item's centre.
	local start = facing * CFrame.new(0, -1.25 * scale, 0)
	VfxBurstSystem.play("vacuumShine", start, { scale = scale })
	VfxBurstSystem.play("vacuumShineSparkle", item.Position, { scale = scale })
end

return VacuumVfxSystem
