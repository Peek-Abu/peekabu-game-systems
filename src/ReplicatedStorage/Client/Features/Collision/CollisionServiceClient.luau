--!strict
--[=[
	CollisionServiceClient (R6 spec 2026-10-08 §5): players are solid to each other.

	- Bodies come and go through ReplicationServiceClient's `bodySpawned` / `bodyDespawned`. Another
	  player's puppet gets a blocker; the local rig (every respawn) gets the self-collider. A pooled puppet
	  reused by another player is despawn → spawn, so a blocker never carries over.
	- Every PreSimulation: CollisionBlockerSystem.step (the range band at 10 Hz), then
	  CollisionSlideOffSystem.step. Nothing runs without a local rig.
	- Workspace attribute `CollisionDebug = true` draws the capsules (read on change, never per frame).
	- F4: puppets, solid, flips and slide-off pushes in the last second, and the step's average ms.

	Spec-exempt shell (signals, RunService); its cores CollisionBlockerSystem and CollisionSlideOffSystem are
	specced. No server rules depend on it: each client stops only its own body.

	@class CollisionServiceClient
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local CollisionConstants = require(ReplicatedStorage.Shared.Features.Collision.Data.CollisionConstants)
local ReplicationServiceClient = require(ReplicatedStorage.Client.Features.Replication.ReplicationServiceClient)
local CollisionBlockerSystem = require(ReplicatedStorage.Client.Features.Collision.Systems.CollisionBlockerSystem)
local CollisionSlideOffSystem = require(ReplicatedStorage.Client.Features.Collision.Systems.CollisionSlideOffSystem)

type Window = { started: number, steps: number, stepSeconds: number, writesAtStart: number, pushes: number }
type Summary = { flipsPerSecond: number, pushesPerSecond: number, stepMs: number }

local log = Logger.new("CollisionServiceClient")
local janitor = Janitor.new()
local localPlayer = Players.LocalPlayer
local blockers = CollisionBlockerSystem.new(false)
local window: Window = { started = os.clock(), steps = 0, stepSeconds = 0, writesAtStart = 0, pushes = 0 }
local summary: Summary = { flipsPerSecond = 0, pushesPerSecond = 0, stepMs = 0 }

local function debugOn(): boolean
	return Workspace:GetAttribute(CollisionConstants.DEBUG_ATTRIBUTE) == true
end

local function onBodySpawned(player: Player, rig: Model)
	if player == localPlayer then
		CollisionBlockerSystem.addSelf(blockers, rig)
	else
		CollisionBlockerSystem.addPuppet(blockers, rig)
	end
end

local function onBodyDespawned(_player: Player, rig: Model)
	CollisionBlockerSystem.remove(blockers, rig)
end

local function step(dt: number)
	local started = os.clock()
	local root = CollisionBlockerSystem.rootOf(ReplicationServiceClient:getLocalRig())
	if root ~= nil then
		CollisionBlockerSystem.step(blockers, dt, root.Position)
		if CollisionSlideOffSystem.step(blockers, root) then
			window.pushes += 1
		end
	end
	window.steps += 1
	window.stepSeconds += os.clock() - started
	local elapsed = started - window.started
	if elapsed >= 1 then
		summary = {
			flipsPerSecond = (blockers.writes - window.writesAtStart) / elapsed,
			pushesPerSecond = window.pushes / elapsed,
			stepMs = window.stepSeconds / window.steps * 1000,
		}
		window = { started = started, steps = 0, stepSeconds = 0, writesAtStart = blockers.writes, pushes = 0 }
	end
end

export type CollisionServiceClient = {
	dependencies: { string },
	init: (self: CollisionServiceClient) -> (),
	start: (self: CollisionServiceClient) -> (),
	stop: (self: CollisionServiceClient) -> (),
	getState: (
		self: CollisionServiceClient
	) -> {
		puppets: number,
		solid: number,
		own: boolean,
		flipsPerSecond: number,
		pushesPerSecond: number,
		stepMs: number,
	},
}

local CollisionServiceClient: CollisionServiceClient = {
	dependencies = { "ReplicationServiceClient" },

	init = function(_self)
		log:debug("CollisionServiceClient initialized")
	end,

	start = function(_self)
		CollisionBlockerSystem.setDebug(blockers, debugOn())
		janitor:Add(
			Workspace:GetAttributeChangedSignal(CollisionConstants.DEBUG_ATTRIBUTE):Connect(function()
				CollisionBlockerSystem.setDebug(blockers, debugOn())
			end),
			"Disconnect"
		)
		janitor:Add(ReplicationServiceClient.bodySpawned:Connect(onBodySpawned), "Disconnect")
		janitor:Add(ReplicationServiceClient.bodyDespawned:Connect(onBodyDespawned), "Disconnect")
		for _, player in Players:GetPlayers() do
			local rig = ReplicationServiceClient:getRig(player)
			if rig ~= nil then
				onBodySpawned(player, rig)
			end
		end
		janitor:Add(RunService.PreSimulation:Connect(step), "Disconnect")
	end,

	stop = function(_self)
		janitor:Cleanup()
		CollisionBlockerSystem.clear(blockers)
	end,

	getState = function(_self)
		local counts = CollisionBlockerSystem.counts(blockers)
		return {
			puppets = counts.puppets,
			solid = counts.solid,
			own = blockers.own ~= nil,
			flipsPerSecond = summary.flipsPerSecond,
			pushesPerSecond = summary.pushesPerSecond,
			stepMs = summary.stepMs,
		}
	end,
}

return CollisionServiceClient
