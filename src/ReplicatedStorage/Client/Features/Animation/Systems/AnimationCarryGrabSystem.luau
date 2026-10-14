--!strict
--[=[
	AnimationCarryGrabSystem: the pickup, as every client sees it. Cosmetic only.

	The server decides a pickup and does it at once (CarryServiceServer: the cargo welded into the hands, the arm IK
	bound to it by AnimationCarrySystem), stamping where the cargo lay as the `CarryFrom` attribute. On its own that
	reads as the cargo teleporting into the hands. Each client replays the moment instead (AnimationCarryGrabFormulas,
	~0.3 s): a local ghost of the cargo is shown where it lay while the held one is hidden, the server's carry IK is
	pointed at the ghost with its chain rooted at the LowerTorso (so the waist bends: the quick crouch), and the ghost
	scoops up into the hold. Then the held cargo shows again and the IK goes back to the server's grips exactly as it
	was. Nothing here is replicated or authoritative: the IK changes are local property writes on this client.

	@class AnimationCarryGrabSystem
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local AnimationCarryGrabFormulas = require(ReplicatedStorage.Client.Features.Animation.Utils.AnimationCarryGrabFormulas)

export type Grab = {
	-- Advances the grab by `dt` seconds; true once it is over (everything handed back).
	step: (dt: number) -> boolean,
	-- Ends it now, handing everything back.
	cancel: () -> (),
}

-- The server's carry IK (AnimationCarrySystem) and its grip attachments, by side.
local SIDES = { "Right", "Left" }
local IK_PREFIX = "CleanupCarryIK"
local GRIP_PREFIX = "CleanupCarryGrip"
-- How quickly the reaching hands follow the ghost (the server's hold uses 0.08).
local REACH_SMOOTH_TIME = 0.05

type Saved = { control: IKControl, target: Instance, chainRoot: Instance, smoothTime: number }

local AnimationCarryGrabSystem = {}

local function partsOf(target: Instance): { BasePart }
	local parts: { BasePart } = {}
	if target:IsA("BasePart") then
		table.insert(parts, target)
	end
	for _, descendant in target:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

-- A visual-only copy of `target` at its current pose: anchored, intangible, without joints, scripts or prompts.
local function ghostOf(target: PVInstance): Model
	-- Clone skips a non-Archivable instance; the copy is local and short-lived, so allow it for this one call.
	local archivable = target.Archivable
	target.Archivable = true
	local copy = target:Clone()
	target.Archivable = archivable
	local ghost = Instance.new("Model")
	ghost.Name = "CarryGrabGhost"
	copy.Parent = ghost
	for _, descendant in copy:GetDescendants() do
		if
			descendant:IsA("JointInstance")
			or descendant:IsA("WeldConstraint")
			or descendant:IsA("LuaSourceContainer")
			or descendant:IsA("ProximityPrompt")
			or descendant:IsA("BillboardGui")
			or descendant:IsA("Sound")
		then
			descendant:Destroy()
		end
	end
	for _, part in partsOf(copy) do
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.LocalTransparencyModifier = 0
	end
	ghost.WorldPivot = target:GetPivot()
	return ghost
end

--[=[
	The pickup origin the server stamped on a carried object, nil when absent or malformed.
]=]
function AnimationCarryGrabSystem.origin(target: Instance): CFrame?
	local from = target:GetAttribute(CarryConstants.CARRY_FROM_ATTRIBUTE)
	return if typeof(from) == "CFrame" then from else nil
end

--[=[
	Plays the grab of `target` (already held by `character`) from `from`, the pose it lay at. The ghost goes under
	`stage` (Workspace by default). nil when there is nothing to replay (AnimationCarryGrabFormulas.plays).
]=]
function AnimationCarryGrabSystem.play(character: Model, target: PVInstance, from: CFrame, stage: Instance?): Grab?
	if not AnimationCarryGrabFormulas.plays(from, target:GetPivot()) then
		return nil
	end
	local ghost = ghostOf(target)
	ghost:PivotTo(from)
	ghost.Parent = stage or Workspace

	local hidden = partsOf(target)
	for _, part in hidden do
		part.LocalTransparencyModifier = 1
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local lowerTorso = character:FindFirstChild("LowerTorso")
	local saved: { Saved } = {}
	local reaching = false
	-- Points the server's carry IK at the ghost; retried each step, since the IK can replicate a frame after the
	-- pickup itself.
	local function reach()
		if reaching or humanoid == nil or lowerTorso == nil then
			return
		end
		for _, side in SIDES do
			local control = humanoid:FindFirstChild(IK_PREFIX .. side)
			local grip = ghost:FindFirstChild(GRIP_PREFIX .. side, true)
			if control ~= nil and control:IsA("IKControl") and grip ~= nil then
				table.insert(saved, {
					control = control,
					target = control.Target,
					chainRoot = control.ChainRoot,
					smoothTime = control.SmoothTime,
				})
				control.Target = grip
				control.ChainRoot = lowerTorso
				control.SmoothTime = REACH_SMOOTH_TIME
				reaching = true
			end
		end
	end

	local elapsed = 0
	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		for _, entry in saved do
			if entry.control.Parent ~= nil then
				entry.control.Target = entry.target
				entry.control.ChainRoot = entry.chainRoot
				entry.control.SmoothTime = entry.smoothTime
			end
		end
		table.clear(saved)
		for _, part in hidden do
			part.LocalTransparencyModifier = 0
		end
		ghost:Destroy()
	end

	return {
		step = function(dt: number): boolean
			if done then
				return true
			end
			if target.Parent == nil or character.Parent == nil then
				finish()
				return true
			end
			elapsed += dt
			if AnimationCarryGrabFormulas.finished(elapsed) then
				finish()
				return true
			end
			reach()
			ghost:PivotTo(AnimationCarryGrabFormulas.pose(from, target:GetPivot(), elapsed))
			return false
		end,
		cancel = finish,
	}
end

--[=[
	Replays every pickup this client sees, of any carrier (the local player's included). Returns the stop.
]=]
function AnimationCarryGrabSystem.start(): () -> ()
	local active: { [Instance]: Grab } = {}
	local watched: { [Instance]: RBXScriptConnection } = {}
	local connections: { RBXScriptConnection } = {}

	local function cancel(target: Instance)
		local grab = active[target]
		if grab ~= nil then
			grab.cancel()
			active[target] = nil
		end
	end

	local function onCarried(target: Instance)
		cancel(target)
		local by = target:GetAttribute(CarryConstants.CARRIED_BY_ATTRIBUTE)
		local from = AnimationCarryGrabSystem.origin(target)
		if type(by) ~= "number" or from == nil or not target:IsA("PVInstance") then
			return
		end
		local player = Players:GetPlayerByUserId(by)
		local character = if player ~= nil then player.Character else nil
		if character == nil then
			return
		end
		local grab = AnimationCarryGrabSystem.play(character, target, from)
		if grab ~= nil then
			active[target] = grab
		end
	end

	local function watch(target: Instance)
		local existing: RBXScriptConnection? = watched[target]
		if existing == nil then
			watched[target] = target:GetAttributeChangedSignal(CarryConstants.CARRIED_BY_ATTRIBUTE):Connect(function()
				onCarried(target)
			end)
		end
	end

	local function unwatch(target: Instance)
		cancel(target)
		local connection: RBXScriptConnection? = watched[target]
		if connection ~= nil then
			connection:Disconnect()
			watched[target] = nil
		end
	end

	for _, target in CollectionService:GetTagged(CarryConstants.TAG) do
		watch(target)
	end
	table.insert(connections, CollectionService:GetInstanceAddedSignal(CarryConstants.TAG):Connect(watch))
	table.insert(connections, CollectionService:GetInstanceRemovedSignal(CarryConstants.TAG):Connect(unwatch))
	table.insert(
		connections,
		RunService.RenderStepped:Connect(function(dt: number)
			for target, grab in active do
				if grab.step(dt) then
					active[target] = nil
				end
			end
		end)
	)

	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		for _, connection in watched do
			connection:Disconnect()
		end
		table.clear(watched)
		for _, grab in active do
			grab.cancel()
		end
		table.clear(active)
	end
end

return AnimationCarryGrabSystem
