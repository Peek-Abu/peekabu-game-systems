--!strict
--[=[
	QueueServiceServer: parties that travel together between the places of one experience (plan:
	docs/superpowers/plans/2026-10-10-queue-base.md).

	- Pads: a BasePart tagged `QueuePad` (attributes QueueCapacity, QueueCountdown, QueueDestination) holds
	  a party. Standing on it joins, leaving leaves; with anyone aboard a countdown runs (reset on each
	  join) and anyone aboard can Depart now (`departNow`, or the client's button). Published to every
	  client as the `queue` world entry.
	- Roles: a game registers its place-role table in QueueRegistry ("lobby", "match", any strings). In
	  Studio or on an unknown PlaceId every role runs in this one server ("local" mode) and a teleport
	  becomes a move to the role's arrival point (`setArrivalPoint`), so the loop plays through rojo serve.
	  With no arrival point for the role (its world is not built here) the party stays on its pad.
	- Departing (live): a fresh reserved server, the party teleported with a ticket (expected user ids and
	  the game's payload from `setDepartData`), retried on failure (3 retries, backing off); after the last
	  the party is back on its pad with a toast and `departFailed` fires. A destination that cannot be
	  reached at all (unregistered role, no arrival point) fails the same way, warned and toasted once per
	  pad.
	- Arriving (a reserved server): waits up to ARRIVAL_TIMEOUT for the expected party, then fires
	  `arrived(party, payload)` with whoever came. Strangers become crew while there is room, else they are
	  sent to the home role (`configure({ homeRole })`, default: where the party came from). A local move
	  fires `arrived` the same way.
	- Returning: `returnParty(players, role, payload)` sends players to any public server of that role;
	  `returned(player, payload)` fires where they land (live or local), and `returnPayloadOf` keeps the
	  payload for a game that reads it later (a result summary).

	The last player leaving a reserved server needs no code: Roblox shuts an empty server down.

	Spec-exempt shell (TeleportService, Players, HttpService, signals), like its QueuePadSystem,
	QueueTeleportSystem, QueueArrivalSystem and QueueLandingSystem; the decisions are the specced
	QueuePadRules, QueuePlaceRules, QueueTeleportRules, QueuePadTracker, QueueDepartureTracker and
	QueueArrivalTracker.

	@class QueueServiceServer
]=]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")

local QueueShared = ReplicatedStorage.Shared.Features.Queue
local QueueServer = ServerScriptService.Features.Queue
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local WorldTypes = require(ReplicatedStorage.Shared.Data.WorldTypes)
local QueueConstants = require(QueueShared.Data.QueueConstants)
local QueueEvents = require(QueueShared.Net.QueueEvents)
local QueueTypes = require(QueueShared.Data.QueueTypes)
local QueueRegistry = require(QueueServer.Data.QueueRegistry)
local QueuePlaceRules = require(QueueServer.Rules.QueuePlaceRules)
local QueueTeleportRules = require(QueueServer.Rules.QueueTeleportRules)
local QueueArrivalSystem = require(QueueServer.Systems.QueueArrivalSystem)
local QueueLandingSystem = require(QueueServer.Systems.QueueLandingSystem)
local QueuePadSystem = require(QueueServer.Systems.QueuePadSystem)
local QueueTeleportSystem = require(QueueServer.Systems.QueueTeleportSystem)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)

type QueuePayload = QueueTypes.QueuePayload
type QueueTicket = QueueTypes.QueueTicket

local log = Logger.new("QueueServiceServer")

local arrived: SignalTyped.Signal<{ Player }, QueuePayload> = SignalTyped.new()
local joinedLate: SignalTyped.Signal<Player> = SignalTyped.new()
local returned: SignalTyped.Signal<Player, QueuePayload> = SignalTyped.new()
local departing: SignalTyped.Signal<BasePart, { Player }> = SignalTyped.new()
local departFailed: SignalTyped.Signal<BasePart, { Player }, string> = SignalTyped.new()

local config: QueueTypes.QueueConfig = { homeRole = nil, forceLive = false }
local departData: QueueTypes.DepartDataResolver? = nil
local counters = { departures = 0, localMoves = 0, failures = 0, arrivals = 0, redirects = 0, returns = 0 }
local connections: { RBXScriptConnection } = {}
local stoppers: { () -> () } = {}
local arrivalsActive = false
local accumulated = 0

local landing = QueueLandingSystem.new(function(player, payload)
	counters.returns += 1
	returned:Fire(player, payload)
end)

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function currentMode(): QueueTypes.Mode
	return QueuePlaceRules.mode(game.PlaceId, RunService:IsStudio(), config.forceLive, QueueRegistry.roles())
end

local function currentRole(): string?
	return QueuePlaceRules.roleOf(game.PlaceId, QueueRegistry.roles())
end

local function idsOf(players: { Player }): { number }
	local ids: { number } = {}
	for _, player in players do
		table.insert(ids, player.UserId)
	end
	return ids
end

local function toast(players: { Player }, text: string)
	for _, player in players do
		ToastServiceServer:send(player, { text = text })
	end
end

-- A local move (Studio, an unknown place or a placeholder role): whether the players reached the role.
local function moveLocally(players: { Player }, role: string): boolean
	counters.localMoves += 1
	return landing:move(players, role)
end

local function payloadFor(pad: BasePart, party: { Player }): QueuePayload
	local resolver = departData
	if resolver == nil then
		return {}
	end
	local ok, result = pcall(resolver, pad, party)
	if not ok then
		log:error(`depart data errored: {tostring(result)}`)
		return {}
	end
	local clean, reason = QueueTeleportRules.payload(result)
	if clean == nil then
		log:error(`depart data refused: {reason or "?"}`)
		return {}
	end
	return clean
end

local teleports = QueueTeleportSystem.new()
-- Assigned below, once `depart` (which unlocks pads) exists.
local pads: QueuePadSystem.QueuePadSystem

-- The party is back on its pad. `quiet` skips the warning and toast (a misroute already reported once).
local function failDeparture(pad: BasePart, party: { Player }, reason: string, quiet: boolean?)
	counters.failures += 1
	if not quiet then
		log:warn(`departure from {pad:GetFullName()} failed: {reason}`)
		toast(party, QueueConstants.DEPART_FAILED_TEXT)
	end
	pads:unlock(pad)
	departFailed:Fire(pad, party, reason)
end

local function sendParty(
	pad: BasePart,
	padConfig: QueueTypes.PadConfig,
	party: { Player },
	payload: QueuePayload,
	placeId: number
)
	local ticket: QueueTicket = {
		kind = "depart",
		from = currentRole(),
		role = padConfig.destination,
		party = idsOf(party),
		capacity = padConfig.capacity,
		payload = payload,
	}
	local sent = teleports:send({
		players = party,
		placeId = placeId,
		reserve = true,
		data = HttpService:JSONEncode(QueueTeleportRules.encode(ticket)),
		onFinished = function(gaveUp, reason)
			pads:unlock(pad)
			if #gaveUp > 0 then
				failDeparture(pad, gaveUp, reason or "teleport failed")
			end
		end,
	})
	if not sent then
		pads:unlock(pad) -- everyone aboard is already travelling with an earlier departure
	end
end

-- A pad's countdown ended (or someone pressed Depart now): its frozen party leaves.
local function depart(pad: BasePart, padConfig: QueueTypes.PadConfig, party: { Player })
	if #party == 0 then
		pads:unlock(pad)
		return
	end
	counters.departures += 1
	departing:Fire(pad, party)
	local payload = payloadFor(pad, party)
	local destination = padConfig.destination
	local route, reason = QueuePlaceRules.route(currentMode(), destination, QueueRegistry.roles())
	if route ~= nil and route.kind == "teleport" then
		sendParty(pad, padConfig, party, payload, route.placeId)
	elseif route == nil or not moveLocally(party, destination) then
		-- Misconfigured (unregistered role, or no arrival point here): the party stays on its pad.
		failDeparture(pad, party, reason or `no arrival point for "{destination}"`, not pads:firstMisroute(pad))
	else
		pads:unlock(pad)
		task.defer(function()
			counters.arrivals += 1
			arrived:Fire(party, payload)
		end)
	end
end

pads = QueuePadSystem.new(depart)

-- The Queue ticket in a player's join data, or nil (none, not ours, or forged).
local function ticketOf(player: Player): QueueTicket?
	local raw = player:GetJoinData().TeleportData
	if type(raw) ~= "string" then
		return nil
	end
	local ok, parsed = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok then
		return nil
	end
	-- JSONDecode is typed `any`; QueueTeleportRules.decode checks every field, so it is the trust boundary.
	local value: WorldTypes.WorldValue? = parsed
	return QueueTeleportRules.decode(value)
end

local function noteReturn(player: Player)
	local ticket = ticketOf(player)
	if ticket ~= nil and ticket.kind == "return" then
		landing:landHome(player, ticket.payload)
	end
end

-- A stranger in a full arrival server: off to a public server of the home role, kicked if there is none.
local function redirect(player: Player, ticket: QueueTicket?)
	counters.redirects += 1
	local home = config.homeRole or (if ticket ~= nil then ticket.from else nil)
	local route = if home ~= nil then QueuePlaceRules.route("live", home, QueueRegistry.roles()) else nil
	if route ~= nil and route.kind == "teleport" then
		teleports:send({
			players = { player },
			placeId = route.placeId,
			reserve = false,
			data = nil,
			onFinished = function(gaveUp)
				for _, stuck in gaveUp do
					stuck:Kick(QueueConstants.REDIRECT_KICK_TEXT)
				end
			end,
		})
		return
	end
	log:warn(`no home role to send {player.Name} to; removing them from the full server`)
	player:Kick(QueueConstants.REDIRECT_KICK_TEXT)
end

local arrivals = QueueArrivalSystem.new({
	ticketOf = ticketOf,
	onArrived = function(crew, ticket)
		counters.arrivals += 1
		arrived:Fire(crew, if ticket ~= nil then ticket.payload else {})
	end,
	onLate = function(player)
		joinedLate:Fire(player)
	end,
	onRedirect = redirect,
})

local onDepart = RequestHandler.wrap({
	name = "QueueDepart",
	rateLimit = { maxRequests = 5, windowSeconds = 5 },
	handler = function(_data: unknown, player: Player)
		pads:departNow(player, serverNow())
	end,
})

local function tick()
	pads:step(serverNow())
	teleports:step(os.clock())
	if arrivalsActive then
		arrivals:step(os.clock())
	end
	landing:step()
end

export type QueueServiceServer = {
	dependencies: { string },
	arrived: SignalTyped.Signal<{ Player }, QueuePayload>,
	joinedLate: SignalTyped.Signal<Player>,
	returned: SignalTyped.Signal<Player, QueuePayload>,
	departing: SignalTyped.Signal<BasePart, { Player }>,
	departFailed: SignalTyped.Signal<BasePart, { Player }, string>,

	start: (self: QueueServiceServer) -> (),
	stop: (self: QueueServiceServer) -> (),
	getState: (self: QueueServiceServer) -> { [string]: any },

	configure: (self: QueueServiceServer, update: QueueTypes.QueueConfigUpdate) -> (),
	setDepartData: (self: QueueServiceServer, resolver: QueueTypes.DepartDataResolver?) -> (),
	setArrivalPoint: (self: QueueServiceServer, role: string, resolver: QueueTypes.ArrivalPoint?) -> (),
	departNow: (self: QueueServiceServer, player: Player) -> boolean,
	padOf: (self: QueueServiceServer, player: Player) -> BasePart?,
	returnParty: (self: QueueServiceServer, players: { Player }, role: string, payload: QueuePayload?) -> boolean,
	returnPayloadOf: (self: QueueServiceServer, player: Player) -> QueuePayload?,
	mode: (self: QueueServiceServer) -> QueueTypes.Mode,
	role: (self: QueueServiceServer) -> string?,
	runsRole: (self: QueueServiceServer, role: string) -> boolean,
}

local QueueServiceServer: QueueServiceServer = {
	dependencies = { "StateSyncServiceServer", "ToastServiceServer" },
	arrived = arrived,
	joinedLate = joinedLate,
	returned = returned,
	departing = departing,
	departFailed = departFailed,

	--[=[
		Starts the pads, the arrival side on a reserved server (or return handling on a public live
		server), the Depart-now packet and the tick.
	]=]
	start = function(_self)
		local mode = currentMode()
		local reserved = QueuePlaceRules.isReservedServer(game.PrivateServerId, game.PrivateServerOwnerId)
		pads:start()
		if mode == "live" and reserved then
			arrivalsActive = true
			arrivals:start()
		elseif mode == "live" then
			for _, player in Players:GetPlayers() do
				noteReturn(player)
			end
			table.insert(connections, Players.PlayerAdded:Connect(noteReturn))
		end
		table.insert(
			connections,
			Players.PlayerRemoving:Connect(function(player)
				teleports:left(player)
				pads:forget(player)
				landing:forget(player)
			end)
		)
		table.insert(
			connections,
			TeleportService.TeleportInitFailed:Connect(function(player, result, message)
				teleports:initFailed(player, `{result.Name}: {message}`)
			end)
		)
		table.insert(
			stoppers,
			QueueEvents.packets.Depart.listen(function(data: boolean, player: Player?)
				if player then
					onDepart(data, player)
				end
			end)
		)
		table.insert(
			connections,
			RunService.Heartbeat:Connect(function(deltaTime)
				accumulated += deltaTime
				if accumulated >= QueueConstants.TICK_INTERVAL then
					accumulated = 0
					tick()
				end
			end)
		)
		log:info(`queue in {mode} mode, role {currentRole() or "none"}{if reserved then ", reserved server" else ""}`)
	end,

	stop = function(_self)
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		for _, stopFn in stoppers do
			stopFn()
		end
		table.clear(stoppers)
		pads:stop()
		arrivals:stop()
		arrivalsActive = false
	end,

	configure = function(_self, update)
		config.homeRole = update.homeRole or config.homeRole
		local forceLive = update.forceLive
		if forceLive ~= nil then
			config.forceLive = forceLive
		end
	end,

	--[=[
		Sets how a departing party's payload is built (a match id). Nil sends `{}`.
	]=]
	setDepartData = function(_self, resolver)
		departData = resolver
	end,

	--[=[
		Sets where a local move puts players for `role` (Studio, unknown place, placeholder role). Nil clears.
	]=]
	setArrivalPoint = function(_self, role, resolver)
		landing:setArrivalPoint(role, resolver)
	end,

	--[=[
		Depart now for the player's pad (a game's own button or prompt). False when they are not aboard an
		open pad.
	]=]
	departNow = function(_self, player)
		return pads:departNow(player, serverNow())
	end,

	padOf = function(_self, player)
		return pads:padOf(player)
	end,

	--[=[
		Sends `players` to any public server of `role` with `payload` (a result summary). False, with a
		warning, for an empty or oversized party, a payload over the limits, an unregistered role, or a
		local move with no arrival point for the role (the players stay where they are).
	]=]
	returnParty = function(_self, players, role, payload)
		local clean, reason = QueueTeleportRules.payload(payload)
		if clean == nil then
			log:warn(`returnParty refused: {reason or "?"}`)
			return false
		end
		if #players == 0 or #players > QueueConstants.MAX_CAPACITY then
			log:warn(`returnParty refused: {#players} players`)
			return false
		end
		local route, routeReason = QueuePlaceRules.route(currentMode(), role, QueueRegistry.roles())
		if route == nil then
			log:warn(`returnParty refused: {routeReason or "?"}`)
			return false
		end
		if route.kind == "teleport" then
			local ticket: QueueTicket = {
				kind = "return",
				from = currentRole(),
				role = role,
				party = idsOf(players),
				capacity = #players,
				payload = clean,
			}
			teleports:send({
				players = players,
				placeId = route.placeId,
				reserve = false,
				data = HttpService:JSONEncode(QueueTeleportRules.encode(ticket)),
				onFinished = function(gaveUp, failReason)
					if #gaveUp > 0 then
						log:warn(`return trip failed for {#gaveUp} player(s): {failReason or "?"}`)
						toast(gaveUp, QueueConstants.RETURN_FAILED_TEXT)
					end
				end,
			})
		elseif not moveLocally(players, role) then
			log:warn(`returnParty refused: no arrival point for "{role}" in this server`)
			return false
		else
			for _, player in players do
				landing:landHome(player, clean)
			end
		end
		return true
	end,

	returnPayloadOf = function(_self, player)
		return landing:payloadOf(player)
	end,

	mode = function(_self)
		return currentMode()
	end,

	role = function(_self)
		return currentRole()
	end,

	runsRole = function(_self, role)
		return QueuePlaceRules.runsRole(currentMode(), currentRole(), role)
	end,

	getState = function(_self)
		return {
			mode = currentMode(),
			role = currentRole() or "none",
			pads = pads:count(),
			inFlight = teleports:inFlight(),
			arrival = if arrivalsActive then arrivals:getState() else nil,
			counters = table.clone(counters),
		}
	end,
}

return QueueServiceServer
