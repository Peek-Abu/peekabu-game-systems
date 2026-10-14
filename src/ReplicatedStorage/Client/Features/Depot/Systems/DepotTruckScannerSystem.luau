--!strict
--[=[
	DepotTruckScannerSystem: the truck's scanner arch answers each bank (truck design A). When Cargo's `Banked`
	announcement lands, after the item's swoop into the bed (CargoConstants.SWOOP_SECONDS), the tagged scanner light
	nearest the bed lights up bright, its glow pulses, a thin light sweeps down the doorway, and it beeps twice.

	Cosmetic and client-local: the server's bank is the only authority, and every instance here is this client's
	own (the sweep, local Color/Brightness on the replicated light). A second bank mid-flash restarts the flash.

	@class DepotTruckScannerSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)

-- How far from the banked point a scanner may be to answer it (the bed's top to its arch light is ~10 studs).
local RANGE = 25
local LIT = Color3.fromRGB(170, 255, 200)
local GLOW = 4
local HOLD = 0.3
local FADE = 0.55
local SWEEP_SECONDS = 0.45
local SWEEP_THICKNESS = Vector3.new(0, 0.12, 0.9)
-- An existing short tick (ShiftAssets), played twice at the arch as its beep.
local BEEP = "shiftCountdownTick"
local BEEP_GAP = 0.14

type Flash = { tweens: { Tween }, sweep: BasePart }

local active: { [BasePart]: Flash } = {}

local DepotTruckScannerSystem = {
	LIT = LIT,
}

-- The tagged scanner lights in the Workspace.
function DepotTruckScannerSystem.tagged(): { BasePart }
	local found: { BasePart } = {}
	for _, instance in CollectionService:GetTagged(DepotConstants.SCANNER_TAG) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(Workspace) then
			table.insert(found, instance)
		end
	end
	return found
end

-- The scanner closest to `point`, if one is within `range` studs.
function DepotTruckScannerSystem.nearest(scanners: { BasePart }, point: Vector3, range: number): BasePart?
	local best: BasePart? = nil
	local bestDistance = range
	for _, scanner in scanners do
		local distance = (scanner.Position - point).Magnitude
		if distance <= bestDistance then
			best = scanner
			bestDistance = distance
		end
	end
	return best
end

local function stop(scanner: BasePart)
	local flash = active[scanner]
	if flash ~= nil then
		for _, tween in flash.tweens do
			tween:Cancel()
		end
		flash.sweep:Destroy()
		active[scanner] = nil
	end
end

--[=[
	Lights `scanner` and starts its sweep (parented to `parent`); returns the sweep part, or nil when the scanner has
	no sweep path. Settles back to the scanner's idle colour by itself.
]=]
function DepotTruckScannerSystem.flash(scanner: BasePart, parent: Instance): BasePart?
	local top = scanner:FindFirstChild(DepotConstants.SCANNER_SWEEP_TOP)
	local bottom = scanner:FindFirstChild(DepotConstants.SCANNER_SWEEP_BOTTOM)
	local width = scanner:GetAttribute(DepotConstants.SCANNER_WIDTH_ATTRIBUTE)
	if top == nil or bottom == nil or not top:IsA("Attachment") or not bottom:IsA("Attachment") then
		return nil
	end
	stop(scanner)
	local idleValue = scanner:GetAttribute(DepotConstants.SCANNER_IDLE_ATTRIBUTE)
	local idle = if typeof(idleValue) == "Color3" then idleValue else scanner.Color
	scanner.Color = LIT
	local tweens: { Tween } = {}
	local settle = TweenInfo.new(FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, HOLD)
	table.insert(tweens, TweenService:Create(scanner, settle, { Color = idle }))
	local glow = scanner:FindFirstChildWhichIsA("PointLight")
	if glow ~= nil then
		glow.Brightness = GLOW
		table.insert(tweens, TweenService:Create(glow, settle, { Brightness = 0 }))
	end

	local sweep = Instance.new("Part")
	sweep.Name = "ScanSweep"
	sweep.Size = Vector3.new(if type(width) == "number" then width else scanner.Size.X, 0, 0) + SWEEP_THICKNESS
	sweep.CFrame = top.WorldCFrame
	sweep.Color = LIT
	sweep.Material = Enum.Material.Neon
	sweep.Transparency = 0.25
	sweep.Anchored = true
	sweep.CanCollide = false
	sweep.CanQuery = false
	sweep.CanTouch = false
	sweep.CastShadow = false
	sweep.Parent = parent
	local down = TweenService:Create(
		sweep,
		TweenInfo.new(SWEEP_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ CFrame = bottom.WorldCFrame, Transparency = 0.85 }
	)
	table.insert(tweens, down)
	local flash: Flash = { tweens = tweens, sweep = sweep }
	active[scanner] = flash
	down.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and active[scanner] == flash then
			sweep:Destroy()
		end
	end)
	for _, tween in tweens do
		tween:Play()
	end
	tweens[1].Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and active[scanner] == flash then
			active[scanner] = nil
			sweep:Destroy()
		end
	end)
	return sweep
end

-- Listens for banks; returns the stopper.
function DepotTruckScannerSystem.start(): () -> ()
	local CargoEvents = require(ReplicatedStorage.Shared.Features.Cargo.Net.CargoEvents)
	local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)
	-- Registers the beep's sound.
	require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftAssets)
	local running = true
	local disconnect = CargoEvents.packets.Banked.listen(function(data)
		local to: Vector3 = data.to
		task.delay(CargoConstants.SWOOP_SECONDS, function()
			if not running then
				return
			end
			local scanner = DepotTruckScannerSystem.nearest(DepotTruckScannerSystem.tagged(), to, RANGE)
			if scanner == nil or DepotTruckScannerSystem.flash(scanner, Workspace) == nil then
				return
			end
			SoundServiceClient:play(BEEP, { at = scanner })
			task.delay(BEEP_GAP, function()
				if running and scanner.Parent ~= nil then
					SoundServiceClient:play(BEEP, { at = scanner })
				end
			end)
		end)
	end)
	return function()
		running = false
		disconnect()
		for scanner in active do
			stop(scanner)
		end
	end
end

return DepotTruckScannerSystem
