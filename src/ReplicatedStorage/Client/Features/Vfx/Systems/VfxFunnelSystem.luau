--!strict
--[=[
	VfxFunnelSystem: streams that pour particles from a source into a sink on this client (a VfxBurstRegistry burst
	whose layers have a `rate`).

	`funnel(id)` hands out a stream: an invisible, client-local Part centred on the sink holds the layers as an inward
	sphere-surface emitter whose radius is the sink-to-source distance and whose cap (ShapePartial, around the
	emission direction pointed at the source) just covers the source. So every particle is born at the source and
	converges on the sink as it dies (VfxFormulas.funnelPartial / funnelSpeed). The Part spins about the stream's axis
	with LockedToPart particles, so the stream spirals in. `aim(from, to, radius, strength)` each frame; strength (0..1)
	scales the rate (and graphics quality thins it, VfxFormulas.streamRate) and the spin. Writes to the emitters wait
	for a real change (VfxFormulas.changedBy). `stop()` disables the emitters and pools the Part (VfxEmitterPool) once
	the particles in flight are gone. Beyond the burst's maxDistance from the camera a stream pours nothing.

	Spec-exempt shell (Instances, RunService); the maths and the pool are the specced VfxFormulas and VfxEmitterPool.

	@class VfxFunnelSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local VfxShared = ReplicatedStorage.Shared.Features.Vfx
local VfxTypes = require(VfxShared.Data.VfxTypes)
local VfxConstants = require(VfxShared.Data.VfxConstants)
local VfxBurstRegistry = require(VfxShared.Data.VfxBurstRegistry)
local VfxFormulas = require(VfxShared.Utils.VfxFormulas)
local VfxEmitterPool = require(ReplicatedStorage.Client.Features.Vfx.State.VfxEmitterPool)
local VfxBurstSystem = require(ReplicatedStorage.Client.Features.Vfx.Systems.VfxBurstSystem)

type Burst = VfxTypes.Burst

type FunnelRig = {
	host: Part,
	emitters: { ParticleEmitter },
}

type FunnelState = {
	burst: Burst,
	rig: FunnelRig,
	from: Vector3,
	to: Vector3,
	radius: number,
	strength: number,
	spin: number,
	distance: number,
	partial: number,
	rates: { number },
	stopped: boolean,
}

export type Funnel = {
	aim: (self: Funnel, from: Vector3, to: Vector3, radius: number, strength: number) -> (),
	stop: (self: Funnel) -> (),
}

export type VfxFunnelState = {
	funnels: number,
	idle: number,
	started: number,
}

local pool = VfxEmitterPool.new(VfxConstants.POOL_CAPACITY, function(rig: FunnelRig)
	rig.host:Destroy()
end)
local funnels: { [FunnelState]: boolean } = {}
local started = 0
local connection: RBXScriptConnection? = nil
local localFolder: Folder? = nil

-- The Folder in Workspace holding the hosts (client-local: made on this client, never replicated).
local function folder(): Folder
	local existing = localFolder
	if existing ~= nil and existing.Parent == Workspace then
		return existing
	end
	local made = Instance.new("Folder")
	made.Name = VfxConstants.LOCAL_FOLDER
	made.Parent = Workspace
	localFolder = made
	return made
end

local function build(id: string, burst: Burst): FunnelRig
	local host = Instance.new("Part")
	host.Name = `VfxFunnel_{id}`
	host.Anchored = true
	host.CanCollide = false
	host.CanQuery = false
	host.CanTouch = false
	host.CastShadow = false
	host.Transparency = 1
	host.Size = Vector3.one
	local emitters: { ParticleEmitter } = {}
	for index, layer in burst.layers do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = `Layer{index}`
		VfxBurstSystem.configure(emitter, layer)
		emitter.Shape = Enum.ParticleEmitterShape.Sphere
		emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.LockedToPart = true
		emitter.Enabled = true
		emitter.Parent = host
		table.insert(emitters, emitter)
	end
	host.Parent = folder()
	return { host = host, emitters = emitters }
end

local function stepOne(state: FunnelState, deltaTime: number)
	local rig = state.rig
	local distance = (state.from - state.to).Magnitude
	local camera = Workspace.CurrentCamera
	local seen = if camera ~= nil then (camera.CFrame.Position - state.to).Magnitude else 0
	local far = seen > (state.burst.maxDistance or VfxConstants.DEFAULT_BURST_DISTANCE)
	local strength = if far or distance < 0.5 then 0 else state.strength
	state.spin = (state.spin + deltaTime * VfxConstants.FUNNEL_SPIN * strength) % (math.pi * 2)
	-- +Y (the emission direction, the sphere cap's centre) points from the sink at the source.
	rig.host.CFrame = CFrame.lookAt(state.to, state.from)
		* CFrame.Angles(-math.pi / 2, 0, 0)
		* CFrame.Angles(0, state.spin, 0)
	local threshold = VfxConstants.WRITE_THRESHOLD
	local partial = VfxFormulas.funnelPartial(state.radius, distance)
	if
		VfxFormulas.changedBy(state.distance, distance, threshold)
		or VfxFormulas.changedBy(state.partial, partial, threshold)
	then
		state.distance = distance
		state.partial = partial
		rig.host.Size = Vector3.one * math.max(distance * 2, 0.2)
		for index, layer in state.burst.layers do
			local emitter = rig.emitters[index]
			emitter.Speed = NumberRange.new(VfxFormulas.funnelSpeed(distance, layer.lifetime.Max))
			emitter.ShapePartial = partial
		end
	end
	local level = VfxBurstSystem.quality()
	for index, layer in state.burst.layers do
		local rate = VfxFormulas.streamRate(layer.rate or 0, strength, level)
		if VfxFormulas.changedBy(state.rates[index], rate, threshold) then
			state.rates[index] = rate
			rig.emitters[index].Rate = rate
		end
	end
end

local function step(deltaTime: number)
	for state in funnels do
		stepOne(state, deltaTime)
	end
end

local VfxFunnelSystem = {}

--[=[
	Starts funnel stream `id`: nothing pours until the first `aim`. Nil for an unknown id (VfxBurstSystem.burst warns).
]=]
function VfxFunnelSystem.funnel(id: string): Funnel?
	local burst = VfxBurstSystem.burst(id)
	if burst == nil then
		return nil
	end
	local rig = pool:acquire(id, function()
		return build(id, burst)
	end)
	local rates: { number } = {}
	for index, emitter in rig.emitters do
		emitter.Rate = 0
		emitter.Enabled = true
		rates[index] = 0
	end
	rig.host.Parent = folder()
	local state: FunnelState = {
		burst = burst,
		rig = rig,
		from = rig.host.Position,
		to = rig.host.Position,
		radius = 0,
		strength = 0,
		spin = 0,
		distance = 0,
		partial = 0,
		rates = rates,
		stopped = false,
	}
	funnels[state] = true
	started += 1
	if connection == nil then
		connection = RunService.RenderStepped:Connect(step)
	end
	local handle: Funnel = {
		aim = function(_self, from, to, radius, strength)
			state.from = from
			state.to = to
			state.radius = radius
			state.strength = strength
		end,
		stop = function(_self)
			if state.stopped then
				return
			end
			state.stopped = true
			funnels[state] = nil
			-- Particles in flight finish; the Part goes back to the pool once they are gone.
			for _, emitter in rig.emitters do
				emitter.Enabled = false
			end
			task.delay(VfxBurstRegistry.tail(burst) + 0.1, function()
				if rig.host.Parent ~= nil then
					pool:release(id, rig)
				end
			end)
		end,
	}
	return handle
end

--[=[
	Ends every stream at once (the client shutting down): every host is destroyed and the loop stops.
]=]
function VfxFunnelSystem.stop()
	for state in funnels do
		state.stopped = true
		state.rig.host:Destroy()
	end
	table.clear(funnels)
	pool:clear()
	local current = connection
	if current ~= nil then
		current:Disconnect()
		connection = nil
	end
end

function VfxFunnelSystem.getState(): VfxFunnelState
	local live = 0
	for _ in funnels do
		live += 1
	end
	return { funnels = live, idle = pool:idle(), started = started }
end

return VfxFunnelSystem
