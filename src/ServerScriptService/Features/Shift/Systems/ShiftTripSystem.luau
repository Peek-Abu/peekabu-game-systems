--!strict
--[=[
	ShiftTripSystem: the shift's half of the trip between the depot and the office (Cleanup Crew spec §3
	steps 2-3 and 7, §5, §6.5). It decides who the crew is and sends them home:

	- Queue `arrived(party, payload)`: the party joins the crew (ShiftCrewTracker.join: added to a crew still
	  here, replacing one that has gone), and the payload's contract id (untrusted: it rode the teleport) is
	  resolved by DepotContractUtils for the result card;
	- Queue `joinedLate(player)`: an expected member who came after the start joins the crew and is handed to
	  `admit` (Shift's transit holds them behind the load screen and places them in the truck); every member of an
	  arriving party is handed to `admit` too;
	- Queue `returned(player)` on this server (a local move home in Studio) and leaving the server take a
	  player out of the crew;
	- `sendHome` is Back to depot: the result card (ShiftCardUtils.encode) rides
	  QueueServiceServer:returnParty, and the crew is "leaving" for ShiftConstants.RETURN_WAIT_SECONDS, so no
	  shift restarts under it; if crew members are still here when that ends (the trip failed after Queue's
	  retries), each is told once and `startable` lets the next shift begin.

	It also gives Queue the shift's local-move arrival point: where the player already stands (in Studio, still aboard
	their truck at the depot), so nothing changes before the transit's load screen is up; the transit then places them in the truck). It gives Queue the depot as
	the home of redirected strangers, and on a live PUBLIC server of the shift place (someone reached it without a
	party; reserved servers are Queue's) it sends every player to the depot (and kicks one still here after the leaving window). ShiftServiceServer hands Round
	`eligible` (only the crew takes part) and Death `spawnFor` (crew in the loading bay; anyone else at the
	depot where this server runs it, otherwise in the loading bay).

	Spec-exempt shell (Players, Queue signals, teleports); membership and the leaving window are the specced
	ShiftCrewTracker, the stranded-server check ShiftPlaceRules, the card is the specced ShiftCardUtils, the contract the specced DepotContractUtils.

	@class ShiftTripSystem
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotTypes = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotTypes)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local DepotContractUtils = require(ServerScriptService.Features.Depot.Utils.DepotContractUtils)
local DepotServiceServer = require(ServerScriptService.Features.Depot.DepotServiceServer)
local OfficeServiceServer = require(ServerScriptService.Features.Office.OfficeServiceServer)
local QueuePlaceRules = require(ServerScriptService.Features.Queue.Rules.QueuePlaceRules)
local QueueServiceServer = require(ServerScriptService.Features.Queue.QueueServiceServer)
local ShiftPlaceRules = require(ServerScriptService.Features.Shift.Rules.ShiftPlaceRules)
local ShiftCrewTracker = require(ServerScriptService.Features.Shift.State.ShiftCrewTracker)
local ShiftCardUtils = require(ServerScriptService.Features.Shift.Utils.ShiftCardUtils)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)

type QueuePayload = QueueTypes.QueuePayload

local STUCK_TEXT = "The truck couldn't get back to the depot. Another shift it is."
local STRANDED_TEXT = "This shift server is empty. Rejoin from the depot."
local REFUSED_TEXT = "The truck can't leave right now. Starting another shift."

export type Options = {
	-- A crew member arrived on their own or with a party (Shift's transit places them).
	admit: (player: Player) -> (),
}

export type ShiftTripSystem = {
	-- Round's `eligible`: only the crew takes part in a run. A plain function, handed over as it is.
	eligible: (player: Player) -> boolean,
	-- Death's spawn resolver. A plain function, handed over as it is.
	spawnFor: (player: Player) -> CFrame?,
	start: (self: ShiftTripSystem, onChanged: () -> ()) -> (),
	stop: (self: ShiftTripSystem) -> (),
	crew: (self: ShiftTripSystem) -> { Player },
	crewIds: (self: ShiftTripSystem, except: number?) -> { number },
	-- The truck the crew rode (from the untrusted depart payload), nil when unknown.
	truck: (self: ShiftTripSystem) -> number?,
	-- The contract's client the crew is working for (the transit slip's destination).
	client: (self: ShiftTripSystem) -> string,
	startable: (self: ShiftTripSystem, now: number) -> number,
	sendHome: (self: ShiftTripSystem, results: ShiftTypes.ShiftResults?, shift: number, now: number) -> boolean,
	isLeaving: (self: ShiftTripSystem, now: number) -> boolean,
}

local log = Logger.new("ShiftTripSystem")

-- UserIds in the server, without `except` (a player who is leaving: Players still lists them in PlayerRemoving).
local function presentIds(except: number?): { number }
	local ids: { number } = {}
	for _, player in Players:GetPlayers() do
		if player.UserId ~= except then
			table.insert(ids, player.UserId)
		end
	end
	return ids
end

local function idsOf(players: { Player }): { number }
	local ids: { number } = {}
	for _, player in players do
		table.insert(ids, player.UserId)
	end
	return ids
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

