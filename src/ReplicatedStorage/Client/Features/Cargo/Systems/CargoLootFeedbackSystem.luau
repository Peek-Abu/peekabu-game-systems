--!strict
--[=[
	CargoLootFeedbackSystem: the loot loop's moments on this client (docs/superpowers/specs/
	2026-10-15-cleanup-crew-loot-loop-design.md §3.3-3.4, §5):

	- the glint: a dust pile marked CargoConstants.BURIED_ATTRIBUTE twinkles a few sparkles every
	  GLINT_INTERVAL_MIN..MAX seconds (its own random schedule), drawn only when the local character is within
	  GLINT_DISTANCE: a hint easy to miss;
	- the reveal: a cargo item that was hidden under a pile pops out with a gold burst and `cargoReveal`;
	- the appraisal: a valuable appraised a moment ago (CargoAppraisedAt, fresh by CargoLootFeedbackFormulas.stampFresh)
	  bursts paper flecks with `cargoAppraise` (its sticky slip and its tag's stamp are the server's and the tag's).

	Client-local instances; pending sounds (CargoAssets) are skipped silently.

	Spec-exempt shell (CollectionService, particles, Sound, RunService); the decisions are the specced
	CargoLootFeedbackFormulas.

	@class CargoLootFeedbackSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Observers = require(ReplicatedStorage.Packages.Observers)
local CargoAssets = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoAssets)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local SoundRegistry = require(ReplicatedStorage.Shared.Features.Sound.Data.SoundRegistry)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local CargoLootFeedbackFormulas = require(ReplicatedStorage.Client.Features.Cargo.Utils.CargoLootFeedbackFormulas)
local SoundServiceClient = require(ReplicatedStorage.Client.Features.Sound.SoundServiceClient)

export type CargoLootFeedbackState = {
	piles: number,
	counters: { [string]: number },
}

-- How often the glint schedule is checked.
local GLINT_CHECK = 0.1

local rng = Random.new()
-- Every pile and when it next glints (os.clock()); only a buried one actually does.
local nextGlint: { [BasePart]: number } = {}
local counters = { glints = 0, reveals = 0, appraisals = 0 }
local stoppers: { () -> () } = {}

local function play(id: string, at: Vector3)
	if CargoAssets.SOUNDS[id] ~= nil and SoundRegistry.has(id) then
		SoundServiceClient:play(id, { at = at })
	end
end

-- A one-shot burst of `count` sparks at `position`, cleaned up after its lifetime.
local function burst(position: Vector3, color: Color3, count: number, size: number, speed: number, lifetime: number)
	local anchor = Instance.new("Attachment")
	anchor.Name = "CargoLootBurst"
	anchor.Parent = Workspace.Terrain
	anchor.WorldPosition = position
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new(size, 0)
	emitter.Lifetime = NumberRange.new(lifetime * 0.6, lifetime)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = 1
	emitter.Enabled = false
	emitter.Parent = anchor
	emitter:Emit(count)
	task.delay(lifetime + 0.2, function()
		anchor:Destroy()
	end)
end

local function localRoot(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local function glint(pile: BasePart)
	local root = localRoot()
	if root == nil or not CargoLootFeedbackFormulas.glintSeen((root.Position - pile.Position).Magnitude) then
		return
	end
	counters.glints += 1
	local top = pile.Position + Vector3.new(0, pile.Size.Y / 2, 0)
	burst(
		top,
		CargoConstants.GLINT_COLOR,
		CargoConstants.GLINT_COUNT,
		CargoConstants.GLINT_SIZE,
		1.5,
		CargoConstants.GLINT_LIFETIME
	)
	play("cargoGlint", top)
end

local function stepGlints()
	local now = os.clock()
	for pile, at in nextGlint do
		if now >= at then
			nextGlint[pile] = now + CargoLootFeedbackFormulas.glintDelay(rng:NextNumber())
			if pile:GetAttribute(CargoConstants.BURIED_ATTRIBUTE) == true then
				glint(pile)
			end
		end
	end
end

local function observePile(instance: Instance): (() -> ())?
	if not instance:IsA("BasePart") then
		return nil
	end
	-- A first glint somewhere in the first interval, so buried piles never twinkle in step.
	nextGlint[instance] = os.clock() + CargoLootFeedbackFormulas.glintDelay(rng:NextNumber())
	return function()
		nextGlint[instance] = nil
	end
end

-- Every cargo item: a reveal when it stops being hidden, a burst when it is freshly appraised.
local function observeItem(instance: Instance): (() -> ())?
	if not instance:IsA("BasePart") then
		return nil
	end
	local item: BasePart = instance
	local wasHidden = item:GetAttribute(CargoConstants.HIDDEN_ATTRIBUTE) == true
	local hiddenChanged = item:GetAttributeChangedSignal(CargoConstants.HIDDEN_ATTRIBUTE):Connect(function()
		local hidden = item:GetAttribute(CargoConstants.HIDDEN_ATTRIBUTE) == true
		if wasHidden and not hidden then
			counters.reveals += 1
			burst(item.Position, CargoConstants.REVEAL_COLOR, CargoConstants.REVEAL_COUNT, 0.45, 12, 0.7)
			play("cargoReveal", item.Position)
		end
		wasHidden = hidden
	end)
	local appraisedChanged = item:GetAttributeChangedSignal(CargoConstants.APPRAISED_AT_ATTRIBUTE):Connect(function()
		local at = item:GetAttribute(CargoConstants.APPRAISED_AT_ATTRIBUTE)
		if
			CargoLootFeedbackFormulas.stampFresh(if type(at) == "number" then at else nil, Workspace:GetServerTimeNow())
		then
			counters.appraisals += 1
			burst(
				item.Position + Vector3.new(0, item.Size.Y / 2, 0),
				CargoConstants.APPRAISE_COLOR,
				CargoConstants.APPRAISE_COUNT,
				0.3,
				6,
				0.6
			)
			play("cargoAppraise", item.Position)
		end
	end)
	return function()
		hiddenChanged:Disconnect()
		appraisedChanged:Disconnect()
	end
end

local CargoLootFeedbackSystem = {}

function CargoLootFeedbackSystem.start()
	if #stoppers > 0 then
		return
	end
	table.insert(stoppers, Observers.observeTag(VacuumConstants.PILE_TAG, observePile))
	table.insert(stoppers, Observers.observeTag(CarryConstants.TAG, observeItem))
	local elapsed = 0
	local ticking = RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime
		if elapsed >= GLINT_CHECK then
			elapsed = 0
			stepGlints()
		end
	end)
	table.insert(stoppers, function()
		ticking:Disconnect()
	end)
end

function CargoLootFeedbackSystem.stop()
	for _, stop in stoppers do
		stop()
	end
	table.clear(stoppers)
	table.clear(nextGlint)
end

function CargoLootFeedbackSystem.getState(): CargoLootFeedbackState
	local piles = 0
	for _ in nextGlint do
		piles += 1
	end
	return { piles = piles, counters = table.clone(counters) }
end

return CargoLootFeedbackSystem
