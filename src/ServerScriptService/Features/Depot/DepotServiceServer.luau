--!strict
--[=[
	DepotServiceServer: the company garage, Cleanup Crew's lobby (spec §3 steps 1-3 and 7, §5, §6.2 "Depot").

	- At load it registers the place-role table (DepotPlaceUtils.roles of the hub and shift place ids; the shift
	  id is a placeholder until the developer creates the shift place) in Queue's QueueRegistry, so Queue knows
	  every role before services start.
	- Where this server runs the depot role (the depot place; in Studio every role runs in one server) it
	  builds the gameplay pieces into the place's Studio-built hub (a Model tagged DepotLayoutConstants.HUB.MODEL_TAG:
	  its marker parts say where, DepotHubSystem / DepotHubRules; an unplayable hub is a boot error naming every
	  problem), or, with no hub model at all, the graybox garage at DepotLayoutConstants.ORIGIN, validated by DepotLayoutRules (a
	  broken layout is a boot error): truck beds tagged QueuePad (Queue holds the parties, runs the countdown and
	  Depart now), tonight's contract board (DepotContractUtils.tonight), the result board, and a tag shell over each
	  truck that every client draws from Queue's state sync and the public `truck` field this service keeps
	  (DepotBillboardSystem).
	- A departing party carries tonight's contract id on its truck's map (setDepartData) and gets the drive card; a local move
	  to the depot lands on the spawn points (setArrivalPoint).
	- An arriving party (and a member who joins late), wherever it lands, gets the arrival card for its
	  contract (resolved from the untrusted payload), with the truck it rode (DepotContractUtils.truckOf) and the quota for the
	  crew that arrived (ShiftQuotaFormulas, the crew size the run's quota is set from; a late member gets the same card);
	  the drive card names the departing truck. A client says it listens (DepotEvents.Ready); a card
	  sent before that is held and delivered then, so a slow-loading client does not miss it.
	- A returning player (Queue `returned`) gets their result card (ShiftCardUtils.decode: teleport data is
	  untrusted) pinned on the result board, visible to them only, and a toast; the card's summary
	  (DepotEvents.LastShift, held until Ready like cards) feeds the board's "last shift" card.
	- In a hub-only server (this server runs the depot but not the shift) the depot places spawning players on
	  its spawn points (Death's spawn resolver); where Shift runs, Shift's trip owns it.
	- The hub's spots (Studio parts with a `depot-spot-*` Interaction kind) are answered by DepotSpotSystem.
	- The map pick (the School map plan): a truck's host (crew hosting's, HostServiceServer:hostOf) sends PickMap; a
	  pick from anyone else, or of no map, is dropped (DepotMapRules). Picks live in DepotMapTracker, are published as
	  the DepotConstants.MAP_WORLD_ENTRY world entry (every client aboard sees the host's pick), ride the depart data as
	  `map` (the Shift server reads it back with DepotMapRules.parse), and are forgotten when the party departs or the
	  truck has no host left (it emptied). A truck nobody picked for plays the office.
	- The contract board's prompt (Interaction kind DepotConstants.BOARD_KIND) sends the player Board with
	  tonight's contract id; the depart data carries the truck number (layout order) beside the contract id,
	  and each player's public `truck` field (DepotConstants.PUBLIC_TRUCK) follows the truck bed they stand in.

	Spec-exempt shell (Players, RunService, ByteNet, Queue signals); the decisions are the specced
	DepotLayoutRules, DepotContractUtils and ShiftCardUtils.

	@class DepotServiceServer
]=]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local DepotShared = ReplicatedStorage.Shared.Features.Depot
local DepotServer = ServerScriptService.Features.Depot
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local DepotConstants = require(DepotShared.Data.DepotConstants)
local TimecardConstants = require(ReplicatedStorage.Shared.Features.Timecard.Data.TimecardConstants)
local DepotTypes = require(DepotShared.Data.DepotTypes)
local DepotEvents = require(DepotShared.Net.DepotEvents)
local DepotMapRules = require(DepotShared.Rules.DepotMapRules)
local InteractionRegistry = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionRegistry)
local QueueTypes = require(ReplicatedStorage.Shared.Features.Queue.Data.QueueTypes)
local ShiftQuotaFormulas = require(ReplicatedStorage.Shared.Features.Shift.Utils.ShiftQuotaFormulas)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local TrainingConstants = require(ReplicatedStorage.Shared.Features.Training.Data.TrainingConstants)
local DepotLayoutConstants = require(DepotServer.Data.DepotLayoutConstants)
local DepotLayoutRules = require(DepotServer.Rules.DepotLayoutRules)
local DepotHubRules = require(DepotServer.Rules.DepotHubRules)
local DepotHubSystem = require(DepotServer.Systems.DepotHubSystem)
local DepotContractUtils = require(DepotServer.Utils.DepotContractUtils)
local DepotPlaceUtils = require(DepotServer.Utils.DepotPlaceUtils)
local DepotBuildSystem = require(DepotServer.Systems.DepotBuildSystem)
local DepotSpotSystem = require(DepotServer.Systems.DepotSpotSystem)
local DepotMapTracker = require(DepotServer.State.DepotMapTracker)
local HostServiceServer = require(ServerScriptService.Features.Host.HostServiceServer)
local StateSyncWorldStore = require(ServerScriptService.Features.StateSync.State.StateSyncWorldStore)
local DeathServiceServer = require(ServerScriptService.Features.Death.DeathServiceServer)
local InteractionServiceServer = require(ServerScriptService.Features.Interaction.InteractionServiceServer)
local QueueRegistry = require(ServerScriptService.Features.Queue.Data.QueueRegistry)
local QueueServiceServer = require(ServerScriptService.Features.Queue.QueueServiceServer)
local RequestHandler = require(ServerScriptService.Core.Net.RequestHandler)
local StateSyncPublicPlayerStore = require(ServerScriptService.Features.StateSync.State.StateSyncPublicPlayerStore)
local ShiftCardUtils = require(ServerScriptService.Features.Shift.Utils.ShiftCardUtils)
local ToastServiceServer = require(ServerScriptService.Features.Toast.ToastServiceServer)

