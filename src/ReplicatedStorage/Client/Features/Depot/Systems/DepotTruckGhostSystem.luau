--!strict
--[=[
	DepotTruckGhostSystem: the hub's truck bays on this client (crew hosting batch 4). Every truck art model tagged
	DepotConstants.TRUCK_ART_TAG whose bed is a held Queue pad (a hosted truck) is drawn from its bed's
	HostConstants.HOST_ATTRIBUTE:

	- no host: a ghost. The art goes GHOST_TRANSPARENCY see-through with a light outline (a Highlight), its opaque
	  camera-shell cores, lights and livery are hidden. The invisible collision stays, so the bay still holds its shape;
	- a host steps in: the truck pops in (DepotTruckPopFormulas: a bounce from START_SCALE and a fade to solid over
	  POP_SECONDS) with a dust puff (DepotTruckPopConstants.PUFF);
	- the bay empties: it fades back to the ghost over LEAVE_SECONDS.

	A truck first seen (joining a server) is drawn in its state at once, without a pop. With StreamingEnabled a truck's
	art can arrive before its bed (the Bed link reads nil until then), and parts stream out and back in with their
	LocalTransparencyModifier reset: so a truck is watched from the moment its art is tagged, its bed is looked up again
	every frame until found (and again if it streams out), and the truck is redrawn whenever parts are added to it. Everything is local (the
	LocalTransparencyModifier, the client-only Highlight and a client-side Model:ScaleTo back to exactly 1), so the
	server's art and its collision never change. Trucks on unheld pads (the office's loading bay) are left alone.

	Spec-exempt shell (Instances, RunService, VfxBurstSystem); the timing and the preset are the specced
	DepotTruckPopFormulas and DepotTruckPopConstants.

	@class DepotTruckGhostSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Observers = require(ReplicatedStorage.Packages.Observers)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local HostConstants = require(ReplicatedStorage.Shared.Features.Host.Data.HostConstants)
local QueueConstants = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueConstants)
local VfxBurstRegistry = require(ReplicatedStorage.Shared.Features.Vfx.Data.VfxBurstRegistry)
local DepotTruckPopConstants = require(ReplicatedStorage.Client.Features.Depot.Data.DepotTruckPopConstants)
local DepotTruckPopFormulas = require(ReplicatedStorage.Client.Features.Depot.Utils.DepotTruckPopFormulas)
local VfxBurstSystem = require(ReplicatedStorage.Client.Features.Vfx.Systems.VfxBurstSystem)

local C = DepotTruckPopConstants

-- Registered at load: VfxBurstSystem refuses an unknown burst.
if not VfxBurstRegistry.has(C.PUFF_ID) then
	VfxBurstRegistry.register(C.PUFF_ID, C.PUFF)
end

type Truck = {
	model: Model,
	-- nil until the bed has streamed in (and again while it is streamed out).
	bed: BasePart?,
	-- Made once the truck is known to be a hub truck (its bed is a held pad).
	highlight: Highlight?,
	-- Parts streamed in since the last draw: redraw at rest.
	dirty: boolean,
	-- nil until first drawn; then whether it is drawn parked (hosted).
	parked: boolean?,
	-- The running pop or fade: when it began (os.clock) and which way.
	since: number?,
	arriving: boolean,
}

local trucks: { [Model]: Truck } = {}
local stopObserving: (() -> ())? = nil
local ticking: RBXScriptConnection? = nil

local function bedOf(model: Model): BasePart?
	local link = model:FindFirstChild(DepotConstants.TRUCK_BED_LINK)
	local bed = if link ~= nil and link:IsA("ObjectValue") then link.Value else nil
	return if bed ~= nil and bed:IsA("BasePart") then bed else nil
end

local function showLivery(gui: SurfaceGui, shown: boolean)
	gui.Enabled = shown
end

-- Draws `truck` (its bed `bed`, its outline `highlight`) at art transparency `transparency` (0 solid .. GHOST) and
-- pop scale `scale`.
local function draw(truck: Truck, bed: BasePart, highlight: Highlight, transparency: number, scale: number)
	local solid = transparency <= 0
	local ghost = transparency >= C.GHOST_TRANSPARENCY - 1e-3
	-- The lamp, the scanner glow and the livery only show on a truck that is (nearly) there.
	local shown = transparency < 0.5
	for _, descendant in truck.model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = transparency
		elseif descendant:IsA("Light") then
			descendant.Enabled = shown
		elseif descendant:IsA("SurfaceGui") then
			showLivery(descendant, shown)
		end
	end
	for _, child in bed:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute(DepotConstants.TRUCK_SHELL_ATTRIBUTE) == true then
			child.LocalTransparencyModifier = if solid then 0 else 1
		end
	end
	highlight.OutlineTransparency = if ghost then C.GHOST_OUTLINE_TRANSPARENCY else 1
	if math.abs(truck.model:GetScale() - scale) > 1e-4 then
		truck.model:ScaleTo(scale)
	end
