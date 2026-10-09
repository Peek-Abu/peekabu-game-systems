--!strict
--[=[
	InteractionServiceServer: server-validated interactions on tagged world objects (design:
	docs/superpowers/specs/2026-10-09-interaction-design.md).

	Every object tagged `Interactable` with a registered `InteractionKind` gets a ProximityPrompt
	configured from its kind. A trigger is re-checked here (InteractionRules: character, enabled,
	distance + tolerance, per-player-per-object cooldown) before the kind's handler runs. One handler per
	kind: `onInteract(kind, function(player, target) ... end)`.

	Spec-exempt shell (CollectionService, ProximityPrompts, Players); the decision is the specced
	InteractionRules and InteractionCooldownTracker.

	@class InteractionServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local InteractionData = ReplicatedStorage.Shared.Features.Interaction.Data
local Observers = require(ReplicatedStorage.Packages.Observers)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local InteractionConstants = require(InteractionData.InteractionConstants)
local InteractionRegistry = require(InteractionData.InteractionRegistry)
local InteractionRules = require(ServerScriptService.Features.Interaction.Rules.InteractionRules)
local InteractionCooldownTracker = require(ServerScriptService.Features.Interaction.State.InteractionCooldownTracker)

export type Handler = (player: Player, target: Instance) -> ()

local log = Logger.new("InteractionServiceServer")

local handlers: { [string]: Handler } = {}
local cooldowns = InteractionCooldownTracker.new()
local targetIds: { [Instance]: number } = {}
local nextTargetId = 0
local counters = { accepted = 0, refused = 0, handlerErrors = 0, untyped = 0 }
local stoppers: { () -> () } = {}

-- The part a prompt hangs on and distance is measured to: the object itself, or a Model's PrimaryPart
-- (else its first BasePart).
local function rootPartOf(target: Instance): BasePart?
	if target:IsA("BasePart") then
		return target
	end
	if target:IsA("Model") then
		return target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function isEnabled(target: Instance): boolean
	return target:GetAttribute(InteractionConstants.ENABLED_ATTRIBUTE) ~= false
end

local function onTriggered(target: Instance, kind: string, root: BasePart, player: Player)
	local def = InteractionRegistry.get(kind)
	local handler = handlers[kind]
	local targetId = targetIds[target]
	if def == nil or handler == nil or targetId == nil then
		counters.refused += 1
		return
	end
	local character = player.Character
	local playerRoot = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local hasCharacter = playerRoot ~= nil and playerRoot:IsA("BasePart")
	local distance = if playerRoot ~= nil and playerRoot:IsA("BasePart")
		then (playerRoot.Position - root.Position).Magnitude
		else math.huge
	local now = os.clock()
	local ok, reason = InteractionRules.check({
		hasCharacter = hasCharacter,
		distance = distance,
		maxDistance = def.maxDistance or InteractionConstants.DEFAULT_MAX_DISTANCE,
		tolerance = InteractionConstants.DISTANCE_TOLERANCE,
		enabled = isEnabled(target),
		cooldownRemaining = cooldowns:remaining(player.UserId, targetId, now, def.cooldown or 0),
	})
	if not ok then
		counters.refused += 1
		log:debug(`refused "{kind}" for {player.Name}: {reason or "?"}`)
		return
	end
	cooldowns:mark(player.UserId, targetId, now)
	counters.accepted += 1
	local success, err = pcall(function()
		handler(player, target)
	end)
	if not success then
		counters.handlerErrors += 1
		log:error(`"{kind}" handler failed: {tostring(err)}`)
	end
end

-- Builds the prompt for one tagged object; returns its cleanup.
local function observe(target: Instance): (() -> ())?
	local kind = target:GetAttribute(InteractionConstants.KIND_ATTRIBUTE)
	local def = if type(kind) == "string" then InteractionRegistry.get(kind) else nil
	local root = rootPartOf(target)
	if type(kind) ~= "string" or def == nil or root == nil then
		counters.untyped += 1
		log:warn(
			`{target:GetFullName()} is Interactable but has no registered {InteractionConstants.KIND_ATTRIBUTE} or part`
		)
		return nil
	end
	nextTargetId += 1
	local targetId = nextTargetId
	targetIds[target] = targetId

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = InteractionConstants.PROMPT_NAME
	prompt.ActionText = def.actionText
	prompt.ObjectText = def.objectText or ""
	prompt.HoldDuration = def.holdDuration or 0
	prompt.MaxActivationDistance = def.maxDistance or InteractionConstants.DEFAULT_MAX_DISTANCE
	prompt.RequiresLineOfSight = def.requiresLineOfSight == true
	prompt.Enabled = isEnabled(target)
	prompt.Parent = root

	local triggered = prompt.Triggered:Connect(function(player)
		onTriggered(target, kind, root, player)
	end)
	local enabledChanged = target:GetAttributeChangedSignal(InteractionConstants.ENABLED_ATTRIBUTE):Connect(function()
		prompt.Enabled = isEnabled(target)
	end)
	return function()
		triggered:Disconnect()
		enabledChanged:Disconnect()
		prompt:Destroy()
		targetIds[target] = nil
		cooldowns:forgetTarget(targetId)
	end
end

export type InteractionServiceServer = {
	dependencies: { string },
	start: (self: InteractionServiceServer) -> (),
	stop: (self: InteractionServiceServer) -> (),
	getState: (self: InteractionServiceServer) -> { [string]: any },
	onInteract: (self: InteractionServiceServer, kind: string, handler: Handler) -> (),
	setEnabled: (self: InteractionServiceServer, target: Instance, enabled: boolean) -> (),
}

local InteractionServiceServer: InteractionServiceServer = {
	dependencies = {},

	--[=[
		Starts observing tagged objects (existing and future) and forgets a player's cooldowns on leave.
	]=]
	start = function(_self)
		table.insert(stoppers, Observers.observeTag(InteractionConstants.TAG, observe))
		local leaving = Players.PlayerRemoving:Connect(function(player)
			cooldowns:forgetPlayer(player.UserId)
		end)
		table.insert(stoppers, function()
			leaving:Disconnect()
		end)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
	end,

	--[=[
		Sets THE handler for a registered kind. Errors on an unregistered kind or a second handler.
	]=]
	onInteract = function(_self, kind, handler)
		assert(InteractionRegistry.has(kind), `interaction kind "{kind}" is not registered`)
		assert(handlers[kind] == nil, `interaction kind "{kind}" already has a handler`)
		handlers[kind] = handler
	end,

	--[=[
		Shows or hides an object's prompt (and refuses triggers while hidden).
	]=]
	setEnabled = function(_self, target, enabled)
		target:SetAttribute(InteractionConstants.ENABLED_ATTRIBUTE, enabled)
	end,

	getState = function(_self)
		local objects = 0
		for _ in targetIds do
			objects += 1
		end
		return { objects = objects, counters = table.clone(counters) }
	end,
}

return InteractionServiceServer
