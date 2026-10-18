--!strict
--[=[
	DepotServiceServer: the company garage, Cleanup Crew's lobby (spec §3 steps 1-3 and 7, §5, §6.2 "Depot").

	- At load it registers the place-role table (DepotConstants.PLACE_IDS: placeholders until the developer
	  creates the shift place) in Queue's QueueRegistry, so Queue knows every role before services start.
	- Where this server runs the depot role (the depot place; in Studio every role runs in one server) it
	  builds the graybox garage at DepotLayoutConstants.ORIGIN, validated by DepotLayoutRules (a broken
	  layout is a boot error): truck beds tagged QueuePad (Queue holds the parties, runs the countdown and
	  Depart now), tonight's contract board (DepotContractUtils.tonight), the result board, and a tag shell over each
	  truck that every client draws from Queue's state sync and the public `truck` field this service keeps
	  (DepotBillboardSystem).
	- A departing party carries tonight's contract id (setDepartData) and gets the drive card; a local move
	  to the depot lands on the spawn points (setArrivalPoint).
	- An arriving party (and a member who joins late), wherever it lands, gets the arrival card for its
	  contract (resolved from the untrusted payload), with the truck it rode (DepotContractUtils.truckOf); the drive card names the departing truck. A client says it listens (DepotEvents.Ready); a card
	  sent before that is held and delivered then, so a slow-loading client does not miss it.
	- A returning player (Queue `returned`) gets their result card (ShiftCardUtils.decode: teleport data is
	  untrusted) pinned on the result board, visible to them only, and a toast; the card's summary
	  (DepotEvents.LastShift, held until Ready like cards) feeds the board's "last shift" card.
	- The contract board's prompt (Interaction kind DepotConstants.BOARD_KIND) sends the player Board with
	  tonight's contract id; the depart data carries the truck number (layout order) beside the contract id,
	  and each player's public `truck` field (DepotConstants.PUBLIC_TRUCK) follows the truck bed they stand in.

	Spec-exempt shell (Players, RunService, ByteNet, Queue signals); the decisions are the specced
	DepotLayoutRules, DepotContractUtils and ShiftCardUtils.

	@class DepotServiceServer
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local DepotShared = ReplicatedStorage.Shared.Features.Depot
local DepotServer = ServerScriptService.Features.Depot
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local DepotConstants = require(DepotShared.Data.DepotConstants)
local DepotTypes = require(DepotShared.Data.DepotTypes)
local DepotEvents = require(DepotShared.Net.DepotEvents)
local InteractionRegistry = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionRegistry)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local DepotLayoutConstants = require(DepotServer.Data.DepotLayoutConstants)
local DepotLayoutRules = require(DepotServer.Rules.DepotLayoutRules)
local DepotContractUtils = require(DepotServer.Utils.DepotContractUtils)
local DepotBuildSystem = require(DepotServer.Systems.DepotBuildSystem)
local InteractionServiceServer = require(ServerScriptService.Features.Interaction.InteractionServiceServer)
local QueueRegistry = require(ServerScriptService.Features.Queue.Data.QueueRegistry)
local QueueServiceServer = require(ServerScriptService.Features.Queue.QueueServiceServer)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local StateSyncPublicPlayerStore = require(ServerScriptService.Features.StateSync.State.StateSyncPublicPlayerStore)
local ShiftCardUtils = require(ServerScriptService.Features.Shift.Utils.ShiftCardUtils)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)

-- The place-role table, at load: Queue resolves this server's role and routes when services start.
for role, placeId in DepotConstants.PLACE_IDS do
	if not QueueRegistry.has(role) then
		QueueRegistry.register(role, placeId)
	end
end

-- The contract board's prompt (M3 UI): registered at load, before the board is built and tagged.
if not InteractionRegistry.has(DepotConstants.BOARD_KIND) then
	InteractionRegistry.register(DepotConstants.BOARD_KIND, { actionText = "Read", objectText = "Work order" })
end

local LAYOUT = DepotLayoutConstants.LAYOUT

local log = Logger.new("DepotServiceServer")

local built: DepotBuildSystem.Built? = nil
local contract: DepotTypes.Contract = DepotContractUtils.tonight(DepotConstants.CONTRACTS, os.time())
-- The contract of the crew that last arrived here (a late member gets the same card).
local crewContract: DepotTypes.Contract = contract
-- The truck that crew rode (from the untrusted payload; nil when unknown).
local crewTruck: number? = nil
local stoppers: { () -> () } = {}
local cardsSent = 0
local cardsPinned = 0

