--!strict
--[=[
	CargoGrimeVisualSystem: how a grimy valuable looks on this client (docs/superpowers/specs/
	2026-10-15-cleanup-crew-loot-loop-design.md §5). Every item tagged VacuumConstants.GRIME_TAG near the camera gets a
	client-local Highlight (a dark grime fill, no outline, occluded) and a dust-mote ParticleEmitter, both fading with
	its replicated CargoClean (CargoLootFeedbackFormulas). The art kit's meshes and SurfaceAppearances are never
	touched, so any template works and a cleaned item is exactly its authored self. Items are re-checked every
	GRIME_VISUAL_CHECK seconds (distance: Highlights are capped per client) and on every CargoClean change; a spotless
	item loses its tag, and with it the look.

	Spec-exempt shell (CollectionService, Highlight, ParticleEmitter, RunService); the decisions are the specced
	CargoLootFeedbackFormulas.

	@class CargoGrimeVisualSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Observers = require(ReplicatedStorage.Packages.Observers)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local CargoLootFeedbackFormulas = require(ReplicatedStorage.Client.Features.Cargo.Utils.CargoLootFeedbackFormulas)

type Look = {
	item: BasePart,
	highlight: Highlight?,
	motes: ParticleEmitter?,
}

export type CargoGrimeVisualState = {
	grimy: number,
	drawn: number,
}

local LOOK_NAME = "CargoGrimeLook"

local looks: { [BasePart]: Look } = {}
local stoppers: { () -> () } = {}

local function cleanOf(item: Instance): number
	local clean = item:GetAttribute(CargoConstants.CLEAN_ATTRIBUTE)
	return if type(clean) == "number" then clean else 0
end

local function undraw(look: Look)
	local highlight = look.highlight
	if highlight ~= nil then
		highlight:Destroy()
		look.highlight = nil
	end
	local motes = look.motes
	if motes ~= nil then
		motes:Destroy()
		look.motes = nil
	end
end

local function draw(look: Look)
	local item = look.item
	local clean = cleanOf(item)
	local camera = Workspace.CurrentCamera
	local distance = if camera ~= nil then (camera.CFrame.Position - item.Position).Magnitude else math.huge
	local hidden = item:GetAttribute(CargoConstants.HIDDEN_ATTRIBUTE) == true
	if not CargoLootFeedbackFormulas.grimeShown(distance, hidden, clean) then
		undraw(look)
		return
	end
	local highlight = look.highlight
	if highlight == nil then
		local made = Instance.new("Highlight")
		made.Name = LOOK_NAME
		made.FillColor = CargoConstants.GRIME_COLOR
		made.OutlineTransparency = 1
		made.DepthMode = Enum.HighlightDepthMode.Occluded
		made.Adornee = item
		made.Parent = item
		highlight = made
		look.highlight = made
	end
	local motes = look.motes
	if motes == nil then
		local made = Instance.new("ParticleEmitter")
		made.Name = LOOK_NAME
		made.Color = ColorSequence.new(CargoConstants.GRIME_MOTE_COLOR)
		made.Size = NumberSequence.new(0.14, 0.04)
		made.Transparency = NumberSequence.new(0.35, 1)
		made.Lifetime = NumberRange.new(1.2, 2)
		made.Speed = NumberRange.new(0.3, 0.9)
		made.SpreadAngle = Vector2.new(60, 60)
		made.EmissionDirection = Enum.NormalId.Top
		made.Acceleration = Vector3.new(0, 0.4, 0)
		made.LightEmission = 0
		made.Parent = item
		motes = made
		look.motes = made
	end
	if highlight ~= nil then
		highlight.FillTransparency = CargoLootFeedbackFormulas.grimeFill(clean)
	end
	if motes ~= nil then
		motes.Rate = CargoLootFeedbackFormulas.moteRate(clean)
	end
end

local function observe(instance: Instance): (() -> ())?
	if not instance:IsA("BasePart") then
		return nil
	end
	local look: Look = { item = instance }
	looks[instance] = look
	draw(look)
	local changed = instance:GetAttributeChangedSignal(CargoConstants.CLEAN_ATTRIBUTE):Connect(function()
		draw(look)
	end)
	return function()
		changed:Disconnect()
		looks[instance] = nil
		undraw(look)
	end
end

local CargoGrimeVisualSystem = {}

function CargoGrimeVisualSystem.start()
	if #stoppers > 0 then
		return
	end
	table.insert(stoppers, Observers.observeTag(VacuumConstants.GRIME_TAG, observe))
	local elapsed = 0
	local ticking = RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed < CargoConstants.GRIME_VISUAL_CHECK then
			return
		end
		elapsed = 0
		for _, look in looks do
			draw(look)
		end
	end)
	table.insert(stoppers, function()
		ticking:Disconnect()
	end)
end

function CargoGrimeVisualSystem.stop()
	for _, stop in stoppers do
		stop()
	end
	table.clear(stoppers)
end

function CargoGrimeVisualSystem.getState(): CargoGrimeVisualState
	local grimy, drawn = 0, 0
	for _, look in looks do
		grimy += 1
		if look.highlight ~= nil then
			drawn += 1
		end
	end
	return { grimy = grimy, drawn = drawn }
end

return CargoGrimeVisualSystem
