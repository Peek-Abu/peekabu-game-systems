--!strict
--[=[
	CargoGrimeSystem: cleaning grimy valuables (docs/superpowers/specs/2026-10-15-cleanup-crew-loot-loop-design.md §3.2-3.3).
	A valuable that is not spotless carries its size's grime channel (VacuumConstants.GRIME_KINDS, registered here at
	load; GRIME_SECONDS for one player, rates add up). Holding the vacuum on it is that channel: allowed when Vacuum
	says this player may vacuum this target (equipped, empty hands, the wand on it) and nobody carries the item. The
	server mirrors the channel's ChannelProgress into the item's cleanliness: a channel cleans the grime that was left
	when it started (CargoAppraisalFormulas.cleanAt), so when the channel forgets the item the next one starts from the
	cleanliness reached. Each change goes through the spawner's `setClean` (value, tag, appraisal, and no vacuum target
	once spotless); the channel's completion makes it spotless (`finish`). Every step that raised its cleanliness
	reports the Gloom it removed (`cleaned`, CargoAppraisalFormulas.gloomRemoved: the item's size Gloom in step with its
	cleanliness, docs/superpowers/specs/2026-10-16-cleanup-crew-gloom-gleam-economy-design.md §3.2), which the shift
	credits to the contract live. A sealed item is never cleaned again, so what was left on it is never removed.

	The first appraisal of an item is told (a small sticky slip, Shift's slip toast style) to every crew member within
	APPRAISAL_TELL_DISTANCE, with the `cargoAppraise` sound at the item (`cargoJackpot` for a jackpot); a valuable banked
	unappraised is told to its banker (`banked`: the truck reveals it, as grimy as it is).

	"Clean it where you find it": the first pick-up of a valuable that is not spotless locks its grime (`pickedUp`, the
	spawner's `seal`): it keeps its cleanliness and value, nobody can clean it again, and the truck appraises it as it
	is. The first lock of a shift tells its carrier why (`lockHint`, a small sticky note); `reset` forgets who was told.

	`start` registers the channels and observes every item tagged VacuumConstants.GRIME_TAG; `update`, `finish`,
	`banked`, `pickedUp` and `reset` are the specced core.

	@class CargoGrimeSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Observers = require(ReplicatedStorage.Packages.Observers)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)
local CargoAppraisalFormulas = require(ReplicatedStorage.Shared.Features.Cargo.Utils.CargoAppraisalFormulas)
local CargoRegistry = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
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
	-- Tells a carrier their first grime lock of the shift (default: the sticky-note toast).
	lockHint: ((player: Player) -> ())?,
	-- The Gloom one cleaning step removed from `item` (more than zero); the shift credits it to the contract.
	cleaned: ((item: Instance, gloom: number) -> ())?,
}

export type CargoGrimeSystem = {
	update: (self: CargoGrimeSystem, item: Instance) -> (),
	finish: (self: CargoGrimeSystem, item: Instance) -> (),
	banked: (self: CargoGrimeSystem, deposit: CargoTypes.Deposit, banker: Player) -> (),
	pickedUp: (self: CargoGrimeSystem, item: Instance, player: Player) -> (),
	reset: (self: CargoGrimeSystem) -> (),
	start: (self: CargoGrimeSystem) -> () -> (),
}

local function cleanOf(item: Instance): number
	local clean = item:GetAttribute(CargoConstants.CLEAN_ATTRIBUTE)
	return if type(clean) == "number" then clean else 0
end

-- An appraisal's small slip (a jackpot slip for a jackpot), off-centre and brief: never the big shift stamp.
local function slip(player: Player, text: string, variant: string?)
	ToastServiceServer:send(player, {
		text = text,
		style = CargoFeedbackUtils.appraisalStyle(variant),
		duration = CargoConstants.APPRAISAL_TOAST_SECONDS,
	})
end

-- The default lock hint: a small sticky note, never the big stamp.
local function lockNote(player: Player)
	ToastServiceServer:send(player, {
		text = CargoConstants.GRIME_LOCK_HINT,
		style = CargoConstants.GRIME_LOCK_TOAST_STYLE,
		duration = CargoConstants.GRIME_LOCK_TOAST_SECONDS,
	})
end

local CargoGrimeSystem = {}

function CargoGrimeSystem.new(deps: Deps): CargoGrimeSystem
	-- The cleanliness each running channel started from; absent while no channel tracks the item.
	local starts: { [Instance]: number } = {}
	setmetatable(starts, { __mode = "k" })
	local registered = false
	-- UserIds told about the grime lock this shift.
	local told: { [number]: boolean } = {}
	local lockHint: (player: Player) -> () = deps.lockHint or lockNote

	-- Just appraised by cleaning: the sound at the item and the slip to the crew near it.
	local function announce(item: Instance)
		local entry = CargoFeedbackUtils.entryOf(item)
		if entry == nil or not item:IsA("BasePart") then
			return
		end
		local appraisal = entry.appraisal
		local variant = if appraisal ~= nil then appraisal.variant else nil
		local text = CargoFeedbackUtils.appraisalText(entry.kind, variant, entry.value, false, entry.overtime)
		-- A jackpot's own sound starts with the appraisal's, then pays off (round-3 pick A).
		deps.sound(item.Position, if variant ~= nil then "cargoJackpot" else "cargoAppraise")
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
			if
				root ~= nil
				and root:IsA("BasePart")
				and (root.Position - item.Position).Magnitude <= CargoConstants.APPRAISAL_TELL_DISTANCE
			then
				slip(player, text, variant)
			end
		end
	end

	local function setClean(item: Instance, clean: number)
		local before = cleanOf(item)
		local appraisedNow = deps.spawner:setClean(item, clean, deps.now())
		local kind = item:GetAttribute(CarryConstants.KIND_ATTRIBUTE)
		local def = if type(kind) == "string" then CargoRegistry.get(kind) else nil
		local gloom = if def ~= nil then CargoAppraisalFormulas.gloomRemoved(def, before, cleanOf(item)) else 0
		local cleaned = deps.cleaned
		if gloom > 0 and cleaned ~= nil then
			cleaned(item, gloom)
		end
		if appraisedNow then
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
			A Load landed: every valuable in it that nobody appraised is appraised at the truck, a slip to the banker.
		]=]
		banked = function(_self, deposit, banker)
			for _, item in deposit.items do
				local appraisal = item.appraisal
				if appraisal ~= nil and not appraisal.appraised then
					slip(
						banker,
						CargoFeedbackUtils.appraisalText(item.kind, appraisal.variant, item.value, true, item.overtime),
						appraisal.variant
					)
				end
			end
		end,

		--[=[
			`player` picked `item` up: a valuable that is not spotless is sealed as it is; their first lock this shift
			tells them why.
		]=]
		pickedUp = function(_self, item, player)
			starts[item] = nil
			if deps.spawner:seal(item) and not told[player.UserId] then
				told[player.UserId] = true
				lockHint(player)
			end
		end,

		--[=[
			A new shift: everyone is told again.
		]=]
		reset = function(_self)
			table.clear(told)
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
