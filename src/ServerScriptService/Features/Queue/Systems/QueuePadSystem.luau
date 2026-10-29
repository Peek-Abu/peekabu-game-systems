--!strict
--[=[
	QueuePadSystem: the pads in the world. Every BasePart tagged QueuePad has its attributes read once when
	tagged (QueueCapacity, QueueCountdown, QueueDestination, QueueHold; set them first) and is sampled every tick: a
	living player whose HumanoidRootPart is over the pad is aboard (QueuePadRules.isAboard), unless the game's board
	filter refuses them (`setBoardFilter`); `refused` fires for each refused player once per visit to the pad. Membership,
	countdowns and Depart now are the specced QueuePadTracker; this module turns Instances into its ids,
	hands a due pad's party to `onDue` and publishes the pads as the `queue` world entry (at most once per
	frame, and never after `stop`). A misconfigured pad is warned about and ignored.

	Depart now locks the pad and hands its party to `onDue` in the same call, with no yield in between: a
	later sample admitting a newcomer would otherwise reset the countdown and cancel the Depart.

	Spec-exempt shell (CollectionService via Observers, characters, Players).

	@class QueuePadSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Observers = require(ReplicatedStorage.Packages.Observers)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local QueueConstants = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueConstants)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local QueuePadRules = require(ServerScriptService.Features.Queue.Rules.QueuePadRules)
local QueuePadTracker = require(ServerScriptService.Features.Queue.State.QueuePadTracker)
local StateSyncWorldStore = require(ServerScriptService.Features.StateSync.State.StateSyncWorldStore)

export type OnDue = (pad: BasePart, config: QueueTypes.PadConfig, party: { Player }) -> ()

export type QueuePadSystem = {
	refused: SignalTyped.Signal<BasePart, Player>,
	start: (self: QueuePadSystem) -> (),
	stop: (self: QueuePadSystem) -> (),
	step: (self: QueuePadSystem, now: number) -> (),
	departNow: (self: QueuePadSystem, player: Player, now: number) -> boolean,
	-- `hold`: the party that left (a local move); they board no pad until they step off this one.
	unlock: (self: QueuePadSystem, pad: BasePart, hold: { Player }?) -> (),
	forget: (self: QueuePadSystem, player: Player) -> (),
	padOf: (self: QueuePadSystem, player: Player) -> BasePart?,
	firstMisroute: (self: QueuePadSystem, pad: BasePart) -> boolean,
	count: (self: QueuePadSystem) -> number,
	setBoardFilter: (self: QueuePadSystem, filter: QueueTypes.BoardFilter?) -> (),
	padIdOf: (self: QueuePadSystem, pad: BasePart) -> string?,
	membersOf: (self: QueuePadSystem, pad: BasePart) -> { Player },
	seatsOf: (self: QueuePadSystem, pad: BasePart) -> number?,
	endsAtOf: (self: QueuePadSystem, pad: BasePart) -> number?,
	setSeats: (self: QueuePadSystem, pad: BasePart, seats: number) -> boolean,
	startCountdown: (self: QueuePadSystem, pad: BasePart, now: number, seconds: number) -> boolean,
	cancelCountdown: (self: QueuePadSystem, pad: BasePart) -> boolean,
}

local log = Logger.new("QueuePadSystem")

-- Root positions of every living character, by UserId.
local function rootPositions(): { [number]: Vector3 }
	local positions: { [number]: Vector3 } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character ~= nil then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local root = character:FindFirstChild("HumanoidRootPart")
			if humanoid ~= nil and humanoid.Health > 0 and root ~= nil and root:IsA("BasePart") then
				positions[player.UserId] = root.Position
			end
		end
	end
	return positions
end

local function playersOf(userIds: { number }): { Player }
	local list: { Player } = {}
	for _, userId in userIds do
		local player = Players:GetPlayerByUserId(userId)
		if player ~= nil then
			table.insert(list, player)
		end
	end
	return list
