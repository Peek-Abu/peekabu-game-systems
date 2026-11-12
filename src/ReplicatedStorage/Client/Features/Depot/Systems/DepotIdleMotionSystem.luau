--!strict
--[=[
	DepotIdleMotionSystem: the hub stations' small idle motions on this client (owner 11-11, ideas sheet #3: "every
	station does something on its own"; DepotSpotConstants.IDLE, DepotIdleRules). The hub is built in Studio, so the
	motions are data: a builder tags a part IDLE.TAG and names its motion in IDLE.ATTRIBUTE, and this system runs it
	while the part exists. Everything is local and cosmetic (nothing replicates, nothing collides):
	- steam: soft white puffs off the part's top now and then (the coffee machine).
	- drip: a drop falls from the part's bottom to whatever is under it (the coffee machine's spout).
	- bounce: the part's model hops on every beat while the radio plays music (DepotStore's station has a track).
	- sway: the bell's swing parts nudge a few degrees about its pivot now and then (never during a real ring).
	- rattle: the part (a locker door) jiggles about its left edge now and then (the Gloom locker: goo inside).
	- twinkle: a few gold sparkles round the part now and then (the Gleam locker).
	- candrop: one of the drinks and snacks stocked in the part's box (a vending machine's window) is vended now and
	  then: nudged off its shelf, it drops to the tray and is back after (no more spinning can).
	- tick: a second hand on the part's front face steps once a second (the time clock's face).

	Spec-exempt shell (Instances, particles, per-frame CFrames); the timing is the specced DepotIdleRules.

	@class DepotIdleMotionSystem
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Observers = require(ReplicatedStorage.Packages.Observers)
local DepotSpotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotSpotConstants)
local DepotIdleRules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotIdleRules)
local DepotAssets = require(ReplicatedStorage.Client.Features.Depot.Data.DepotAssets)
local DepotStore = require(ReplicatedStorage.Client.Features.Depot.State.DepotStore)
local DepotSpotSystem = require(ReplicatedStorage.Client.Features.Depot.Systems.DepotSpotSystem)

local IDLE = DepotSpotConstants.IDLE
local SWING = DepotSpotConstants.BELL_SWING
local STEAM_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local DROP_SIZE = 0.09

local random = Random.new()

local function inert(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

-- Runs `go` every IDLE.INTERVALS[kind] seconds until the stopper is called.
local function every(kind: string, go: () -> ()): () -> ()
	local running = true
	task.spawn(function()
		while running do
			local wait = DepotIdleRules.nextAt(0, kind, random:NextNumber())
			task.wait(wait)
			if running then
				go()
			end
		end
	end)
	return function()
		running = false
	end
end

local function steam(part: BasePart): () -> ()
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "IdleSteam"
	emitter.Texture = STEAM_TEXTURE
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(1.0, 1.5)
	emitter.Speed = NumberRange.new(0.8, 1.3)
	emitter.SpreadAngle = Vector2.new(12, 12)
	emitter.Acceleration = Vector3.new(0, 0.6, 0)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.7) })
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.LightInfluence = 0.6
	emitter.Parent = part
	local stop = every("steam", function()
		emitter:Emit(random:NextInteger(3, 5))
	end)
	return function()
		stop()
		emitter:Destroy()
	end
end

-- A drop from the part's bottom down to whatever is under it.
local function drip(part: BasePart): () -> ()
	return every("drip", function()
		if part.Parent == nil then
			return
		end
		local start = (part.CFrame * CFrame.new(0, -part.Size.Y / 2, 0)).Position
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { part }
		local hit = Workspace:Raycast(start, Vector3.new(0, -IDLE.FALL.DISTANCE * 2, 0), params)
		local distance = if hit ~= nil then start.Y - hit.Position.Y else IDLE.FALL.DISTANCE
		local drop = Instance.new("Part")
		drop.Name = "IdleDrip"
		drop.Shape = Enum.PartType.Ball
		drop.Size = Vector3.one * DROP_SIZE
		drop.Color = Color3.fromRGB(60, 34, 18)
		drop.Material = Enum.Material.Glass
		drop.Transparency = 0.2
		inert(drop)
		drop.Position = start
		drop.Parent = Workspace
		local t0 = os.clock()
		local connection: RBXScriptConnection? = nil
		connection = RunService.RenderStepped:Connect(function()
			local t = os.clock() - t0
			local fallen = math.min(distance, DepotIdleRules.fall(t))
			drop.Position = start - Vector3.new(0, fallen, 0)
			if fallen >= distance then
				if connection ~= nil then
					connection:Disconnect()
				end
				drop:Destroy()
			end
		end)
	end)
