--!strict
--[=[
	DeathServiceClient: spectating while the local player is dead (design:
	docs/superpowers/specs/2026-10-09-death-design.md).

	While the local player's public `dead` field is set, the camera follows a living player through a
	CameraServiceClient `default` mode with `subject`. `spectateNext` / `spectatePrev` cycle; a target who
	dies or leaves is replaced; respawning (the field clearing) ends it. Candidates and cycling are the
	pure DeathSpectateRules.

	Spec-exempt shell (Camera, Input, Charm, Players).

	@class DeathServiceClient
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local Observers = require(ReplicatedStorage.Packages.Observers)
local DeathConstants = require(ReplicatedStorage.Shared.Features.Death.Data.DeathConstants)
local DeathSpectateRules = require(ReplicatedStorage.Shared.Features.Death.Rules.DeathSpectateRules)
local StateSyncConstants = require(ReplicatedStorage.Shared.Features.StateSync.Data.StateSyncConstants)
local CameraServiceClient = require(ReplicatedStorage.Client.Features.Camera.CameraServiceClient)
local InputActionRegistry = require(ReplicatedStorage.Client.Features.Input.Data.InputActionRegistry)
local InputServiceClient = require(ReplicatedStorage.Client.Features.Input.InputServiceClient)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

local enabled = true
local filter: ((userId: number) -> boolean)? = nil
local target: number? = nil
local modeToken: number? = nil
local watchedHumanoid: Humanoid? = nil
local stoppers: { () -> () } = {}

local function isLocalDead(): boolean
	local entry = StateSyncClientStore.publicPlayers()[StateSyncConstants.publicEntryKey(Players.LocalPlayer.UserId)]
	return entry ~= nil and entry[DeathConstants.PUBLIC_FIELD] == true
end

local function humanoidFor(userId: number): Humanoid?
	local player = Players:GetPlayerByUserId(userId)
	local character = if player ~= nil then player.Character else nil
	return if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
end

local function isWatchable(userId: number): boolean
	local humanoid = humanoidFor(userId)
	if humanoid == nil or humanoid.Health <= 0 then
		return false
	end
	local gameFilter = filter
	return gameFilter == nil or gameFilter(userId)
end

local function endSpectating()
	local token = modeToken
	if token ~= nil then
		CameraServiceClient:removeMode(token)
	end
	modeToken = nil
	target = nil
	watchedHumanoid = nil
end

-- Picks (or keeps) a target and points the camera at it. `direction`: 1 / -1 cycles, 0 keeps.
local function refresh(direction: number)
	if not enabled or not isLocalDead() then
		endSpectating()
		return
	end
	local candidates = DeathSpectateRules.candidates(
		StateSyncClientStore.publicPlayers(),
		Players.LocalPlayer.UserId,
		DeathConstants.PUBLIC_FIELD,
		isWatchable
	)
	local nextTarget = DeathSpectateRules.step(candidates, target, direction)
	local humanoid = if nextTarget ~= nil then humanoidFor(nextTarget) else nil
	if nextTarget == target and humanoid == watchedHumanoid and modeToken ~= nil then
		return
	end
	endSpectating()
	if nextTarget ~= nil and humanoid ~= nil then
		target = nextTarget
		watchedHumanoid = humanoid
		modeToken =
			CameraServiceClient:pushMode({ kind = "default", subject = humanoid }, DeathConstants.SPECTATE_PRIORITY)
	end
end

local function registerAction(id: string, keyboard: Enum.KeyCode, gamepad: Enum.KeyCode, description: string)
	if not InputActionRegistry.has(id) then
		InputActionRegistry.register(id, {
			context = "gameplay",
			bindings = { keyboard = { keyboard }, gamepad = { gamepad } },
			description = description,
		})
	end
end

export type DeathServiceClient = {
	dependencies: { string },
	init: (self: DeathServiceClient) -> (),
	start: (self: DeathServiceClient) -> (),
	stop: (self: DeathServiceClient) -> (),
	isDead: (self: DeathServiceClient) -> boolean,
	spectating: (self: DeathServiceClient) -> number?,
	setSpectateEnabled: (self: DeathServiceClient, on: boolean) -> (),
	setSpectateFilter: (self: DeathServiceClient, filter: ((userId: number) -> boolean)?) -> (),
	getState: (self: DeathServiceClient) -> { [string]: any },
}

local DeathServiceClient: DeathServiceClient = {
	dependencies = { "StateSyncServiceClient", "CameraServiceClient", "InputServiceClient" },

	--[=[
		Registers the spectate actions (a game may register its own bindings first).
	]=]
	init = function(_self)
		registerAction(
			DeathConstants.SPECTATE_NEXT,
			Enum.KeyCode.Right,
			Enum.KeyCode.DPadRight,
			"Spectate the next player"
		)
		registerAction(
			DeathConstants.SPECTATE_PREV,
			Enum.KeyCode.Left,
			Enum.KeyCode.DPadLeft,
			"Spectate the previous player"
		)
	end,

	start = function(_self)
		table.insert(
			stoppers,
			Charm.subscribe(StateSyncClientStore.publicPlayers, function()
				refresh(0)
			end)
		)
		table.insert(
			stoppers,
			InputServiceClient:bind(DeathConstants.SPECTATE_NEXT, function(phase)
				if phase == "begin" then
					refresh(1)
				end
			end)
		)
		table.insert(
			stoppers,
			InputServiceClient:bind(DeathConstants.SPECTATE_PREV, function(phase)
				if phase == "begin" then
					refresh(-1)
				end
			end)
		)
		-- A watched player's respawn swaps their Humanoid without touching the public map.
		table.insert(
			stoppers,
			Observers.observeCharacter(function(_player: Player, _character: Model)
				refresh(0)
				return nil
			end)
		)
		table.insert(stoppers, endSpectating)
	end,

	stop = function(_self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
	end,

	isDead = function(_self)
		return isLocalDead()
	end,

	--[=[
		The userId being spectated, or nil.
	]=]
	spectating = function(_self)
		return target
	end,

	setSpectateEnabled = function(_self, on)
		enabled = on
		refresh(0)
	end,

	--[=[
		Narrows who may be watched (e.g. teammates only); nil allows every living player.
	]=]
	setSpectateFilter = function(_self, nextFilter)
		filter = nextFilter
		refresh(0)
	end,

	getState = function(_self)
		return { enabled = enabled, dead = isLocalDead(), spectating = target }
	end,
}

return DeathServiceClient
