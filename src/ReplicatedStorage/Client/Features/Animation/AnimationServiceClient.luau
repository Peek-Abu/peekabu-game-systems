--!strict
--[=[
	AnimationServiceClient: the client's animation surface.

	Everything plays on this client's own character through the SAME per-Animator `AnimationPlayerSystem`
	that AnimationLocomotionHumanoidSystem uses, so bookkeeping is one truth:
	- local plays (UI, the F4 panel) through `play` / `stop` / `stopClass`;
	- server-granted actions (`ActionStarted` / `ActionStopped` from AnimationServiceServer), one handle per
	  layer — a new grant on a layer replaces the one before it. The engine replicates the owner's
	  character animations to every other client, so nothing here sends anything back.

	Spec-exempt: a network-bound client shell (the DebuggerServiceClient precedent) — every rule it
	routes to lives in specced modules (`AnimationPlayerSystem`, the registry).

	@class AnimationServiceClient
]=]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationShared = ReplicatedStorage.Shared.Features.Animation
local AnimationEvents = require(AnimationShared.Net.AnimationEvents)
local AnimationPlayerSystem = require(AnimationShared.Systems.AnimationPlayerSystem)
local AnimationPlayerEngineSystem = require(AnimationShared.Systems.AnimationPlayerEngineSystem)
local AnimationRegistry = require(AnimationShared.Data.AnimationRegistry)
local AnimationTypes = require(AnimationShared.Data.AnimationTypes)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)

local log = Logger.new("AnimationService")

-- The granted action playing on each layer of the local character (see `start`).
local grantedByLayer: { [string]: AnimationPlayerSystem.PlayHandle } = {}

export type AnimationServiceClient = {
	dependencies: { string },
	start: (self: AnimationServiceClient) -> (),

	play: (
		self: AnimationServiceClient,
		id: string,
		opts: AnimationPlayerSystem.PlayOpts?
	) -> (AnimationPlayerSystem.PlayHandle?, string?),
	stop: (self: AnimationServiceClient, id: string, fadeTime: number?) -> boolean,
	stopClass: (
		self: AnimationServiceClient,
		class: AnimationTypes.InterruptionClass,
		fadeTime: number?
	) -> AnimationPlayerSystem.StopClassResult,
	playing: (self: AnimationServiceClient) -> { AnimationPlayerSystem.PlayingInfo },
	counters: (self: AnimationServiceClient) -> AnimationPlayerSystem.Counters,
	reportTracks: (self: AnimationServiceClient) -> (),
	probeAssets: (self: AnimationServiceClient) -> (),
}

-- The local character's player, resolved fresh each call: the runtime memoizes per Animator, so a
-- respawn naturally lands on a new player and a stale character on none.
local function localAnimationPlayer(): AnimationPlayerSystem.AnimationPlayerSystem?
	local character = Players.LocalPlayer.Character
	if character == nil then
		return nil
	end
	return AnimationPlayerEngineSystem.forCharacter(character)
end