end

local function puff(bed: BasePart)
	if not VfxBurstSystem.polished() then
		return
	end
	VfxBurstSystem.play(C.PUFF_ID, bed.Position - Vector3.new(0, bed.Size.Y / 2, 0))
end

-- The truck's bed while it is streamed in and a held pad (a hub truck), with its outline made; nil otherwise.
local function resolve(truck: Truck): (BasePart?, Highlight?)
	local bed = truck.bed
	if bed == nil or bed.Parent == nil then
		bed = bedOf(truck.model)
		truck.bed = bed
		truck.dirty = true
	end
	if bed == nil or bed:GetAttribute(QueueConstants.HOLD_ATTRIBUTE) ~= true then
		return nil, nil
	end
	local highlight = truck.highlight
	if highlight == nil then
		local made = Instance.new("Highlight")
		made.Name = "DepotTruckGhost"
		made.Adornee = truck.model
		made.FillTransparency = 1
		made.OutlineColor = C.GHOST_OUTLINE
		made.OutlineTransparency = 1
		made.DepthMode = Enum.HighlightDepthMode.Occluded
		made.Parent = truck.model
		truck.highlight = made
		highlight = made
	end
	return bed, highlight
end

local function step()
	local now = os.clock()
	for _, truck in trucks do
		local bed, highlight = resolve(truck)
		if bed == nil or highlight == nil then
			continue
		end
		local hosted = bed:GetAttribute(HostConstants.HOST_ATTRIBUTE) ~= nil
		if truck.parked == nil then
			truck.parked = hosted
			truck.dirty = true
		elseif truck.parked ~= hosted then
			truck.parked = hosted
			truck.since = now
			truck.arriving = hosted
			if hosted then
				puff(bed)
			end
		end
		local since = truck.since
		if since ~= nil then
			local t = now - since
			local scale = if truck.arriving then DepotTruckPopFormulas.scale(t) else 1
			draw(truck, bed, highlight, DepotTruckPopFormulas.transparency(t, truck.arriving), scale)
			local length = if truck.arriving then C.POP_SECONDS else C.LEAVE_SECONDS
			if t >= length then
				truck.since = nil
			end
			truck.dirty = false
		elseif truck.dirty then
			draw(truck, bed, highlight, if truck.parked then 0 else C.GHOST_TRANSPARENCY, 1)
			truck.dirty = false
		end
	end
end

local function observe(instance: Instance): (() -> ())?
	if not instance:IsA("Model") then
		return nil
	end
	local model: Model = instance
	-- Watched from the start: whether it is a hub truck is only known once its bed streams in (`resolve`).
	local truck: Truck = {
		model = model,
		bed = nil,
		highlight = nil,
		dirty = true,
		parked = nil,
		since = nil,
		arriving = false,
	}
	trucks[model] = truck
	local added = model.DescendantAdded:Connect(function()
		truck.dirty = true
	end)
	return function()
		added:Disconnect()
		trucks[model] = nil
		local highlight = truck.highlight
		if highlight ~= nil then
			highlight:Destroy()
		end
	end
end

local DepotTruckGhostSystem = {}

-- Starts drawing the bays; returns the stop (the DepotTruckScannerSystem shape).
function DepotTruckGhostSystem.start(): () -> ()
	if stopObserving == nil then
		VfxBurstSystem.preload()
		stopObserving = Observers.observeTag(DepotConstants.TRUCK_ART_TAG, observe)
		ticking = RunService.Heartbeat:Connect(step)
	end
	return DepotTruckGhostSystem.stop
end

function DepotTruckGhostSystem.stop()
	local stopFn = stopObserving
	if stopFn ~= nil then
		stopFn()
		stopObserving = nil
	end
	local connection = ticking
	if connection ~= nil then
		connection:Disconnect()
		ticking = nil
	end
end

return DepotTruckGhostSystem
