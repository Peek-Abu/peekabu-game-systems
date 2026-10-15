--!strict
--[=[
	CargoGrimeSystem: cleaning grimy valuables (docs/superpowers/specs/2026-10-15-cleanup-crew-loot-loop-design.md §3.2-3.3).
	A valuable that is not spotless carries its size's grime channel (VacuumConstants.GRIME_KINDS, registered here at
	load; GRIME_SECONDS for one player, rates add up). Holding the vacuum on it is that channel: allowed when Vacuum
	says this player may vacuum this target (equipped, empty hands, the wand on it) and nobody carries the item. The
	server mirrors the channel's ChannelProgress into the item's cleanliness: a channel cleans the grime that was left
	when it started (CargoAppraisalFormulas.cleanAt), so when the channel forgets the item the next one starts from the
	cleanliness reached. Each change goes through the spawner's `setClean` (value, tag, appraisal, and no vacuum target
	once spotless); the channel's completion makes it spotless (`finish`).

	The first appraisal of an item is stamped (a toast in Shift's stamp style) to every crew member within
	APPRAISAL_TELL_DISTANCE, with the `cargoAppraise` sound at the item; a valuable banked unappraised is stamped to its
	banker (`banked`: the truck reveals it, as grimy as it is).

	`start` registers the channels and observes every item tagged VacuumConstants.GRIME_TAG; `update`, `finish` and
	`banked` are the specced core.

	@class CargoGrimeSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Observers = require(ReplicatedStorage.Packages.Observers)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)
local CargoAppraisalFormulas = require(ReplicatedStorage.Shared.Features.Cargo.Utils.CargoAppraisalFormulas)
local CargoFeedbackUtils = require(ReplicatedStorage.Shared.Features.Cargo.Utils.CargoFeedbackUtils)
local CarryConstants = require(ReplicatedStorage.Shared.Features.Carry.Data.CarryConstants)
local InteractionConstants = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionConstants)
local InteractionRegistry = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionRegistry)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local CargoSpawnSystem = require(ServerScriptService.Features.Cargo.Systems.CargoSpawnSystem)
local InteractionServiceServer = require(ServerScriptService.Features.Interaction.InteractionServiceServer)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)

-- Registered at load: the channels are a server rule (the client only names the item it aims at).
for size, kind in VacuumConstants.GRIME_KINDS do
	if not InteractionRegistry.hasChannel(kind) then
		InteractionRegistry.registerChannel(kind, {
			duration = VacuumConstants.GRIME_SECONDS[size],
			maxDistance = VacuumConstants.RANGE,
		})
	end
end

export type Deps = {
	spawner: CargoSpawnSystem.CargoSpawnSystem,
	-- Server time (an appraisal's timestamp: its tag's stamp pops while it is fresh).
	now: () -> number,
	-- A Cargo sound at a spot, for everyone near it (silent while pending).
	sound: (position: Vector3, id: string) -> (),
}

export type CargoGrimeSystem = {
	update: (self: CargoGrimeSystem, item: Instance) -> (),
	finish: (self: CargoGrimeSystem, item: Instance) -> (),
	banked: (self: CargoGrimeSystem, deposit: CargoTypes.Deposit, banker: Player) -> (),
	start: (self: CargoGrimeSystem) -> () -> (),
}

local function cleanOf(item: Instance): number
	local clean = item:GetAttribute(CargoConstants.CLEAN_ATTRIBUTE)
	return if type(clean) == "number" then clean else 0
end

local function stamp(player: Player, text: string)
	ToastServiceServer:send(player, {
		text = text,
		style = CargoConstants.APPRAISAL_TOAST_STYLE,
		duration = CargoConstants.APPRAISAL_TOAST_SECONDS,
	})
end

local CargoGrimeSystem = {}

function CargoGrimeSystem.new(deps: Deps): CargoGrimeSystem
	-- The cleanliness each running channel started from; absent while no channel tracks the item.
	local starts: { [Instance]: number } = {}
	setmetatable(starts, { __mode = "k" })
	local registered = false

	-- Just appraised by cleaning: the sound at the item and the stamp to the crew near it.
	local function announce(item: Instance)
		local entry = CargoFeedbackUtils.entryOf(item)
		if entry == nil or not item:IsA("BasePart") then
			return
		end
		local appraisal = entry.appraisal
		local variant = if appraisal ~= nil then appraisal.variant else nil
		local text = CargoFeedbackUtils.appraisalText(entry.kind, variant, entry.value, false)
		deps.sound(item.Position, "cargoAppraise")
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
			if
				root ~= nil
				and root:IsA("BasePart")
				and (root.Position - item.Position).Magnitude <= CargoConstants.APPRAISAL_TELL_DISTANCE
			then
				stamp(player, text)
			end
		end
	end

	local function setClean(item: Instance, clean: number)
		if deps.spawner:setClean(item, clean, deps.now()) then
			announce(item)
		end
	end

	local system: CargoGrimeSystem
	system = {
		--[=[
			Reads `item`'s channel progress: a number advances its cleanliness from where this channel started; none
			means no channel tracks it now, so the next one starts from here.
		]=]
		update = function(_self, item)
			if item:GetAttribute(CargoConstants.CLEAN_ATTRIBUTE) == nil then
				return
			end
			local progress = item:GetAttribute(InteractionConstants.CHANNEL_PROGRESS_ATTRIBUTE)
			if type(progress) ~= "number" then
				starts[item] = nil
				return
			end
			local start = starts[item]
			if start == nil then
				start = cleanOf(item)
				starts[item] = start
			end
			setClean(item, CargoAppraisalFormulas.cleanAt(start, progress))
		end,

		--[=[
			The item's cleaning channel completed: it is spotless.
		]=]
		finish = function(_self, item)
			if item:GetAttribute(CargoConstants.CLEAN_ATTRIBUTE) == nil then
				return
			end
			starts[item] = nil
			setClean(item, 1)
		end,

		--[=[
			A Load landed: every valuable in it that nobody appraised is appraised at the truck, stamped to the banker.
		]=]
		banked = function(_self, deposit, banker)
			for _, item in deposit.items do
				local appraisal = item.appraisal
				if appraisal ~= nil and not appraisal.appraised then
					stamp(banker, CargoFeedbackUtils.appraisalText(item.kind, appraisal.variant, item.value, true))
				end
			end
		end,

		--[=[
			Registers the grime channels (never on a held item) and follows every cleanable item's progress. Returns
			the stopper.
		]=]
		start = function(self)
			if not registered then
				registered = true
				for _, kind in VacuumConstants.GRIME_KINDS do
					InteractionServiceServer:channel(kind, {
						canChannel = function(player, target)
							return target:GetAttribute(CarryConstants.CARRIED_BY_ATTRIBUTE) == nil
								and target:HasTag(VacuumConstants.GRIME_TAG)
								and VacuumServiceServer:canVacuum(player, target)
						end,
						onComplete = function(_players, target)
							if target.Parent ~= nil then
								self:finish(target)
							end
						end,
					})
				end
			end
			return Observers.observeTag(VacuumConstants.GRIME_TAG, function(item: Instance)
				local changed = item:GetAttributeChangedSignal(InteractionConstants.CHANNEL_PROGRESS_ATTRIBUTE)
					:Connect(function()
						self:update(item)
					end)
				return function()
					changed:Disconnect()
					starts[item] = nil
				end
			end)
		end,
	}
	return system
end

return CargoGrimeSystem
