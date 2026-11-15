--!strict
--[=[
	VacuumAirSystem: the air a sucking vacuum gulps (P1 2026-11-14, "air flowing INTO the nozzle"; visual only, on this
	machine). While a holder's vacuum sucks (VacuumMotionSystem's active: the server's VacuumMotionConstants
	.ACTIVE_ATTRIBUTE, or the local player's own trigger at once), a VacuumVfxConstants `vacuumAir` funnel fans pale air
	streaks and dust motes in from ahead of its floor head into the head's mouth (VacuumFeelFormulas.airFlow), re-aimed
	every frame as the wand moves; when it stops, the stream stops and the air in flight finishes. Every player sees
	every holder's. Stepped by VacuumMotionSystem for every holder (the presets are registered when VacuumVfxSystem
	loads, through VacuumFeedbackSystem, before any step).

	Spec-exempt shell (VfxFunnelSystem); where the air flows is the specced VacuumFeelFormulas.airFlow.

	@class VacuumAirSystem
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local VacuumFeelFormulas = require(ReplicatedStorage.Client.Features.Vacuum.Utils.VacuumFeelFormulas)
local VfxFunnelSystem = require(ReplicatedStorage.Client.Features.Vfx.Systems.VfxFunnelSystem)

local AIR = "vacuumAir"
-- The air's strength (VfxFunnelSystem: its rate and swirl): full rate, a gentle swirl.
local STRENGTH = 1

local streams: { [Model]: VfxFunnelSystem.Funnel } = {}

local VacuumAirSystem = {}

-- `character`'s held floor head, or nil while its wand is stowed.
local function headOf(character: Model): BasePart?
	local tool = character:FindFirstChild(VacuumConstants.TOOL_NAME)
	local head = if tool ~= nil and tool:IsA("Tool") then tool:FindFirstChild(VacuumConstants.FLOOR_HEAD_NAME) else nil
	return if head ~= nil and head:IsA("BasePart") then head else nil
end

--[=[
	One frame of `character`'s air: flowing into its floor head while `active` (and its wand is out), else stopped.
]=]
function VacuumAirSystem.step(character: Model, root: BasePart?, active: boolean)
	local head = if active and root ~= nil then headOf(character) else nil
	local stream = streams[character]
	if head == nil or root == nil then
		if stream ~= nil then
			stream:stop()
			streams[character] = nil
		end
		return
	end
	local flowing = stream or VfxFunnelSystem.funnel(AIR)
	if flowing == nil then
		return
	end
	streams[character] = flowing
	local source, sink, radius = VacuumFeelFormulas.airFlow(head.CFrame, head.Size, root.Position)
	flowing:aim(source, sink, radius, STRENGTH)
end

--[=[
	`character` is gone (or no longer held): its air stops.
]=]
function VacuumAirSystem.forget(character: Model)
	local stream = streams[character]
	if stream ~= nil then
		stream:stop()
		streams[character] = nil
	end
end

function VacuumAirSystem.forgetAll()
	for _, stream in streams do
		stream:stop()
	end
	table.clear(streams)
end

return VacuumAirSystem
