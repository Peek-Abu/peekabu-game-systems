--!strict
--[=[
	VacuumServiceClient: click once to vacuum (owner pick I1, 2026-11-19; VacuumLatchRules). A press of the `vacuum`
	action (left mouse, gamepad R2, or the Shift HUD's touch button through pressVacuum / releaseVacuum) latches the
	vacuum on until its pile is clean, the player walks out of reach, starts carrying or puts it away, or presses again;
	with VacuumConstants.LATCH off it is the old hold. While on (Cleanup Crew spec §4), it re-aims every
	AIM_INTERVAL at the pile the vacuum is on (VacuumTargetRules: the wand's floor head and the body's facing,
	not the camera; the pile already being cleaned is kept while it is in reach) and keeps Interaction's channel
	on it; letting go stops the channel, and the pile keeps its progress. Nothing is sent while carrying. A grimy
	valuable lying in the open (VacuumConstants.GRIME_TAG, not buried and not held) is aimed at exactly like a pile:
	vacuuming it cleans it (the loot loop).
	The server decides everything. VacuumFeedbackSystem plays the suction, whine, pop and canister sounds;
	VacuumMotionSystem moves every holder's wand and body (aim, brace) on this client.
	VacuumFaceSystem turns the local body to face the camera while the wand is out (off: face.enabled).

	Spec-exempt shell (Input, CollectionService); the aim is the specced VacuumTargetRules.

	@class VacuumServiceClient
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local VacuumLatchRules = require(ReplicatedStorage.Client.Features.Vacuum.Rules.VacuumLatchRules)
local VacuumTargetRules = require(ReplicatedStorage.Shared.Features.Vacuum.Rules.VacuumTargetRules)
local VacuumMotionRigSystem = require(ReplicatedStorage.Shared.Features.Vacuum.Systems.VacuumMotionRigSystem)
local VacuumFeedbackSystem = require(ReplicatedStorage.Client.Features.Vacuum.Systems.VacuumFeedbackSystem)
local VacuumLookSystem = require(ReplicatedStorage.Client.Features.Vacuum.Systems.VacuumLookSystem)
local VacuumFaceSystem = require(ReplicatedStorage.Client.Features.Vacuum.Systems.VacuumFaceSystem)
local VacuumMotionSystem = require(ReplicatedStorage.Client.Features.Vacuum.Systems.VacuumMotionSystem)
local VacuumPullSystem = require(ReplicatedStorage.Client.Features.Vacuum.Systems.VacuumPullSystem)
local VacuumCameraSystem = require(ReplicatedStorage.Client.Features.Vacuum.Systems.VacuumCameraSystem)
local CarryServiceClient = require(ReplicatedStorage.Client.Features.Carry.CarryServiceClient)
local InputActionRegistry = require(ReplicatedStorage.Client.Features.Input.Data.InputActionRegistry)
local InputServiceClient = require(ReplicatedStorage.Client.Features.Input.InputServiceClient)
local InteractionServiceClient = require(ReplicatedStorage.Client.Features.Interaction.InteractionServiceClient)

local holding = false
-- Fires with `holding` whenever the vacuum turns on or off (the phone's VACUUM button stays lit while latched on).
local changed: SignalTyped.Signal<boolean> = SignalTyped.new()
-- N12 hysteresis: the last aimed pile and whether the aim already missed once this hold.
local lastTarget: Instance? = nil
-- Bumped by every beginVacuum so a stale aim loop from a quick release and re-press exits.
local generation = 0
local missed = false
local unbinders: { () -> () } = {}

-- The pile the local player's vacuum is on (VacuumTargetRules: near the wand's floor head, underfoot, or in
-- front of the body; never the camera), keeping `current` while it is in reach; nil when none is.
-- The floor head the pick measures from: the nozzle where the aim lays it (the same rule the server re-checks with,
-- VacuumConstants.SUCTION_FOLLOWS_NOZZLE), else the Tool's floor-head part.
local function nozzleOf(character: Model, root: BasePart, head: Instance?): VacuumTargetRules.Head?
	if VacuumConstants.SUCTION_FOLLOWS_NOZZLE then
		local nozzle = VacuumMotionRigSystem.nozzleHead(
			character,
			VacuumLookSystem.yawOf(Players.LocalPlayer, character, root),
			VacuumLookSystem.pitchOf(Players.LocalPlayer, character)
		)
		if nozzle ~= nil then
			return nozzle
		end
	end
	return if head ~= nil and head:IsA("BasePart") then VacuumTargetRules.head(head.CFrame, head.Size) else nil
end

local function aimedPile(current: Instance?): Instance?
	local character = Players.LocalPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if character == nil or root == nil or not root:IsA("BasePart") then
		return nil
	end
	local tool = character:FindFirstChild(VacuumConstants.TOOL_NAME)
	local head = if tool ~= nil then tool:FindFirstChild(VacuumConstants.FLOOR_HEAD_NAME) else nil
	local parts: { BasePart } = {}
	local piles: { VacuumTargetRules.Pile } = {}
	local currentIndex: number? = nil
	local function consider(target: Instance)
		if target:IsA("BasePart") then
			table.insert(parts, target)
			table.insert(piles, {
				position = target.Position,
				radius = VacuumTargetRules.radius(
					target.Size,
					target:GetAttribute(VacuumConstants.BASE_SIZE_ATTRIBUTE)
				),
			})
			if target == current then
				currentIndex = #parts
			end
		end
	end
	for _, pile in CollectionService:GetTagged(VacuumConstants.PILE_TAG) do
		consider(pile)
	end
	-- Grimy valuables: only one lying in the open (not buried under a pile, not in anyone's hands).
	for _, item in CollectionService:GetTagged(VacuumConstants.GRIME_TAG) do
		if
			item:GetAttribute(CargoConstants.HIDDEN_ATTRIBUTE) ~= true
			and item:GetAttribute(CarryConstants.CARRIED_BY_ATTRIBUTE) == nil
		then
			consider(item)
		end
	end
	local index = VacuumTargetRules.pick(
		root.Position,
		root.CFrame.LookVector,
		nozzleOf(character, root, head),
		piles,
		VacuumTargetRules.withCone(
			VacuumConstants.TARGET,
			VacuumTargetRules.coneOn(
				RunService:IsStudio(),
				Workspace:GetAttribute(VacuumConstants.DEV_CONE_ATTRIBUTE),
				VacuumConstants.TARGET.cone ~= false
			)
		),
		currentIndex
	)
	return if index ~= nil then parts[index] else nil
end

local function localTool(): Tool?
	local player = Players.LocalPlayer
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	local candidate = if character ~= nil then character:FindFirstChild(VacuumConstants.TOOL_NAME) else nil
	if candidate == nil and backpack ~= nil then
		candidate = backpack:FindFirstChild(VacuumConstants.TOOL_NAME)
	end
	return if candidate ~= nil
			and candidate:IsA("Tool")
			and candidate:GetAttribute(VacuumConstants.TOOL_ATTRIBUTE) == true
		then candidate
		else nil
end

local function selected(): boolean
	local tool = localTool()
	local character = Players.LocalPlayer.Character
	return tool ~= nil and character ~= nil and tool.Parent == character
end

export type VacuumServiceClient = {
	dependencies: { string },
	changed: SignalTyped.Signal<boolean>,
	init: (self: VacuumServiceClient) -> (),
	start: (self: VacuumServiceClient) -> (),
	stop: (self: VacuumServiceClient) -> (),
	-- A press / a release of the vacuum button (the latch decides: start, stop, or nothing).
	pressVacuum: (self: VacuumServiceClient) -> (),
	releaseVacuum: (self: VacuumServiceClient) -> (),
	beginVacuum: (self: VacuumServiceClient) -> (),
	endVacuum: (self: VacuumServiceClient) -> (),
	isVacuuming: (self: VacuumServiceClient) -> boolean,
	equipVacuum: (self: VacuumServiceClient) -> boolean,
}

local VacuumServiceClient: VacuumServiceClient = {
	changed = changed,
	dependencies = {
		"InputServiceClient",
		"InteractionServiceClient",
		"CarryServiceClient",
		"SoundServiceClient",
		"StateSyncServiceClient",
	},

	init = function(_self)
		if InputActionRegistry.get(VacuumConstants.ACTION) == nil then
			InputActionRegistry.register(VacuumConstants.ACTION, {
				context = "gameplay",
				bindings = { keyboard = { Enum.UserInputType.MouseButton1 }, gamepad = { Enum.KeyCode.ButtonR2 } },
				description = "Press once to vacuum the pile in front of you",
			})
		end
	end,

	start = function(self)
		table.insert(
			unbinders,
			InputServiceClient:bind(VacuumConstants.ACTION, function(phase)
				if phase == "begin" then
					self:pressVacuum()
				else
					self:releaseVacuum()
				end
			end)
		)
		VacuumPullSystem.start()
		VacuumFeedbackSystem.start()
		VacuumMotionSystem.start({
			localActive = function()
				return holding and lastTarget ~= nil
			end,
		})
		VacuumFaceSystem.start()
		VacuumCameraSystem.start({
			localActive = function()
				return holding and lastTarget ~= nil
			end,
		})
	end,

	stop = function(self)
		self:endVacuum()
		VacuumCameraSystem.stop()
		VacuumFaceSystem.stop()
		VacuumFeedbackSystem.stop()
		VacuumMotionSystem.stop()
		VacuumPullSystem.stop()
		for _, unbind in unbinders do
			unbind()
		end
		table.clear(unbinders)
	end,

	pressVacuum = function(self)
		if VacuumLatchRules.press(VacuumConstants.LATCH, holding) == "end" then
			self:endVacuum()
		else
			self:beginVacuum()
		end
	end,

	releaseVacuum = function(self)
		if VacuumLatchRules.release(VacuumConstants.LATCH) then
			self:endVacuum()
		end
	end,

	--[=[
		Starts vacuuming whatever pile the player faces, re-aiming until endVacuum (latched: until its pile is clean or
		out of reach).
	]=]
	beginVacuum = function(self)
		if holding or not selected() then
			return
		end
		holding = true
		changed:Fire(true)
		generation += 1
		local mine = generation
		lastTarget = nil
		missed = false
		local startedAt = os.clock()
		local hadTarget = false
		-- The pile a latch started on (it never moves on to another).
		local locked: Instance? = nil
		task.spawn(function()
			while holding and mine == generation do
				local target = if CarryServiceClient:isCarrying() or not selected() then nil else aimedPile(lastTarget)
				if target ~= nil and not VacuumLatchRules.allows(VacuumConstants.LATCH, locked, target) then
					target = nil
				end
				if target ~= nil then
					lastTarget = target
					locked = locked or target
					hadTarget = true
					missed = false
					InteractionServiceClient:startChannel(target)
				elseif
					lastTarget ~= nil
					and lastTarget.Parent ~= nil
					and not missed
					and not CarryServiceClient:isCarrying()
					and selected()
				then
					-- Aim dropped: keep the channel one more interval so edge flapping does not burn the rate limit.
					missed = true
					InteractionServiceClient:startChannel(lastTarget)
				else
					lastTarget = nil
					missed = false
					InteractionServiceClient:stopChannel()
					if
						not VacuumLatchRules.keepWithoutTarget(
							VacuumConstants.LATCH,
							hadTarget,
							os.clock() - startedAt,
							VacuumConstants.LATCH_GRACE
						)
					then
						-- Latched: the pile is clean or out of reach (or nothing was ever in reach); the next pile is a new press.
						self:endVacuum()
						return
					end
				end
				task.wait(VacuumConstants.AIM_INTERVAL)
			end
		end)
	end,

	endVacuum = function(_self)
		local was = holding
		holding = false
		InteractionServiceClient:stopChannel()
		if was then
			changed:Fire(false)
		end
	end,

	equipVacuum = function(_self)
		if CarryServiceClient:isCarrying() then
			return false
		end
		local character = Players.LocalPlayer.Character
		local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
		local tool = localTool()
		if humanoid == nil or humanoid.Health <= 0 or tool == nil then
			return false
		end
		humanoid:EquipTool(tool)
		return selected()
	end,

	isVacuuming = function(_self)
		return holding
	end,
}

return VacuumServiceClient