-- A live public server of the shift place: nobody should be here without a party.
local function isPublicShiftServer(): boolean
	return ShiftPlaceRules.isStrandedServer(
		QueueServiceServer:mode(),
		QueueServiceServer:role(),
		QueuePlaceRules.isReservedServer(game.PrivateServerId, game.PrivateServerOwnerId)
	)
end

local ShiftTripSystem = {}

function ShiftTripSystem.new(options: Options): ShiftTripSystem
	local members = ShiftCrewTracker.new()
	local contract: DepotTypes.Contract = DepotContractUtils.tonight(DepotConstants.CONTRACTS, os.time())
	local truck: number? = nil
	local changed: () -> () = function() end
	local stoppers: { () -> () } = {}

	local function crewPlayers(): { Player }
		return playersOf(members:present(presentIds()))
	end

	local system: ShiftTripSystem = {
		eligible = function(player)
			return members:has(player.UserId)
		end,

		spawnFor = function(player)
			local index = table.find(members:present(presentIds()), player.UserId)
			if index ~= nil or not QueueServiceServer:runsRole(DepotConstants.ROLE_DEPOT) then
				return OfficeServiceServer:spawnCFrame(index or 1)
			end
			return DepotServiceServer:spawnCFrame(table.find(Players:GetPlayers(), player) or 1)
		end,

		start = function(_self, onChanged)
			changed = onChanged
			QueueServiceServer:configure({ homeRole = DepotConstants.ROLE_DEPOT })
			-- A local move leaves the party where it stands; the transit moves them once their screens are covered.
			QueueServiceServer:setArrivalPoint(DepotConstants.ROLE_SHIFT, function(player, index)
				local character = player.Character
				if character ~= nil then
					return character:GetPivot()
				end
				return OfficeServiceServer:spawnCFrame(index)
			end)
			local arrived = QueueServiceServer.arrived:Connect(function(party, payload)
				if #party == 0 then
					return
				end
				members:join(idsOf(party), presentIds())
				contract = DepotContractUtils.resolve(DepotConstants.CONTRACTS, payload.contract)
				truck = DepotContractUtils.truckOf(payload.truck, DepotConstants.MAX_TRUCKS)
				log:info(`a crew of {#party} arrived for {contract.id}`)
				changed()
				for _, player in party do
					options.admit(player)
				end
			end)
			local late = QueueServiceServer.joinedLate:Connect(function(player)
				if members:add(player.UserId) then
					changed()
					options.admit(player)
				end
			end)
			local returned = QueueServiceServer.returned:Connect(function(player, _payload)
				if members:remove(player.UserId) then
					changed()
				end
			end)
			local leaving = Players.PlayerRemoving:Connect(function(player)
				if members:remove(player.UserId) then
					changed()
				end
			end)
			table.insert(stoppers, function()
				arrived:Disconnect()
				late:Disconnect()
				returned:Disconnect()
				leaving:Disconnect()
			end)
			if isPublicShiftServer() then
				log:warn("a public server of the shift place: every player is sent to the hub")
				local function sendToDepot(player: Player)
					QueueServiceServer:returnParty({ player }, DepotConstants.ROLE_DEPOT, {})
					-- Still here after the window: the teleport failed; nothing else would ever remove them.
					task.delay(ShiftConstants.RETURN_WAIT_SECONDS, function()
						if player.Parent == Players then
							player:Kick(STRANDED_TEXT)
						end
					end)
				end
				for _, player in Players:GetPlayers() do
					sendToDepot(player)
				end
				local joining = Players.PlayerAdded:Connect(sendToDepot)
				table.insert(stoppers, function()
					joining:Disconnect()
				end)
			end
		end,

		stop = function(_self)
			for _, stopFn in stoppers do
				stopFn()
			end
			table.clear(stoppers)
			QueueServiceServer:setArrivalPoint(DepotConstants.ROLE_SHIFT, nil)
			members:clear()
			truck = nil
		end,

		crew = function(_self)
			return crewPlayers()
		end,

		crewIds = function(_self, except)
			return members:present(presentIds(except))
		end,

		truck = function(_self)
			return truck
		end,

		client = function(_self)
			return contract.client
		end,

		startable = function(_self, now)
			if members:expired(now) then
				local stuck = crewPlayers()
				for _, player in stuck do
					ToastServiceServer:send(player, { text = STUCK_TEXT, duration = 5 })
				end
				if #stuck > 0 then
					log:warn(`{#stuck} crew member(s) never left for the depot; the next shift may start`)
				end
			end
			return members:startable(presentIds(), now)
		end,

		sendHome = function(_self, results, shift, now)
			local players = crewPlayers()
			if #players == 0 then
				return false
			end
			local payload: QueuePayload = {}
			if results ~= nil then
				payload = ShiftCardUtils.encode(results, { client = contract.client, shift = shift, truck = truck })
			end
			if not QueueServiceServer:returnParty(players, DepotConstants.ROLE_DEPOT, payload) then
				for _, player in players do
					ToastServiceServer:send(player, { text = REFUSED_TEXT, duration = 5 })
				end
				return false
			end
			members:leave(now, ShiftConstants.RETURN_WAIT_SECONDS)
			changed()
			return true
		end,

		isLeaving = function(_self, now)
			return members:isLeaving(now)
		end,
	}
	return system
end

return ShiftTripSystem