-- The place-role table, at load: Queue resolves this server's role and routes when services start.
for role, placeId in DepotPlaceUtils.roles(DepotConstants.HUB_PLACE_ID, DepotConstants.SHIFT_PLACE_ID) do
	if not QueueRegistry.has(role) then
		QueueRegistry.register(role, placeId)
	end
end

-- The contract board's prompt (M3 UI): registered at load, before the board is built and tagged.
if not InteractionRegistry.has(DepotConstants.BOARD_KIND) then
	InteractionRegistry.register(DepotConstants.BOARD_KIND, { actionText = "Read", objectText = "Tonight’s job" })
end

if not InteractionRegistry.has(TimecardConstants.CLOCK_KIND) then
	InteractionRegistry.register(
		TimecardConstants.CLOCK_KIND,
		{ actionText = "View timecard", objectText = "Weekly time clock", maxDistance = 8 }
	)
end

if not InteractionRegistry.has(TimecardConstants.DAILY_KIND) then
	InteractionRegistry.register(
		TimecardConstants.DAILY_KIND,
		{ actionText = "Read", objectText = "Today's job", maxDistance = 8 }
	)
end
local TimecardEvents = require(ReplicatedStorage.Shared.Features.Timecard.Net.TimecardEvents)
local LAYOUT = DepotLayoutConstants.LAYOUT

local log = Logger.new("DepotServiceServer")

