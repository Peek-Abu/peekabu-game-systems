--!strict
--[=[
	QueueTeleportSystem: sends players to another place and sees each teleport through. A departure that
	reserves reserves ONE server (ReserveServer) and keeps its access code, so every retry, including a
	retry for only the players a partial failure hit, lands in that same server. A failure (ReserveServer or
	TeleportAsync erroring, TeleportInitFailed, or a player still here TELEPORT_WATCHDOG seconds after the
	attempt) is retried on QueueTeleportRules' schedule; after the last retry the player is given up on.
	`onFinished` runs once per departure with the players given up on (empty when everyone left). A request
	whose players are all already in flight with an earlier departure starts nothing: `send` returns false
	and `onFinished` never runs.

	ReserveServer and TeleportAsync error in Studio; that is why QueueServiceServer routes Studio as a local
	move. Spec-exempt shell (TeleportService, Players); the bookkeeping is the specced QueueDepartureTracker
	and the schedule the specced QueueTeleportRules.

	@class QueueTeleportSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local QueueConstants = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueConstants)
local QueueDepartureTracker = require(ServerScriptService.Features.Queue.State.QueueDepartureTracker)
local QueueTeleportRules = require(ServerScriptService.Features.Queue.Rules.QueueTeleportRules)

export type OnFinished = (gaveUp: { Player }, reason: string?) -> ()

export type Request = {
	players: { Player },
	placeId: number,
	-- Reserve a fresh server (a party going out), or join any public server (a trip home, a redirect).
	reserve: boolean,
	-- JSON teleport data, or nil for none.
	data: string?,
	onFinished: OnFinished,
}

export type QueueTeleportSystem = {
	send: (self: QueueTeleportSystem, request: Request) -> boolean,
	initFailed: (self: QueueTeleportSystem, player: Player, reason: string) -> (),
	left: (self: QueueTeleportSystem, player: Player) -> (),
	step: (self: QueueTeleportSystem, now: number) -> (),
	inFlight: (self: QueueTeleportSystem) -> number,
}

type Record = {
	request: Request,
	accessCode: string?,
	players: { [number]: Player },
}

local log = Logger.new("QueueTeleportSystem")

local QueueTeleportSystem = {}

function QueueTeleportSystem.new(): QueueTeleportSystem
	local tracker = QueueDepartureTracker.new()
	local records: { [number]: Record } = {}

	-- Reports a departure once nobody in it is outstanding.
	local function settle(id: number)
		local record = records[id]
		if record == nil then
			return
		end
		local outcome = tracker:finished(id)
		if outcome == nil then
			return
		end
		records[id] = nil
		local gaveUp: { Player } = {}
		for _, userId in outcome.gaveUp do
			local player: Player? = record.players[userId]
			if player ~= nil and player.Parent == Players then
				table.insert(gaveUp, player)
			end
		end
		local ok, err = pcall(function()
			record.request.onFinished(gaveUp, outcome.reason)
		end)
		if not ok then
			log:error(`onFinished failed: {tostring(err)}`)
		end
	end

	local attempt: (id: number, players: { Player }) -> ()

	-- Counts a failure for each player; retries them on the schedule or gives up on them.
	local function fail(id: number, players: { Player }, reason: string)
		local retry: { [number]: { Player } } = {}
		for _, player in players do
			local failures = tracker:fail(player.UserId)
			if failures ~= nil then
				local delay = QueueTeleportRules.retryDelay(failures)
				if delay == nil then
					log:warn(`giving up teleporting {player.Name}: {reason}`)
					tracker:giveUp(player.UserId, reason)
				else
					local group = retry[delay] or {}
					table.insert(group, player)
					retry[delay] = group
				end
			end
		end
		for delay, group in retry do
			log:info(`retrying {#group} player(s) in {delay}s: {reason}`)
			task.delay(delay, attempt, id, group)
		end
		settle(id)
	end

	attempt = function(id, players)
		local record = records[id]
		if record == nil then
			return
		end
		local present: { Player } = {}
		local now = os.clock()
		for _, player in players do
			if player.Parent == Players and tracker:departureOf(player.UserId) == id then
				table.insert(present, player)
				tracker:attempt(player.UserId, now)
			end
		end
		if #present == 0 then
			settle(id)
			return
		end
		local request = record.request
		if request.reserve and record.accessCode == nil then
			local ok, result = pcall(function(): string
				local code = TeleportService:ReserveServer(request.placeId)
				return code
			end)
			if not ok then
				fail(id, present, `ReserveServer failed: {tostring(result)}`)
				return
			end
			record.accessCode = result
		end
		local options = Instance.new("TeleportOptions")
		local code = record.accessCode
		if code ~= nil then
			options.ReservedServerAccessCode = code
		end
		local data = request.data
		if data ~= nil then
			options:SetTeleportData(data)
		end
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(request.placeId, present, options)
		end)
		if not ok then
			fail(id, present, `TeleportAsync failed: {tostring(err)}`)
		end
	end

	local system: QueueTeleportSystem
	system = {
		send = function(_self, request)
			local ids: { number } = {}
			local byId: { [number]: Player } = {}
			for _, player in request.players do
				table.insert(ids, player.UserId)
				byId[player.UserId] = player
			end
			local id = tracker:begin(ids)
			if id == nil then
				return false
			end
			records[id] = { request = request, accessCode = nil, players = byId }
			task.spawn(attempt, id, request.players)
			return true
		end,

		-- TeleportInitFailed, or the watchdog: the player's attempt failed.
		initFailed = function(_self, player, reason)
			local id = tracker:departureOf(player.UserId)
			if id ~= nil then
				fail(id, { player }, reason)
			end
		end,

		-- The player left the server (teleported, or quit): no longer outstanding.
		left = function(_self, player)
			local id = tracker:arrive(player.UserId)
			if id ~= nil then
				settle(id)
			end
		end,

		step = function(self, now)
			for _, userId in tracker:stale(now, QueueConstants.TELEPORT_WATCHDOG) do
				local player = Players:GetPlayerByUserId(userId)
				if player ~= nil then
					self:initFailed(player, "teleport timed out")
				end
			end
		end,

		inFlight = function(_self)
			local count = 0
			for _ in records do
				count += 1
			end
			return count
		end,
	}
	return system
end

return QueueTeleportSystem
