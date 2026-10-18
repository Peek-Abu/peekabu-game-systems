--!strict
--[=[
	VacuumGaugeSystem: every backpack's Gloom gauge on this client (VacuumFeedbackSystem decides what it heads toward:
	the crew's Gloom as a share of the contract). Each frame each player's gauge eases toward that share
	(VacuumFeedbackFormulas.gaugeStep); its dust insert behind the window (VacuumVisualSystem on the server) is resized
	and its Weld moved locally (never replicated) from the full size and offset the server recorded on them, and its
	lamp lit once full. A gauge's parts are found once per backpack and kept while they stay in place (a respawn or a
	new backpack finds them again), never searched every frame.

	Spec-exempt shell (Players, Instances); the easing and the fill are the specced VacuumFeedbackFormulas.

	@class VacuumGaugeSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local VacuumFeedbackFormulas = require(ReplicatedStorage.Client.Features.Vacuum.Utils.VacuumFeedbackFormulas)

-- A backpack's gauge: what it shows and last drew, and its parts in the character it was found on (found once per
-- backpack, not searched every frame): the dust insert, its Weld and their full size and offset, and the lamp.
type Gauge = {
	shown: number,
	drawn: number,
	character: Model?,
	backpack: Instance?,
	fill: BasePart?,
	weld: Weld?,
	lamp: BasePart?,
	fullSize: Vector3,
	fullC0: CFrame,
}

local gauges: { [number]: Gauge } = {}

-- The gauge's parts in `character`'s backpack: the cached ones while they are still in place, else found again (a
-- respawn, a new backpack), which forces a redraw. False when it has no gauge.
local function bind(gauge: Gauge, character: Model): boolean
	local backpack, fill, weld = gauge.backpack, gauge.fill, gauge.weld
	if
		gauge.character == character
		and backpack ~= nil
		and backpack.Parent == character
		and fill ~= nil
		and fill:IsDescendantOf(backpack)
		and weld ~= nil
		and weld.Parent == fill
	then
		return true
	end
	gauge.character, gauge.backpack, gauge.fill, gauge.weld, gauge.lamp = nil, nil, nil, nil, nil
	local foundPack = character:FindFirstChild(VacuumConstants.BACKPACK_NAME)
	local foundFill = if foundPack ~= nil then foundPack:FindFirstChild(VacuumConstants.GAUGE_FILL_NAME, true) else nil
	local foundWeld = if foundFill ~= nil then foundFill:FindFirstChild(VacuumConstants.GAUGE_WELD_NAME) else nil
	if
		foundPack == nil
		or foundFill == nil
		or not foundFill:IsA("BasePart")
		or foundWeld == nil
		or not foundWeld:IsA("Weld")
	then
		return false
	end
	local fullSize = foundFill:GetAttribute("GaugeFullSize")
	local fullC0 = foundWeld:GetAttribute("GaugeFullC0")
	if typeof(fullSize) ~= "Vector3" or typeof(fullC0) ~= "CFrame" then
		return false
	end
	local lamp = foundPack:FindFirstChild(VacuumConstants.LAMP_NAME, true)
	gauge.character, gauge.backpack, gauge.fill, gauge.weld = character, foundPack, foundFill, foundWeld
	gauge.lamp = if lamp ~= nil and lamp:IsA("BasePart") then lamp else nil
	gauge.fullSize, gauge.fullC0 = fullSize, fullC0
	gauge.drawn = -1
	return true
end

-- Sizes a backpack's dust insert to `shown` and lights its lamp when full. False when it has no gauge.
local function drawGauge(gauge: Gauge, character: Model?): boolean
	if character == nil or not bind(gauge, character) then
		return false
	end
	local fill, weld = gauge.fill, gauge.weld
	if fill == nil or weld == nil then
		return false
	end
	if math.abs(gauge.drawn - gauge.shown) < 1e-4 then
		return true
	end
	local fullSize = gauge.fullSize
	local height, drop = VacuumFeedbackFormulas.gaugeFill(fullSize.Y, gauge.shown)
	fill.Size = Vector3.new(fullSize.X, math.max(height, 0.001), fullSize.Z)
	fill.Transparency = if height < 0.005 then 1 else 0
	weld.C0 = gauge.fullC0 * CFrame.new(0, -drop, 0)
	local lamp = gauge.lamp
	if lamp ~= nil then
		local lit = gauge.shown >= 0.98
		lamp.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
		lamp.Color = if lit then VacuumConstants.LAMP_ON_COLOR else VacuumConstants.LAMP_OFF_COLOR
	end
	gauge.drawn = gauge.shown
	return true
end

local function drawAll(deltaTime: number, target: number)
	for _, player in Players:GetPlayers() do
		if gauges[player.UserId] == nil then
			gauges[player.UserId] = {
				shown = target,
				drawn = -1,
				character = nil,
				backpack = nil,
				fill = nil,
				weld = nil,
				lamp = nil,
				fullSize = Vector3.zero,
				fullC0 = CFrame.identity,
			}
		end
	end
	for userId, gauge in gauges do
		local player = Players:GetPlayerByUserId(userId)
		if player == nil then
			gauges[userId] = nil
			continue
		end
		gauge.shown = VacuumFeedbackFormulas.gaugeStep(gauge.shown, target, deltaTime, VacuumConstants.GAUGE_RATE)
		drawGauge(gauge, player.Character)
	end
end

local VacuumGaugeSystem = {}

--[=[
	One frame: every player's gauge eases toward `target` (0..1) over `deltaTime` and is drawn.
]=]
function VacuumGaugeSystem.draw(deltaTime: number, target: number)
	drawAll(deltaTime, target)
end

-- Forgets every gauge (the system stopped).
function VacuumGaugeSystem.clear()
	table.clear(gauges)
end

return VacuumGaugeSystem