local AnimationServiceClient: AnimationServiceClient = {
	dependencies = {},

	--[=[
		Plays a registered animation on the local character.
		@param id string
		@param opts AnimationPlayerSystem.PlayOpts?
		@return AnimationPlayerSystem.PlayHandle?, string?
	]=]
	play = function(_self, id, opts)
		local player = localAnimationPlayer()
		if player == nil then
			return nil, "no-character"
		end
		local handle, reason = player:play(id, opts)
		if handle == nil then
			log:warn(`play "{id}" failed: {reason or "?"}`)
		end
		return handle, reason
	end,

	--[=[
		Stops one animation on the local character.
		@param id string
		@param fadeTime number?
		@return boolean -- whether anything was playing under that id
	]=]
	stop = function(_self, id, fadeTime)
		local player = localAnimationPlayer()
		if player == nil then
			return false
		end
		return player:stop(id, fadeTime)
	end,

	--[=[
		Bulk-stops a declared class on the local character (only `attack` is actionable — see
		AnimationPlayerSystem.stopClass).
		@param class AnimationTypes.InterruptionClass
		@param fadeTime number?
		@return AnimationPlayerSystem.StopClassResult
	]=]
	stopClass = function(_self, class, fadeTime)
		local player = localAnimationPlayer()
		if player == nil then
			return { stopped = {}, refused = false }
		end
		return player:stopClass(class, fadeTime)
	end,

	--[=[
		Live-track snapshot for the F4 Animations panel.
		@return { AnimationPlayerSystem.PlayingInfo }
	]=]
	playing = function(_self)
		local player = localAnimationPlayer()
		if player == nil then
			return {}
		end
		return player:playing()
	end,

	--[=[
		Cache counters for the F4 Animations panel (loads vs hits — the proof the per-play-load
		disease stays dead).
		@return AnimationPlayerSystem.Counters
	]=]
	counters = function(_self)
		local player = localAnimationPlayer()
		if player == nil then
			return { loads = 0, hits = 0 }
		end
		return player:counters()
	end,

	--[=[
		Logs the live bookkeeping (the anim-tracks command's landing).
	]=]
	reportTracks = function(self)
		local snapshot = self:playing()
		if #snapshot == 0 then
			log:info("tracks: none playing")
			return
		end
		local counters = self:counters()
		log:info(`tracks: {#snapshot} playing · cache loads={counters.loads} hits={counters.hits}`)
		-- `ipairs`: playing() sorts by id and the log should read in that order.
		for _, info in ipairs(snapshot) do
			log:info(`  {info.id} [{info.interruption}] {info.assetId}{if info.looped then " (looped)" else ""}`)
		end
	end,

	--[=[
		Probes every registry asset id with PreloadAsync and logs failures by REGISTRY KEY (so a
		dead id is a one-line registry fix). The anim-report command's asset half; Task 6 wires the
		same probe at boot.
	]=]
	probeAssets = function(_self)
		task.spawn(function()
			-- assetId -> EVERY registry key that references it: entries may alias one asset, and
			-- a 1:1 map would misattribute a dead asset to whichever key landed last (Qodo
			-- PR #13). The probe's whole promise is "the failing key is the one-line fix".
			local keysByAsset: { [string]: { string } } = {}
			local instances: { Instance } = {}
			for _, key in AnimationRegistry.ids() do
				local def = AnimationRegistry.get(key)
				if def == nil then
					continue
				end
				local assets = { def.assetId }
				local variants = def.variants
				if variants ~= nil then
					for _, variantId in variants do
						table.insert(assets, variantId)
					end
				end
				for _, assetId in assets do
					local keys = keysByAsset[assetId]
					if keys == nil then
						-- First key to claim this asset also owns its single preload: probing an
						-- aliased asset twice would only slow the sweep.
						keysByAsset[assetId] = { key }
						local animation = Instance.new("Animation")
						animation.AnimationId = assetId
						table.insert(instances, animation)
					else
						table.insert(keys, key)
					end
				end
			end
			local failures = 0
			ContentProvider:PreloadAsync(instances, function(contentId: string, status: Enum.AssetFetchStatus)
				if status ~= Enum.AssetFetchStatus.Success then
					failures += 1
					local keys = keysByAsset[contentId]
					local attribution = if keys ~= nil then table.concat(keys, ", ") else "?"
					log:warn(`asset probe FAILED: "{attribution}" -> {contentId} ({status.Name})`)
				end
			end)
			if failures == 0 then
				log:info(`asset probe: all {#instances} registry asset(s) load`)
			else
				log:warn(`asset probe: {failures}/{#instances} registry asset(s) FAILED — see lines above`)
			end
			for _, instance in instances do
				instance:Destroy()
			end
		end)
	end,

	--[=[
		Wires the granted-action and diagnostic listeners (anim-tracks, anim-report) and runs the
		boot-time asset probe.
	]=]
	start = function(self)
		AnimationEvents.packets.ActionStarted.listen(function(data)
			local layer = AnimationTypes.layerAt(data.layer)
			local id = AnimationRegistry.idForWire(data.wireId)
			if layer == nil or id == nil then
				log:warn(`granted action ignored: unknown layer {data.layer} or wire id {data.wireId}`)
				return
			end
			local previous = grantedByLayer[layer]
			if previous ~= nil then
				previous:stop()
			end
			local handle = self:play(id, { variant = data.variant, speed = data.speedMilli / 1000 })
			if handle ~= nil then
				grantedByLayer[layer] = handle
			else
				grantedByLayer[layer] = nil
			end
		end)

		AnimationEvents.packets.ActionStopped.listen(function(data)
			local layer = AnimationTypes.layerAt(data.layer)
			local handle = if layer ~= nil then grantedByLayer[layer] else nil
			if layer ~= nil and handle ~= nil then
				handle:stop()
				grantedByLayer[layer] = nil
			end
		end)

		-- A new character starts with no grants (its old tracks died with the old character).
		Players.LocalPlayer.CharacterAdded:Connect(function()
			table.clear(grantedByLayer)
		end)

		AnimationEvents.packets.ReportTracks.listen(function(_payload: boolean)
			self:reportTracks()
		end)

		AnimationEvents.packets.ProbeAssets.listen(function(_payload: boolean)
			self:probeAssets()
		end)

		-- Boot-time registry sweep (spec Decision 6): PreloadAsync every registry asset once at
		-- join — warms the content cache ahead of first character use and REPORTS dead ids by
		-- registry key (never throws; a dead id is a one-line registry fix, not a broken boot).
		self:probeAssets()
	end,
}

return AnimationServiceClient