end

local function bounce(part: BasePart): () -> ()
	local target: PVInstance = part:FindFirstAncestorWhichIsA("Model") or part
	local base = target:GetPivot()
	local t0 = os.clock()
	local connection = RunService.RenderStepped:Connect(function()
		local playing = DepotStore.stationDef().track ~= nil
		local lift = if playing then DepotIdleRules.bounce(os.clock() - t0, IDLE.BEAT_SECONDS) else 0
		target:PivotTo(base + Vector3.new(0, lift, 0))
	end)
	return function()
		connection:Disconnect()
		if target.Parent ~= nil then
			target:PivotTo(base)
		end
	end
end

-- The bell's swing parts nudged about its pivot (the same parts a ring swings), never during a ring.
local function sway(part: BasePart): () -> ()
	local bell: Instance = part:FindFirstAncestorWhichIsA("Model") or part
	return every("sway", function()
		local pivot = bell:FindFirstChild(SWING.PIVOT_NAME, true)
		if pivot == nil or not pivot:IsA("Attachment") or DepotSpotSystem.ringing(bell) then
			return
		end
		local base = pivot.WorldCFrame
		local parts: { [BasePart]: CFrame } = {}
		for _, piece in bell:GetDescendants() do
			if piece:IsA("BasePart") and piece:GetAttribute(SWING.SWING_ATTRIBUTE) == true then
				parts[piece] = base:ToObjectSpace(piece.CFrame)
			end
		end
		local t0 = os.clock()
		while os.clock() - t0 < IDLE.SWAY.SECONDS and not DepotSpotSystem.ringing(bell) do
			local turn = base * CFrame.Angles(math.rad(DepotIdleRules.sway(os.clock() - t0)), 0, 0)
			for piece, offset in parts do
				piece.CFrame = turn * offset
			end
			RunService.RenderStepped:Wait()
		end
		if not DepotSpotSystem.ringing(bell) then
			for piece, offset in parts do
				piece.CFrame = base * offset
			end
		end
	end)
end

-- The part jiggles about its left edge (a door on its hinge).
local function rattle(part: BasePart): () -> ()
	local base = part.CFrame
	local hinge = base * CFrame.new(-part.Size.X / 2, 0, 0)
	local offset = hinge:ToObjectSpace(base)
	return every("rattle", function()
		local t0 = os.clock()
		while os.clock() - t0 <= IDLE.RATTLE.SECONDS and part.Parent ~= nil do
			part.CFrame = hinge * CFrame.Angles(0, math.rad(DepotIdleRules.rattle(os.clock() - t0)), 0) * offset
			RunService.RenderStepped:Wait()
		end
		part.CFrame = base
	end)
end

local function twinkle(part: BasePart): () -> ()
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "IdleTwinkle"
	emitter.Texture = DepotAssets.SPARKLE
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(0.2, 0.6)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 226, 120))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Rotation = NumberRange.new(0, 90)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.Parent = part
	local stop = every("twinkle", function()
		emitter:Emit(random:NextInteger(2, 4))
	end)
	return function()
		stop()
		emitter:Destroy()
	end
end

-- A can falls from the top of the part's box to its bottom (inside a vending machine's window).
-- The stocked items inside `part`'s box (parts tagged VEND.STOCK_TAG: the vending machine's drinks and snacks).
local function stockIn(part: BasePart): { BasePart }
	local found: { BasePart } = {}
	local half = part.Size / 2 + Vector3.new(0.6, 0.6, 0.6)
	for _, item in CollectionService:GetTagged(IDLE.VEND.STOCK_TAG) do
		if item:IsA("BasePart") then
			local at = part.CFrame:PointToObjectSpace(item.Position)
			if math.abs(at.X) <= half.X and math.abs(at.Y) <= half.Y and math.abs(at.Z) <= half.Z then
				table.insert(found, item)
			end
		end
	end
	return found
