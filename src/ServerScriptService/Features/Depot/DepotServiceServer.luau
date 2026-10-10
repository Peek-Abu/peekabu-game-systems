--!strict
--[=[
	DepotServiceServer: the company garage, Cleanup Crew's lobby (spec §3 steps 1-3 and 7, §5, §6.2 "Depot").

	- At load it registers the place-role table (DepotConstants.PLACE_IDS: placeholders until the developer
	  creates the shift place) in Queue's QueueRegistry, so Queue knows every role before services start.
	- Where this server runs the depot role (the depot place; in Studio every role runs in one server) it
	  builds the graybox garage at DepotLayoutConstants.ORIGIN, validated by DepotLayoutRules (a broken
	  layout is a boot error): truck beds tagged QueuePad (Queue holds the parties, runs the countdown and
	  Depart now), tonight's contract board (DepotContractUtils.tonight), the result board, and a label over
	  each truck counting who is aboard (QueueServiceServer:padOf; Queue's own HUD widget shows the countdown
	  to those aboard).
	- A departing party carries tonight's contract id (setDepartData) and gets the drive card; a local move
	  to the depot lands on the spawn points (setArrivalPoint).
	- An arriving party (and a member who joins late), wherever it lands, gets the arrival card for its
	  contract (resolved from the untrusted payload). A client says it listens (DepotEvents.Ready); a card
	  sent before that is held and delivered then, so a slow-loading client does not miss it.
	- A returning player (Queue `returned`) gets their result card (ShiftCardUtils.decode: teleport data is
	  untrusted) pinned on the result board, visible to them only, and a toast.

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
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local DepotLayoutConstants = require(DepotServer.Data.DepotLayoutConstants)
local DepotLayoutRules = require(DepotServer.Rules.DepotLayoutRules)
local DepotContractUtils = require(DepotServer.Utils.DepotContractUtils)
local DepotBuildSystem = require(DepotServer.Systems.DepotBuildSystem)
local QueueRegistry = require(ServerScriptService.Features.Queue.Data.QueueRegistry)
local QueueServiceServer = require(ServerScriptService.Features.Queue.QueueServiceServer)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local ShiftCardUtils = require(ServerScriptService.Features.Shift.Utils.ShiftCardUtils)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)

-- The place-role table, at load: Queue resolves this server's role and routes when services start.
for role, placeId in DepotConstants.PLACE_IDS do
	if not QueueRegistry.has(role) then
		QueueRegistry.register(role, placeId)
	end
end

local LAYOUT = DepotLayoutConstants.LAYOUT

local log = Logger.new("DepotServiceServer")

local built: DepotBuildSystem.Built? = nil
local contract: DepotTypes.Contract = DepotContractUtils.tonight(DepotConstants.CONTRACTS, os.time())
-- The contract of the crew that last arrived here (a late member gets the same card).
local crewContract: DepotTypes.Contract = contract
local stoppers: { () -> () } = {}
local cardsSent = 0
local cardsPinned = 0

-- Clients that said they listen for cards (DepotEvents.Ready); a card for anyone else waits in `held`.
local ready: { [Player]: true } = {}
local held: { [Player]: DepotTypes.CardMessage } = {}

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
	end,
})

local function padText(index: number, aboard: number, capacity: number): string
	if aboard == 0 then
		return `TRUCK {index}\n0/{capacity} aboard\nStand in the bed to join`
	end
	return `TRUCK {index}\n{aboard}/{capacity} aboard`
end

-- Recounts who stands in each truck bed (Queue's membership) and rewrites the labels.
local function refreshLabels()
	local current = built
	if current == nil then
		return
	end
	local aboard: { [BasePart]: number } = {}
	for _, player in Players:GetPlayers() do
		local pad = QueueServiceServer:padOf(player)
		if pad ~= nil then
			aboard[pad] = (aboard[pad] or 0) + 1
		end
	end
	for _, truck in current.trucks do
		truck.label.Text = padText(truck.index, aboard[truck.pad] or 0, truck.capacity)
	end
end

local function pinResultCard(player: Player, payload: QueueTypes.QueuePayload)
	local current = built
	local card = ShiftCardUtils.decode(payload)
	if current == nil or card == nil then
		return
	end
	local lines = ShiftCardUtils.lines(card)
	task.spawn(function()
		if DepotBuildSystem.pinCard(player, current.resultBoard, lines) then
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
	dependencies = { "QueueServiceServer", "ToastServiceServer" },

	--[=[
		Hands Queue the depart data and the depot arrival point, sends travel cards and result cards, and builds
		the garage where this server runs the depot role.
	]=]
	start = function(self)
		QueueServiceServer:setDepartData(function(_pad, _party)
			return { contract = contract.id }
		end)
		QueueServiceServer:setArrivalPoint(DepotConstants.ROLE_DEPOT, function(_player, index)
			return self:spawnCFrame(index)
		end)
		local departing = QueueServiceServer.departing:Connect(function(_pad, party)
			sendCard(party, DepotContractUtils.driveCard(contract))
		end)
		local arrived = QueueServiceServer.arrived:Connect(function(party, payload)
			crewContract = DepotContractUtils.resolve(DepotConstants.CONTRACTS, payload.contract)
			sendCard(party, DepotContractUtils.arrivalCard(crewContract, ShiftConstants.QUOTA))
		end)
		local late = QueueServiceServer.joinedLate:Connect(function(player)
			sendCard({ player }, DepotContractUtils.arrivalCard(crewContract, ShiftConstants.QUOTA))
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
		built = DepotBuildSystem.build(
			LAYOUT,
			DepotLayoutConstants.ORIGIN,
			DepotContractUtils.boardLines(contract, ShiftConstants.QUOTA)
		)
		refreshLabels()
		local elapsed = 0
		local ticking = RunService.Heartbeat:Connect(function(deltaTime)
			elapsed += deltaTime
			if elapsed >= DepotLayoutConstants.LABEL_INTERVAL then
				elapsed = 0
				refreshLabels()
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