-- Clients that said they listen for cards (DepotEvents.Ready); a card for anyone else waits in `held`.
local ready: { [Player]: true } = {}
local held: { [Player]: DepotTypes.CardMessage } = {}
local heldLast: { [Player]: DepotTypes.LastShift } = {}
-- The truck each player's public field currently says (refreshTrucks writes it on change).
local truckOf: { [number]: number } = {}

-- The truck number (layout order) of a pad, or nil before the garage is built.
local function truckIndexOf(pad: BasePart): number?
	local current = built
	if current == nil then
		return nil
	end
	for _, truck in current.trucks do
		if truck.pad == pad then
			return truck.index
		end
	end
	return nil
end

local function sendCard(players: { Player }, card: DepotTypes.CardMessage)
	for _, player in players do
		if player.Parent == Players then
			if ready[player] then
				DepotEvents.packets.Card.sendTo(card, player)
				cardsSent += 1
			else
				held[player] = card
			end
		end
	end
end

-- The last shift goes the same way: now when the client listens, else when it says so.
local function sendLast(player: Player, summary: DepotTypes.LastShift)
	if player.Parent ~= Players then
		return
	end
	if ready[player] then
		DepotEvents.packets.LastShift.sendTo(summary, player)
	else
		heldLast[player] = summary
	end
end

local onReady = RequestHandler.wrap({
	name = "DepotReady",
	rateLimit = { maxRequests = 5, windowSeconds = 5 },
	handler = function(_data: unknown, player: Player)
		if ready[player] then
			return
		end
		ready[player] = true
		local card = held[player]
		if card ~= nil then
			held[player] = nil
			sendCard({ player }, card)
		end
		local last = heldLast[player]
		if last ~= nil then
			heldLast[player] = nil
			sendLast(player, last)
		end
	end,
})

-- Keeps each player's public `truck` field on the truck bed they stand in (Queue's membership); written on change.
-- The truck tags themselves are drawn by the client from Queue's state sync and these fields (DepotBillboardSystem).
local function refreshTrucks()
	if built == nil then
		return
	end
	for _, player in Players:GetPlayers() do
		local pad = QueueServiceServer:padOf(player)
		local index = if pad ~= nil then truckIndexOf(pad) else nil
		if index ~= truckOf[player.UserId] then
			if index ~= nil then
				truckOf[player.UserId] = index
				StateSyncPublicPlayerStore.set(player.UserId, { [DepotConstants.PUBLIC_TRUCK] = index })
			else
				truckOf[player.UserId] = nil
				StateSyncPublicPlayerStore.clearField(player.UserId, DepotConstants.PUBLIC_TRUCK)
			end
		end
	end
end

local function pinResultCard(player: Player, payload: QueueTypes.QueuePayload)
	local current = built
	local card = ShiftCardUtils.decode(payload)
	if current == nil or card == nil then
		return
	end
	sendLast(player, ShiftCardUtils.summary(card))
	local attributes = ShiftCardUtils.attributes(card)
	task.spawn(function()
		if DepotBuildSystem.pinCard(player, current.resultBoard, attributes) then
			cardsPinned += 1
			ToastServiceServer:send(player, { text = DepotConstants.RETURN_TEXT, duration = 6 })
		end
	end)
end

export type DepotServiceServer = {
	dependencies: { string },
	start: (self: DepotServiceServer) -> (),
	stop: (self: DepotServiceServer) -> (),
	getState: (self: DepotServiceServer) -> { [string]: string | number | boolean },
	spawnCFrame: (self: DepotServiceServer, index: number) -> CFrame,
	contract: (self: DepotServiceServer) -> DepotTypes.Contract,
}