local built: DepotBuildSystem.Built? = nil
-- Where every gameplay piece stands: a Studio-built hub's markers when the place has one, else the graybox.
local plan: DepotHubRules.Plan = DepotHubRules.fromLayout(LAYOUT, DepotLayoutConstants.ORIGIN)
local contract: DepotTypes.Contract = DepotContractUtils.tonight(DepotConstants.CONTRACTS, os.time())
-- The contract of the crew that last arrived here (a late member gets the same card).
local crewContract: DepotTypes.Contract = contract
-- The truck that crew rode (from the untrusted payload; nil when unknown).
local crewTruck: number? = nil
-- That crew's quota (ShiftQuotaFormulas, by how many arrived); a late member is told the same one.
local crewQuota: number = ShiftQuotaFormulas.quota(1)
local stoppers: { () -> () } = {}
-- True while this hub-only server's depot owns Death's spawn resolver (Shift owns it wherever it runs).
local ownsSpawns = false
local cardsSent = 0
local cardsPinned = 0
local mapPicks = 0
-- Each truck's map pick (by Queue pad id), published as the MAP_WORLD_ENTRY world entry.
local maps = DepotMapTracker.new()

-- The map truck `pad`'s host picked (the office when none).
local function mapOfPad(pad: BasePart): ShiftTypes.MapId
	local padId = QueueServiceServer.pads:padIdOf(pad)
	return if padId ~= nil then maps:mapOf(padId) else DepotMapRules.parse(nil)
end

-- Tonight's job on `map` (the Office's is the board's `contract`).
local function contractOn(map: ShiftTypes.MapId): DepotTypes.Contract
	return DepotContractUtils.tonight(DepotMapRules.contractsOf(map), os.time())
end

local function publishMaps()
	StateSyncWorldStore.set(DepotConstants.MAP_WORLD_ENTRY, maps:snapshot())
end

-- Clients that said they listen for cards (DepotEvents.Ready); a card for anyone else waits in `held`.
local ready: { [Player]: true } = {}
local held: { [Player]: DepotTypes.CardMessage } = {}
local heldLast: { [Player]: DepotTypes.LastShift } = {}
-- The truck each player's public field currently says (refreshTrucks writes it on change).
local truckOf: { [number]: number } = {}
local departedForShift: { [number]: boolean } = {}
local timecardShiftPhase: (() -> ShiftTypes.ShiftPhase)? = nil

-- A training departure: the Training pad itself, or one of a Training zone's pads (TrainingZoneSystem).
local function isTrainingPad(pad: BasePart): boolean
	return CollectionService:HasTag(pad, TrainingConstants.TRUCK_TAG)
		or CollectionService:HasTag(pad, TrainingConstants.ZONE_PAD_TAG)
end

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

-- A host's map pick for the truck they are aboard. Dropped unless the id is a map and the sender hosts that truck.
local onPickMap = RequestHandler.wrap({
	name = "DepotPickMap",
	rateLimit = DepotConstants.MAP_REQUEST_RATE,
	handler = function(data: unknown, player: Player)
		if not DepotMapRules.isMap(data) then
			return
		end
		local pad = QueueServiceServer:padOf(player)
		local padId = if pad ~= nil then QueueServiceServer.pads:padIdOf(pad) else nil
		if pad == nil or padId == nil then
			return
		end
		if not DepotMapRules.canPick(player.UserId, HostServiceServer:hostOf(pad)) then
			return
		end
		if maps:pick(padId, DepotMapRules.parse(data)) then
			mapPicks += 1
			publishMaps()
		end
	end,
})

-- Forgets the map picks of trucks with no host left (emptied).
local function refreshMaps(current: DepotBuildSystem.Built)
	local live: { [string]: boolean } = {}
	for _, truck in current.trucks do
		local padId = QueueServiceServer.pads:padIdOf(truck.pad)
		if padId ~= nil and HostServiceServer:hostOf(truck.pad) ~= nil then
			live[padId] = true
		end
	end
	if maps:retain(live) then
		publishMaps()
	end
end

-- Keeps each player's public `truck` field on the truck bed they stand in (Queue's membership); written on change.
-- The truck tags themselves are drawn by the client from Queue's state sync and these fields (DepotBillboardSystem).
local function refreshTrucks()
	local current = built
	if current == nil then
		return
	end
	refreshMaps(current)
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
	canPunchTimecard: (self: DepotServiceServer, player: Player) -> boolean,
	setTimecardPhaseReader: (self: DepotServiceServer, phaseReader: (() -> ShiftTypes.ShiftPhase)?) -> (),
}