end

-- Now and then one stocked item is vended (owner 11-12: the machine dropped a spinning can): a local copy is nudged
-- off its shelf toward the glass (`part`'s LookVector), drops to `part`'s bottom (the tray) tipping forward, rests,
-- and goes; the item itself hides meanwhile and is back on its shelf after.
local function candrop(part: BasePart): () -> ()
	return every("candrop", function()
		if part.Parent == nil then
			return
		end
		local stock = stockIn(part)
		if #stock == 0 then
			return
		end
		local item = stock[random:NextInteger(1, #stock)]
		local copy = item:Clone()
		for _, tag in CollectionService:GetTags(copy) do
			CollectionService:RemoveTag(copy, tag)
		end
		inert(copy)
		copy.Parent = Workspace
		item.LocalTransparencyModifier = 1
		local start = item.CFrame
		local ahead = Vector3.new(part.CFrame.LookVector.X, 0, part.CFrame.LookVector.Z)
		ahead = if ahead.Magnitude > 1e-3 then ahead.Unit else Vector3.zAxis
		local bottom = part.Position.Y - part.Size.Y / 2
		local drop = math.max(0, (start.Position.Y - item.Size.Y / 2) - bottom)
		-- Tipping forward: about the horizontal axis across the glass.
		local across = ahead:Cross(Vector3.yAxis)
		local t0 = os.clock()
		while part:IsDescendantOf(game) do
			local forward, fallen, tip, done = DepotIdleRules.vend(os.clock() - t0, drop)
			local at = start.Position + ahead * forward - Vector3.new(0, fallen, 0)
			copy.CFrame = CFrame.fromAxisAngle(across, -math.rad(tip)) * start.Rotation + at
			if done then
				break
			end
			RunService.RenderStepped:Wait()
		end
		task.wait(IDLE.VEND.REST)
		copy:Destroy()
		item.LocalTransparencyModifier = 0
	end)
end

-- A thin second hand on the part's front face (its -Z face), stepping once a second.
local function tick(part: BasePart): () -> ()
	local length = math.min(part.Size.X, part.Size.Y) * 0.42
	local hand = Instance.new("Part")
	hand.Name = "IdleSecondHand"
	hand.Size = Vector3.new(0.035, length, 0.02)
	hand.Color = Color3.fromRGB(214, 48, 49)
	hand.Material = Enum.Material.SmoothPlastic
	inert(hand)
	hand.Parent = part
	local connection = RunService.RenderStepped:Connect(function()
		local face = part.CFrame * CFrame.new(0, 0, -part.Size.Z / 2 - 0.012)
		local angle = math.rad(DepotIdleRules.tick(Workspace:GetServerTimeNow()))
		hand.CFrame = face * CFrame.Angles(0, 0, angle) * CFrame.new(0, length / 2, 0)
	end)
	return function()
		connection:Disconnect()
		hand:Destroy()
	end
end

local MOTIONS: { [string]: (part: BasePart) -> () -> () } = {
	steam = steam,
	drip = drip,
	bounce = bounce,
	sway = sway,
	rattle = rattle,
	twinkle = twinkle,
	candrop = candrop,
	tick = tick,
}

local DepotIdleMotionSystem = {}

-- Runs every tagged part's idle motion while it exists; returns the stopper.
function DepotIdleMotionSystem.start(): () -> ()
	return Observers.observeTag(IDLE.TAG, function(instance: Instance)
		if not instance:IsA("BasePart") then
			return nil
		end
		local motion = instance:GetAttribute(IDLE.ATTRIBUTE)
		local run = if type(motion) == "string" then MOTIONS[motion] else nil
		if run == nil then
			return nil
		end
		return run(instance)
	end)
end

return DepotIdleMotionSystem