end

local QueuePadSystem = {}

function QueuePadSystem.new(onDue: OnDue): QueuePadSystem
	local tracker = QueuePadTracker.new()
	local refusedSignal: SignalTyped.Signal<BasePart, Player> = SignalTyped.new()
	local boardFilter: QueueTypes.BoardFilter? = nil
	-- Per pad: the players refused at the last sample, so `refused` fires once per visit.
	local refusedBefore: { [string]: { [number]: boolean } } = {}
	local padById: { [string]: BasePart } = {}
	local idByPad: { [BasePart]: string } = {}
	local misrouted: { [BasePart]: boolean } = {}
	local order: { string } = {}
	local nextId = 0
	local stopObserving: (() -> ())? = nil
	local running = false
	local publishScheduled = false

	-- Republishes the pads, at most once per frame. A publish queued before `stop` does nothing.
	local function publish()
		if publishScheduled then
			return
		end
		publishScheduled = true
		task.defer(function()
			publishScheduled = false
			if running then
				StateSyncWorldStore.set(QueueConstants.WORLD_ENTRY, tracker:snapshot())
			end
		end)
	end

	-- Locks every due pad and hands its frozen party to `onDue`. Whether any pad departed.
	local function departDue(now: number): boolean
		local departed = false
		for _, padId in tracker:due(now) do
			local pad: BasePart? = padById[padId]
			local config = tracker:config(padId)
			local party = playersOf(tracker:lock(padId))
			departed = true
			if pad ~= nil and config ~= nil then
				onDue(pad, config, party)
			end
		end
		return departed
	end

	-- Starts tracking one tagged instance; returns its cleanup.
	local function observe(instance: Instance): (() -> ())?
		if not instance:IsA("BasePart") then
			log:warn(`{instance:GetFullName()} is tagged {QueueConstants.TAG} but is not a BasePart`)
			return nil
		end
		local pad: BasePart = instance
		local config, reason = QueuePadRules.config(
			pad:GetAttribute(QueueConstants.CAPACITY_ATTRIBUTE),
			pad:GetAttribute(QueueConstants.COUNTDOWN_ATTRIBUTE),
			pad:GetAttribute(QueueConstants.DESTINATION_ATTRIBUTE),
			pad:GetAttribute(QueueConstants.HOLD_ATTRIBUTE)
		)
		if config == nil then
			log:warn(`{pad:GetFullName()} is not a usable queue pad: {reason or "?"}`)
			return nil
		end
		nextId += 1
		local padId = `pad{nextId}`
		tracker:add(padId, config)
		padById[padId] = pad
		idByPad[pad] = padId
		table.insert(order, padId)
		publish()
		return function()
			tracker:remove(padId)
			refusedBefore[padId] = nil
			padById[padId] = nil
			idByPad[pad] = nil
			misrouted[pad] = nil
			local index = table.find(order, padId)
			if index ~= nil then
				table.remove(order, index)
			end
			publish()
		end
	end

	-- The players aboard `pad` its board filter refuses (an erroring filter refuses nobody); `refused` fires for
	-- each one not refused at the last sample.
	local function refusedOn(pad: BasePart, padId: string, aboard: { number }): { [number]: boolean }?
		local filter = boardFilter
		if filter == nil then
			refusedBefore[padId] = nil
			return nil
		end
		local members = playersOf(tracker:members(padId))
		local refused: { [number]: boolean } = {}
		local before = refusedBefore[padId] or {}
		for _, userId in aboard do
			local player = Players:GetPlayerByUserId(userId)
			if player ~= nil then
				local ok, allowed = pcall(filter, pad, player, members)
				if not ok then
					log:error(`board filter errored: {tostring(allowed)}`)
				elseif allowed ~= true then
					refused[userId] = true
					if not before[userId] then
						refusedSignal:Fire(pad, player)
					end
				end
			end
		end
		refusedBefore[padId] = refused
		return refused
	end

	local system: QueuePadSystem
	system = {
		refused = refusedSignal,

		start = function(_self)
			running = true
			stopObserving = Observers.observeTag(QueueConstants.TAG, observe)
			publish()
		end,

		stop = function(_self)
			running = false
			local stopFn = stopObserving
			if stopFn ~= nil then
				stopFn()
				stopObserving = nil
			end
			StateSyncWorldStore.clear(QueueConstants.WORLD_ENTRY)
		end,

		-- One sample: who stands on each pad (by UserId, so seats are deterministic when more arrive than
		-- fit), then every pad whose countdown ended departs.
		step = function(_self, now)
			local positions = rootPositions()
			local changed = false
			for _, padId in order do
				local pad: BasePart? = padById[padId]
				if pad ~= nil then
					local aboard: { number } = {}
					for userId, position in positions do
						if QueuePadRules.isAboard(pad.CFrame, pad.Size, position, QueueConstants.ABOARD_HEIGHT) then
							table.insert(aboard, userId)
						end
					end
					table.sort(aboard)
					local refused = refusedOn(pad, padId, aboard)
					if tracker:sync(padId, aboard, now, refused) then
						changed = true
					end
				end
			end
			if departDue(now) then
				changed = true
			end
			if changed then
				publish()
			end
		end,

		-- Depart now: the pad becomes due, is locked and its party handed to `onDue`, all in this call.
		departNow = function(_self, player, now)
			if tracker:departNow(player.UserId, now) == nil then
				return false
			end
			departDue(now)
			publish()
			return true
		end,

		unlock = function(_self, pad, hold)
			local padId = idByPad[pad]
			if padId ~= nil then
				local ids: { number } = {}
				if hold ~= nil then
					for _, player in hold do
						table.insert(ids, player.UserId)
					end
				end
				tracker:unlock(padId, ids)
				publish()
			end
		end,

		forget = function(_self, player)
			if tracker:forget(player.UserId) then
				publish()
			end
		end,

		padOf = function(_self, player)
			local padId = tracker:padOf(player.UserId)
			return if padId ~= nil then padById[padId] else nil
		end,

		-- True the first time this pad's party could not be routed (a misconfigured destination), so the
		-- caller warns and toasts once per pad instead of on every countdown.
		firstMisroute = function(_self, pad)
			if misrouted[pad] then
				return false
			end
			misrouted[pad] = true
			return true
		end,

		count = function(_self)
			return #order
		end,

		setBoardFilter = function(_self, filter)
			boardFilter = filter
		end,

		padIdOf = function(_self, pad)
			return idByPad[pad]
		end,

		membersOf = function(_self, pad)
			local padId = idByPad[pad]
			return if padId ~= nil then playersOf(tracker:members(padId)) else {}
		end,

		seatsOf = function(_self, pad)
			local padId = idByPad[pad]
			return if padId ~= nil then tracker:seats(padId) else nil
		end,

		endsAtOf = function(_self, pad)
			local padId = idByPad[pad]
			return if padId ~= nil then tracker:endsAt(padId) else nil
		end,

		setSeats = function(_self, pad, seats)
			local padId = idByPad[pad]
			if padId == nil or not tracker:setSeats(padId, seats) then
				return false
			end
			publish()
			return true
		end,

		startCountdown = function(_self, pad, now, seconds)
			local padId = idByPad[pad]
			if padId == nil or not tracker:startCountdown(padId, now, seconds) then
				return false
			end
			-- A zero-second countdown is due now: it departs in this call, like Depart now.
			departDue(now)
			publish()
			return true
		end,

		cancelCountdown = function(_self, pad)
			local padId = idByPad[pad]
			if padId == nil or not tracker:cancelCountdown(padId) then
				return false
			end
			publish()
			return true
		end,
	}
	return system
end

return QueuePadSystem
