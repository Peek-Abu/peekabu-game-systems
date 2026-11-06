--!strict
--[=[
	OfficeHazardSystem: the yard's parked car with its hazards on blinks on this client. Its corner lights are
	artist-owned (the yard placer, PlaceYardDressing, builds them in the Studio place; Rojo never mounts Workspace): the
	lamp part carries an Attachment named HAZARD_LAMP at each corner, each with a glow ParticleEmitter. This finds them
	by that name under Workspace's HAZARD_ROOT folder (no tag: the place is not re-saved for it), including lamps that
	stream in later, and on ONE Heartbeat for every lamp: lit (OfficeHazardUtils.lit off the server's clock, so every
	corner and every client blink in step) the lamp part turns Neon in HAZARD_ON_COLOR and each emitter puffs one glow;
	dark it goes back to its own material and colour. The emitters' own steady Rate is set to 0 here (client-local),
	so only the blink lights them. Purely visual: nothing is sent or replicated.

	Spec-exempt shell (Instances, RunService); the timing and the lamp test are the specced OfficeHazardUtils.

	@class OfficeHazardSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local OfficeClient = ReplicatedStorage.Client.Features.Office
local OfficeAtmosphereConstants = require(OfficeClient.Data.OfficeAtmosphereConstants)
local OfficeHazardUtils = require(OfficeClient.Utils.OfficeHazardUtils)

export type OfficeHazardState = {
	lamps: number,
	lit: boolean,
}

-- A lamp part (the lens) and what the blink changes on it: its own look, and its corners' emitters with their rates.
type Lens = {
	material: Enum.Material,
	color: Color3,
	rates: { [ParticleEmitter]: number },
}

local LAMP = OfficeAtmosphereConstants.HAZARD_LAMP

local lenses: { [BasePart]: Lens } = {}
local lit = false
local connections: { RBXScriptConnection } = {}

local function show(part: BasePart, lens: Lens, on: boolean)
	if on then
		part.Material = Enum.Material.Neon
		part.Color = OfficeAtmosphereConstants.HAZARD_ON_COLOR
		for emitter in lens.rates do
			emitter:Emit(1)
		end
	else
		part.Material = lens.material
		part.Color = lens.color
	end
end

-- The emitters on the lens's lamps, each taken off its steady rate once (the blink puffs them instead).
local function collect(part: BasePart, lens: Lens)
	for _, child in part:GetChildren() do
		if OfficeHazardUtils.isLamp(child, LAMP) then
			for _, emitter in child:GetChildren() do
				if emitter:IsA("ParticleEmitter") and lens.rates[emitter] == nil then
					lens.rates[emitter] = emitter.Rate
					emitter.Rate = 0
				end
			end
		end
	end
end

-- Tracks the lamp part `part` (once), picking up any corner emitter that arrived since.
local function track(part: BasePart)
	local lens = lenses[part]
	if lens == nil then
		lens = { material = part.Material, color = part.Color, rates = {} }
		lenses[part] = lens
		collect(part, lens)
		show(part, lens, lit)
		return
	end
	collect(part, lens)
end

-- Any instance that arrives under the yard: a lamp, or an emitter on one, tracks its lamp part.
local function consider(instance: Instance)
	local lamp = if instance:IsA("ParticleEmitter") then instance.Parent else instance
	if lamp == nil or not OfficeHazardUtils.isLamp(lamp, LAMP) then
		return
	end
	local part = lamp.Parent
	if part ~= nil and part:IsA("BasePart") then
		track(part)
	end
end

local function watch(root: Instance)
	for _, descendant in root:GetDescendants() do
		consider(descendant)
	end
	table.insert(connections, root.DescendantAdded:Connect(consider))
	table.insert(
		connections,
		root.DescendantRemoving:Connect(function(instance: Instance)
			if instance:IsA("BasePart") then
				lenses[instance] = nil
			end
		end)
	)
end

local function step()
	local now = OfficeHazardUtils.lit(
		Workspace:GetServerTimeNow(),
		OfficeAtmosphereConstants.HAZARD_PERIOD,
		OfficeAtmosphereConstants.HAZARD_ON_SECONDS
	)
	if now == lit then
		return
	end
	lit = now
	for part, lens in lenses do
		show(part, lens, now)
	end
end

local OfficeHazardSystem = {}

function OfficeHazardSystem.start()
	if #connections > 0 then
		return
	end
	local root = Workspace:FindFirstChild(OfficeAtmosphereConstants.HAZARD_ROOT)
	if root ~= nil then
		watch(root)
	else
		local waiting: RBXScriptConnection? = nil
		waiting = Workspace.ChildAdded:Connect(function(child: Instance)
			if child.Name == OfficeAtmosphereConstants.HAZARD_ROOT and waiting ~= nil then
				waiting:Disconnect()
				watch(child)
			end
		end)
		if waiting ~= nil then
			table.insert(connections, waiting)
		end
	end
	table.insert(connections, RunService.Heartbeat:Connect(step))
end

-- Stops the blink and gives every lamp back its own look and its emitters their rates.
function OfficeHazardSystem.stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	for part, lens in lenses do
		part.Material = lens.material
		part.Color = lens.color
		for emitter, rate in lens.rates do
			emitter.Rate = rate
		end
	end
	table.clear(lenses)
	lit = false
end

function OfficeHazardSystem.getState(): OfficeHazardState
	local count = 0
	for _ in lenses do
		count += 1
	end
	return { lamps = count, lit = lit }
end

return OfficeHazardSystem