local DepotServiceServer: DepotServiceServer = {
	dependencies = {
		"QueueServiceServer",
		"ToastServiceServer",
		"InteractionServiceServer",
		"StateSyncServiceServer",
		"DeathServiceServer",
		"HostServiceServer",
	},

	--[=[
		Hands Queue the depart data and the depot arrival point, sends travel cards and result cards, and builds
		the garage where this server runs the depot role.
	]=]
	start = function(self)
		InteractionServiceServer:onInteract(TimecardConstants.CLOCK_KIND, function(player, _target)
			TimecardEvents.packets.OpenClipboard.sendTo(true, player)
		end)
		InteractionServiceServer:onInteract(TimecardConstants.DAILY_KIND, function(player, _target)
			TimecardEvents.packets.OpenClipboard.sendTo(false, player)
		end)
		QueueServiceServer:setDepartData(function(pad, _party)
			-- The Training truck's run plays the Training map (TrainingServiceServer); any other truck its host's pick,
			-- whose job is tonight's on that map (a School run is a school's job).
			local training = isTrainingPad(pad)
			local map: ShiftTypes.MapId = if training then DepotMapRules.parse(nil) else mapOfPad(pad)
			local payload: QueueTypes.QueuePayload = { contract = contractOn(map).id }
			-- The payload type allows no nil, so the key is only added for a known truck.
			local index = truckIndexOf(pad)
			if index ~= nil then
				payload.truck = index
			end
			if training then
				payload[TrainingConstants.MODE_KEY] = TrainingConstants.MODE
			else
				payload.map = map
			end
			return payload
		end)
		InteractionServiceServer:onInteract(DepotConstants.BOARD_KIND, function(player, _target)
			DepotEvents.packets.Board.sendTo(contract.id, player)
		end)
		-- The hub's spots (Supply Counter, standees, coffee, crew wall, rank chart, radio, shift bell).
		table.insert(stoppers, DepotSpotSystem.start())
		QueueServiceServer:setArrivalPoint(DepotConstants.ROLE_DEPOT, function(_player, index)
			return self:spawnCFrame(index)
		end)
		local departing = QueueServiceServer.departing:Connect(function(pad, party)
			-- The pick rode the depart data (resolved before this fires); read it for the drive card, then the truck
			-- starts over.
			local map: ShiftTypes.MapId = mapOfPad(pad)
			local padId = QueueServiceServer.pads:padIdOf(pad)
			if padId ~= nil and maps:clear(padId) then
				publishMaps()
			end
			-- A training trip has no contract to brief (training's own HUD and signs say what to do).
			if isTrainingPad(pad) then
				return
			end
			sendCard(party, DepotContractUtils.driveCard(contractOn(map), truckIndexOf(pad)))
		end)
		local arrived = QueueServiceServer.arrived:Connect(function(party, payload)
			-- Only accepted arrivals mark a player away; a failed departure leaves hub access intact.
			for _, player in party do
				departedForShift[player.UserId] = true
			end
			crewContract = DepotContractUtils.resolve(
				DepotMapRules.contractsOf(DepotMapRules.parse(payload.map)),
				payload.contract
			)
			crewTruck = DepotContractUtils.truckOf(payload.truck, DepotConstants.MAX_TRUCKS)
			crewQuota = ShiftQuotaFormulas.quota(#party)
			if payload[TrainingConstants.MODE_KEY] ~= TrainingConstants.MODE then
				sendCard(party, DepotContractUtils.arrivalCard(crewContract, crewQuota, crewTruck))
			end
		end)
		local late = QueueServiceServer.joinedLate:Connect(function(player)
			departedForShift[player.UserId] = true
			sendCard({ player }, DepotContractUtils.arrivalCard(crewContract, crewQuota, crewTruck))
		end)
		local returned = QueueServiceServer.returned:Connect(function(player, payload)
			departedForShift[player.UserId] = nil
			pinResultCard(player, payload)
		end)
		local listening = DepotEvents.packets.Ready.listen(function(data: boolean, player: Player?)
			if player then
				onReady(data, player)
			end
		end)
		local picking = DepotEvents.packets.PickMap.listen(function(data: string, player: Player?)
			if player then
				onPickMap(data, player)
			end
		end)
		publishMaps()
		local leaving = Players.PlayerRemoving:Connect(function(player)
			departedForShift[player.UserId] = nil
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
			picking()
			leaving:Disconnect()
		end)

		if not QueueServiceServer:runsRole(DepotConstants.ROLE_DEPOT) then
			log:info("not a depot server: the garage is not built")
			return
		end
		if DepotPlaceUtils.depotOwnsSpawns(true, QueueServiceServer:runsRole(DepotConstants.ROLE_SHIFT)) then
			DeathServiceServer:setSpawnPoint(function(player)
				return self:spawnCFrame(table.find(Players:GetPlayers(), player) or 1)
			end)
			ownsSpawns = true
			log:info("hub spawns: the depot places players")
		end
		local boardAttributes = DepotContractUtils.boardAttributes(contract)
		local hub = DepotHubSystem.find()
		if hub ~= nil then
			-- No quiet fallback (owner, 2026-11-10): a broken hub is a boot error that names every problem. The
			-- graybox below is only for a place with no hub model at all (the test place, a new game's first place).
			local authored =
				DepotHubRules.check(DepotHubSystem.markers(hub), DepotHubSystem.bounds(hub), hub:GetFullName())
			DepotHubSystem.hide(hub)
			plan = authored
			built = DepotBuildSystem.buildPlan(authored, boardAttributes)
			log:info(`depot: the Studio hub ({#authored.trucks} trucks, {#authored.spawns} spawns)`)
		else
			local ok, errors = DepotLayoutRules.validate(LAYOUT)
			assert(ok, `depot layout is invalid:\n{table.concat(errors, "\n")}`)
			plan = DepotHubRules.fromLayout(LAYOUT, DepotLayoutConstants.ORIGIN)
			built = DepotBuildSystem.build(LAYOUT, DepotLayoutConstants.ORIGIN, boardAttributes)
		end
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
		log:info(`depot built: {#plan.trucks} trucks, tonight's contract {contract.id}`)
	end,

	stop = function(_self)
		timecardShiftPhase = nil
		for _, stopFn in stoppers do
			stopFn()
		end
		table.clear(stoppers)
		table.clear(ready)
		table.clear(held)
		table.clear(heldLast)
		table.clear(truckOf)
		table.clear(departedForShift)
		maps:reset()
		StateSyncWorldStore.clear(DepotConstants.MAP_WORLD_ENTRY)
		QueueServiceServer:setDepartData(nil)
		QueueServiceServer:setArrivalPoint(DepotConstants.ROLE_DEPOT, nil)
		if ownsSpawns then
			DeathServiceServer:setSpawnPoint(nil)
			ownsSpawns = false
		end
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
		local spawns = plan.spawns
		local spot = spawns[(math.max(index, 1) - 1) % #spawns + 1]
		return spot * CFrame.new(0, DepotLayoutConstants.SPAWN_HEIGHT, 0)
	end,

	canPunchTimecard = function(_self, player)
		local phaseReader = timecardShiftPhase
		if built == nil or player.Parent ~= Players or phaseReader == nil then
			return false
		end
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		-- In the depot's bounds' space, moved so the box's floor corner is 0, 0, 0 (the graybox's own floor space).
		local bounds = plan.bounds
		local size = bounds.size
		local position = if root and root:IsA("BasePart")
			then bounds.cframe:PointToObjectSpace(root.Position) + size / 2
			else nil
		return DepotPlaceUtils.canPunchTimecard(
			QueueServiceServer:runsRole(DepotConstants.ROLE_DEPOT),
			phaseReader(),
			departedForShift[player.UserId] == true,
			position,
			{ minX = 0, minZ = 0, maxX = size.X, maxZ = size.Z },
			size.Y
		)
	end,
	-- Only callbacks cross into Depot; it does not require Timecard or Shift services.
	setTimecardPhaseReader = function(_self, phaseReader)
		timecardShiftPhase = phaseReader
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
			mapPicks = mapPicks,
		}
	end,
}

return DepotServiceServer