local DepotServiceServer: DepotServiceServer = {
	dependencies = {
		"QueueServiceServer",
		"ToastServiceServer",
		"InteractionServiceServer",
		"StateSyncServiceServer",
	},

	--[=[
		Hands Queue the depart data and the depot arrival point, sends travel cards and result cards, and builds
		the garage where this server runs the depot role.
	]=]
	start = function(self)
		QueueServiceServer:setDepartData(function(pad, _party)
			local payload: QueueTypes.QueuePayload = { contract = contract.id }
			-- The payload type allows no nil, so the key is only added for a known truck.
			local index = truckIndexOf(pad)
			if index ~= nil then
				payload.truck = index
			end
			return payload
		end)
		InteractionServiceServer:onInteract(DepotConstants.BOARD_KIND, function(player, _target)
			DepotEvents.packets.Board.sendTo(contract.id, player)
		end)
		QueueServiceServer:setArrivalPoint(DepotConstants.ROLE_DEPOT, function(_player, index)
			return self:spawnCFrame(index)
		end)
		local departing = QueueServiceServer.departing:Connect(function(pad, party)
			sendCard(party, DepotContractUtils.driveCard(contract, truckIndexOf(pad)))
		end)
		local arrived = QueueServiceServer.arrived:Connect(function(party, payload)
			crewContract = DepotContractUtils.resolve(DepotConstants.CONTRACTS, payload.contract)
			crewTruck = DepotContractUtils.truckOf(payload.truck, DepotConstants.MAX_TRUCKS)
			sendCard(party, DepotContractUtils.arrivalCard(crewContract, ShiftConstants.QUOTA, crewTruck))
		end)
		local late = QueueServiceServer.joinedLate:Connect(function(player)
			sendCard({ player }, DepotContractUtils.arrivalCard(crewContract, ShiftConstants.QUOTA, crewTruck))
		end)
		local returned = QueueServiceServer.returned:Connect(pinResultCard)
		local listening = DepotEvents.packets.Ready.listen(function(data: boolean, player: Player?)
			if player then
				onReady(data, player)
			end
		end)
		local leaving = Players.PlayerRemoving:Connect(function(player)
			ready[player] = nil
			held[player] = nil
			heldLast[player] = nil
			truckOf[player.UserId] = nil
		end)
		table.insert(stoppers, function()
			departing:Disconnect()
			arrived:Disconnect()
			late:Disconnect()
			returned:Disconnect()
			listening()
			leaving:Disconnect()
		end)

		if not QueueServiceServer:runsRole(DepotConstants.ROLE_DEPOT) then
			log:info("not a depot server: the garage is not built")
			return
		end
		local ok, errors = DepotLayoutRules.validate(LAYOUT)
		assert(ok, `depot layout is invalid:\n{table.concat(errors, "\n")}`)
		built =
			DepotBuildSystem.build(LAYOUT, DepotLayoutConstants.ORIGIN, DepotContractUtils.boardAttributes(contract))
		refreshTrucks()
		local elapsed = 0
		local ticking = RunService.Heartbeat:Connect(function(deltaTime)
			elapsed += deltaTime
			if elapsed >= DepotLayoutConstants.TRUCK_INTERVAL then
				elapsed = 0
				refreshTrucks()
			end
		end)
		table.insert(stoppers, function()
			ticking:Disconnect()
		end)
		log:info(`depot built: {#LAYOUT.trucks} trucks, tonight's contract {contract.id}`)
	end,

	stop = function(_self)
		for _, stopFn in stoppers do
			stopFn()
		end
		table.clear(stoppers)
		table.clear(ready)
		table.clear(held)
		table.clear(heldLast)
		table.clear(truckOf)
		QueueServiceServer:setDepartData(nil)
		QueueServiceServer:setArrivalPoint(DepotConstants.ROLE_DEPOT, nil)
		local current = built
		if current ~= nil then
			current.model:Destroy()
			built = nil
		end
	end,

	--[=[
		Where the `index`-th player appears in the depot (wrapping over the spawn points).
	]=]
	spawnCFrame = function(_self, index)
		local spawns = LAYOUT.spawns
		local point = spawns[(math.max(index, 1) - 1) % #spawns + 1]
		return DepotLayoutConstants.ORIGIN * CFrame.new(point.x, DepotLayoutConstants.SPAWN_HEIGHT, point.z)
	end,

	contract = function(_self)
		return contract
	end,

	getState = function(_self)
		local current = built
		return {
			built = current ~= nil,
			trucks = if current ~= nil then #current.trucks else 0,
			contract = contract.id,
			mode = QueueServiceServer:mode(),
			role = QueueServiceServer:role() or "none",
			cardsSent = cardsSent,
			cardsPinned = cardsPinned,
		}
	end,
}

return DepotServiceServer
