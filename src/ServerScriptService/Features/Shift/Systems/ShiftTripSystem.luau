--!strict
--[=[
	ShiftTripSystem: the shift's half of the trip between the depot and the office (Cleanup Crew spec §3
	steps 2-3 and 7, §5, §6.5). It decides who the crew is and sends them home:

	- Queue `arrived(party, payload)`: the party joins the crew (ShiftCrewTracker.join: added to a crew still
	  here, replacing one that has gone), and the payload's contract id (untrusted: it rode the teleport) is
	  resolved by DepotContractUtils for the result card;
	- Queue `joinedLate(player)`: an expected member who came after the start joins the crew and is moved to
	  the loading bay;
	- Queue `returned(player)` on this server (a local move home in Studio) and leaving the server take a
	  player out of the crew;
	- `sendHome` is Back to depot: the result card (ShiftCardUtils.encode) rides
	  QueueServiceServer:returnParty, and the crew is "leaving" for ShiftConstants.RETURN_WAIT_SECONDS, so no
	  shift restarts under it; if crew members are still here when that ends (the trip failed after Queue's
	  retries), each is told once and `startable` lets the next shift begin.

	It also gives Queue the loading bay as the shift's local-move arrival point and the depot as the home of
	redirected strangers, and on a live PUBLIC server of the shift place (someone reached it without a
	party; reserved servers are Queue's) it sends every player to the depot. ShiftServiceServer hands Round
	`eligible` (only the crew takes part) and Death `spawnFor` (crew in the loading bay; anyone else at the
	depot where this server runs it, otherwise in the loading bay).

	Spec-exempt shell (Players, Queue signals, teleports); membership and the leaving window are the specced
	ShiftCrewTracker, the card is the specced ShiftCardUtils, the contract the specced DepotContractUtils.

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
local ShiftCrewTracker = require(ServerScriptService.Features.Shift.State.ShiftCrewTracker)
local ShiftCardUtils = require(ServerScriptService.Features.Shift.Utils.ShiftCardUtils)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)

type QueuePayload = QueueTypes.QueuePayload

local STUCK_TEXT = "The truck couldn't get back to the depot. Another shift it is."
local REFUSED_TEXT = "The truck can't leave right now. Starting another shift."

export type ShiftTripSystem = {
	-- Round's `eligible`: only the crew takes part in a run. A plain function, handed over as it is.
	eligible: (player: Player) -> boolean,
	-- Death's spawn resolver. A plain function, handed over as it is.
	spawnFor: (player: Player) -> CFrame?,
	start: (self: ShiftTripSystem, onChanged: () -> ()) -> (),
	stop: (self: ShiftTripSystem) -> (),
	crew: (self: ShiftTripSystem) -> { Player },
	crewIds: (self: ShiftTripSystem, except: number?) -> { number },
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
	return QueueServiceServer:mode() == "live"
		and QueueServiceServer:role() == DepotConstants.ROLE_SHIFT
		and not QueuePlaceRules.isReservedServer(game.PrivateServerId, game.PrivateServerOwnerId)
end

local ShiftTripSystem = {}

function ShiftTripSystem.new(): ShiftTripSystem
	local members = ShiftCrewTracker.new()
	local contract: DepotTypes.Contract = DepotContractUtils.tonight(DepotConstants.CONTRACTS, os.time())
	local changed: () -> () = function() end
	local stoppers: { () -> () } = {}

	local function crewPlayers(): { Player }
		return playersOf(members:present(presentIds()))
	end

	local function toLoadingBay(player: Player)
		local character = player.Character
		local index = table.find(members:present(presentIds()), player.UserId) or 1
		if character ~= nil then
			character:PivotTo(OfficeServiceServer:spawnCFrame(index))
		end
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
			QueueServiceServer:setArrivalPoint(DepotConstants.ROLE_SHIFT, function(_player, index)
				return OfficeServiceServer:spawnCFrame(index)
			end)
			local arrived = QueueServiceServer.arrived:Connect(function(party, payload)
				if #party == 0 then
					return
				end
				members:join(idsOf(party), presentIds())
				contract = DepotContractUtils.resolve(DepotConstants.CONTRACTS, payload.contract)
				log:info(`a crew of {#party} arrived for {contract.id}`)
				changed()
			end)
			local late = QueueServiceServer.joinedLate:Connect(function(player)
				if members:add(player.UserId) then
					toLoadingBay(player)
					changed()
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
				log:warn("a public server of the shift place: every player is sent to the depot")
				local function sendToDepot(player: Player)
					QueueServiceServer:returnParty({ player }, DepotConstants.ROLE_DEPOT, {})
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
		end,

		crew = function(_self)
			return crewPlayers()
		end,

		crewIds = function(_self, except)
			return members:present(presentIds(except))
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
				payload = ShiftCardUtils.encode(results, { client = contract.client, shift = shift })
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
