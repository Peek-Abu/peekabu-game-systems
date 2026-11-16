--!strict
--[=[
	OfficeServiceServer: the Harlow & Finch office (Cleanup Crew spec Â§6.2 "Office", Â§6.5 "Reset"). At start
	it validates the authored layout (OfficeLayoutRules; a broken layout is a boot error) and builds the
	authored core at start; seeded modular geometry each shift (OfficeBuildSystem), then its night decor (OfficeDecorSystem), at OfficeConstants.ORIGIN, far from the origin where M4's depot
	goes. Each shift `beginShift` rolls the spawns (OfficeSpawnUtils, re-rolling with the next seed, up to
	ROLL_ATTEMPTS times, if OfficeSpawnRules finds a broken guarantee; then it proceeds with the last roll) and places them in ONE per-shift folder owned by ONE Janitor:
	piles (Vacuum), items (Cargo), hidden items under piles (revealed when the pile is cleared; the pile is marked
	CargoConstants.BURIED_ATTRIBUTE, its glint), and desk / locker contents (Cargo). Every valuable spawns with the
	appraisal the roll gave it, fully grimy (the loot loop). `reset` destroys that folder and forgets the shift.

	M2: Harlow's route, rest point, the loading bay he may walk (`loadingBay`) and the one safe place, the truck's box
	(`safeZone`).

	Outside (generated maps): `outdoors` is the grounds' world boxes (the Outdoors safe volumes), `entrance(id)` an
	entrance's world outside and inside frames, and `whereIs` names the ground a point outside stands on. `safeZone`
	stays the truck's box: clocking out "aboard" still means in the truck.

	Doors: OfficeDoorSystem.listen registers the door prompt (OfficeConstants.DOOR_KIND, "Open / close"); it toggles the door on interact
	(a player's accepted close slams: a "door" noise, DOOR_SLAM_RADIUS; a close with Harlow about is refused), and
	`openDoorsNear` lets Harlow open the closed doors he is walking through (on his line of travel: within DOOR_REACH,
	ahead of his heading and within a door's half-width plus his agent radius of his heading line; none with no
	heading; true when it opened one, false when no office stands). Facade leaves are locked set dressing: their
	prompt (OfficeConstants.FACADE_KIND, "Locked", OfficeDoorSystem.listen) only rattles the leaf.

	Ordering guarantee for anything that spawns into a shift (Occupant's Manager): `ready` fires (deferred, with the shift
	folder) once `beginShift` has rebuilt the office and placed every spawn, and `isReady` says whether that shift is
	still standing (false after `reset`). Shift's transit calls `beginShift` before Shift enters `running`, so by the
	time ShiftServiceServer.changed reports `running` the office, its route and `container()` are already the new
	shift's. `seed` is the rebuilt layout's seed (the model's LayoutSeed attribute), which the transit hands clients.
	When generation from the shift's seed errors, the rebuild warns and tries the next seed up (GENERATE_RETRIES more
	times) before raising, so `seed` is the seed actually used.

	Maps: `beginShift`'s `map` picks the generator ("school": SchoolLayoutGenerationUtils, from the same base layout;
	"office": OfficeLayoutGenerationUtils). Both output an OfficeTypes.Layout and pass the same checks, so everything
	downstream (build, spawns, hide, the route) is unchanged. `map` is the map standing now (the model's
	OfficeConstants.MAP_ATTRIBUTE; "office" at boot).

	Authored sites (`useSite`, OfficeTypes.Site): a run can use a Studio-built map instead (the Training map); every
	accessor answers from it and `beginShift` lets it place its own spawns. The generated office still stands unused.

	The office is built only where the shift role runs (QueueServiceServer:runsRole); a hub-only server builds nothing.

	Stray guard: `rebuild` (after destroying the tracked model) and the first build at `start` destroy every Workspace
	child named OfficeConstants.MODEL_NAME (OfficeBuildSystem.clearStrays, which warns "removed N stray office
	model(s)" when there were any): a transit whose reset errored (it runs guarded) must never leave an old office,
	with its door leaves, standing beside the new one. `stop` still destroys the tracked model.

	Split out of this file: OfficeRebuildSystem (layout generation with retries, the generated-layout checks, the
	piecewise teardown), OfficeShiftSpawnSystem (the spawn roll and placing it, the overtime batch, hidden-item reveals
	and searched dressing) and OfficeSiteUtils (the world answers: spawn frame, route, rest point, safe zone, loading
	bay, whereIs, outdoors, entrances; an authored site's when one stands in).

	Spec-exempt shell (Instances, signals); the decisions are the specced OfficeLayoutRules, OfficeLayoutUtils,
	OfficeSpawnUtils and OfficeSpawnRules.

	@class OfficeServiceServer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OfficeServer = ServerScriptService.Features.Office
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local OfficeAnomalyConstants = require(ReplicatedStorage.Shared.Features.Office.Data.OfficeAnomalyConstants)
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeLayoutConstants = require(OfficeServer.Data.OfficeLayoutConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeLayoutRules = require(OfficeServer.Rules.OfficeLayoutRules)
local OfficeVariationRules = require(OfficeServer.Rules.OfficeVariationRules)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)
local ShiftTypes = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftTypes)
local OfficeFurniturePlacementUtils = require(OfficeServer.Utils.OfficeFurniturePlacementUtils)
local OfficeSpawnUtils = require(OfficeServer.Utils.OfficeSpawnUtils)
local OfficeSiteUtils = require(OfficeServer.Utils.OfficeSiteUtils)
local OfficeLootUtils = require(OfficeServer.Utils.OfficeLootUtils)
local OfficeOozeSystem = require(OfficeServer.Systems.OfficeOozeSystem)
local OfficeBuildSystem = require(OfficeServer.Systems.OfficeBuildSystem)
local OfficeDecorSystem = require(OfficeServer.Systems.OfficeDecorSystem)
local OfficeDoorSystem = require(OfficeServer.Systems.OfficeDoorSystem)
local OfficeDressingSystem = require(OfficeServer.Systems.OfficeDressingSystem)
local OfficeSearchedDressingSystem = require(OfficeServer.Systems.OfficeSearchedDressingSystem)
local OfficeRebuildSystem = require(OfficeServer.Systems.OfficeRebuildSystem)
local OfficeShiftSpawnSystem = require(OfficeServer.Systems.OfficeShiftSpawnSystem)
local OfficeBuildPaceTracker = require(OfficeServer.State.OfficeBuildPaceTracker)
local CargoServiceServer = require(ServerScriptService.Features.Cargo.CargoServiceServer)
local QueueServiceServer = require(ServerScriptService.Features.Queue.QueueServiceServer)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local InteractionServiceServer = require(ServerScriptService.Features.Interaction.InteractionServiceServer)
local NoiseServiceServer = require(ServerScriptService.Features.Noise.NoiseServiceServer)

type Marker = OfficeTypes.Marker

local log = Logger.new("OfficeServiceServer")

local LAYOUT = OfficeRebuildSystem.fitted(OfficeFurniturePlacementUtils.normalize(OfficeLayoutConstants.LAYOUT))
local depths = OfficeLayoutUtils.depths(LAYOUT)

local markerById: { [string]: Marker } = {}
for _, marker in LAYOUT.markers do
	markerById[marker.id] = marker
end

local built: OfficeBuildSystem.Built? = nil
-- Whether a rebuild is under way (it yields between pieces): a second beginShift waits for it instead of building a
-- second office beside it.
local rebuilding = false
local shiftJanitor = Janitor.new()
local shiftFolder: Folder? = nil
local dressing = OfficeSearchedDressingSystem.new()
-- pile â†’ the item hidden under it, for this shift.
local hidden: { [BasePart]: BasePart } = {}
local lastPlan: OfficeTypes.SpawnPlan? = nil
-- Whether this shift's overtime batch has spawned (one batch per shift; cleared by beginShift and reset).
local overtimeSpawned = false
local stoppers: { () -> () } = {}
-- The seed of the layout standing now (nil: the boot layout).
local layoutSeed: number? = nil
-- The map standing now (the boot layout is the office).
local layoutMap: ShiftTypes.MapId = "office"
-- A developer's forced anomaly set (the anomaly command); nil: the seed's pick. A rebuild drops it.
local forcedAnomalies: { OfficeAnomalyConstants.AnomalyId }? = nil
-- Fired (with the shift folder) once a shift's office is rebuilt and every spawn placed.
local ready: SignalTyped.Signal<Folder> = SignalTyped.new()
-- An authored site standing in for the generated office (useSite; the Training map); nil: the office.
local site: OfficeTypes.Site? = nil

local floorAt = OfficeSiteUtils.floorAt

-- Harlow's route in the world, in walking order, and his rest point (M2).
local routePoints: { Vector3 } = {}
for _, id in LAYOUT.route do
	local marker = markerById[id]
	if marker ~= nil then
		table.insert(routePoints, floorAt(marker).Position)
	end
end
local restMarker = markerById[LAYOUT.rest]

local function rebuild(requested: number, map: ShiftTypes.MapId)
	local layout, seed = OfficeRebuildSystem.generateLayout(requested, map)
	OfficeBuildPaceTracker.step()
	OfficeRebuildSystem.checkGenerated(layout)
	OfficeBuildPaceTracker.step()
	LAYOUT = layout
	depths = OfficeLayoutUtils.depths(layout)
	table.clear(markerById)
	for _, marker in layout.markers do
		markerById[marker.id] = marker
	end
	table.clear(routePoints)
	for _, id in layout.route do
		local marker = markerById[id]
		if marker ~= nil then
			table.insert(routePoints, floorAt(marker).Position)
		end
	end
	restMarker = markerById[layout.rest]
	local old = built
	if old ~= nil then
		-- Gone before the (yielding) build starts: nothing reads a destroyed office while the new one goes up.
		built = nil
		old.doors.destroy()
		OfficeRebuildSystem.teardown(old.model)
	end
	-- Guard: any other office model in Workspace (one a past cleanup missed) goes too, with a warning as evidence.
	OfficeBuildSystem.clearStrays()
	local current = OfficeBuildSystem.build(layout, OfficeConstants.ORIGIN, nil, seed, map)
	current.model:SetAttribute("LayoutSeed", seed)
	current.model:SetAttribute(OfficeConstants.MAP_ATTRIBUTE, map)
	forcedAnomalies = nil
	current.model:SetAttribute(
		OfficeAnomalyConstants.PUBLISHED_ATTRIBUTE,
		table.concat(OfficeVariationRules.anomalies(seed), ",")
	)
	built = current
	layoutSeed = seed
	layoutMap = map
	OfficeBuildPaceTracker.step()
	OfficeDecorSystem.build(layout, OfficeConstants.ORIGIN, current.model, nil, seed)
end

export type OfficeServiceServer = {
	dependencies: { string },
	ready: SignalTyped.Signal<Folder>,
	isReady: (self: OfficeServiceServer) -> boolean,
	seed: (self: OfficeServiceServer) -> number?,
	map: (self: OfficeServiceServer) -> ShiftTypes.MapId,
	anomalies: (self: OfficeServiceServer) -> { OfficeAnomalyConstants.AnomalyId },
	forceAnomalies: (self: OfficeServiceServer, ids: { OfficeAnomalyConstants.AnomalyId }?) -> boolean,
	start: (self: OfficeServiceServer) -> (),
	stop: (self: OfficeServiceServer) -> (),
	getState: (self: OfficeServiceServer) -> { [string]: any },
	beginShift: (
		self: OfficeServiceServer,
		options: { seed: number, variant: string, quota: number, map: ShiftTypes.MapId }
	) -> OfficeTypes.SpawnPlan,
	spawnOvertimeLoot: (self: OfficeServiceServer) -> number,
	reset: (self: OfficeServiceServer) -> (),
	spawnCFrame: (self: OfficeServiceServer, index: number) -> CFrame,
	container: (self: OfficeServiceServer) -> Folder?,
	route: (self: OfficeServiceServer) -> { Vector3 },
	restPoint: (self: OfficeServiceServer) -> Vector3,
	safeZone: (self: OfficeServiceServer) -> (Vector3, Vector3),
	loadingBay: (self: OfficeServiceServer) -> (Vector3, Vector3),
	whereIs: (self: OfficeServiceServer, position: Vector3) -> (string?, number?, number?),
	outdoors: (self: OfficeServiceServer) -> { { min: Vector3, max: Vector3 } },
	entrance: (self: OfficeServiceServer, id: OfficeTypes.EntranceId) -> (CFrame?, CFrame?),
	truckBed: (self: OfficeServiceServer) -> BasePart?,
	overtimeSheet: (self: OfficeServiceServer) -> BasePart?,
	openDoorsNear: (self: OfficeServiceServer, position: Vector3, heading: Vector3?) -> boolean,
	useSite: (self: OfficeServiceServer, next: OfficeTypes.Site?) -> (),
}

local OfficeServiceServer: OfficeServiceServer = {
	dependencies = {
		"VacuumServiceServer",
		"CargoServiceServer",
		"QueueServiceServer",
		"InteractionServiceServer",
		"NoiseServiceServer",
	},
	ready = ready,

	--[=[
		Validates and builds the office, and reveals hidden items as their piles are cleared.
	]=]
	start = function(_self)
		if not QueueServiceServer:runsRole(DepotConstants.ROLE_SHIFT) then
			log:info("not a shift server: the office is not built")
			return
		end
		local ok, errors = OfficeLayoutRules.validate(LAYOUT)
		assert(ok, `office layout is invalid:\n{table.concat(errors, "\n")}`)
		local capacityOk, reason = OfficeLayoutRules.checkCapacity(LAYOUT)
		assert(capacityOk, `office layout cannot hold a shift: {reason or "?"}`)
		local routeOk, routeReason = OfficeLayoutRules.checkRoute(LAYOUT)
		assert(routeOk, `office layout has no usable patrol route: {routeReason or "?"}`)
		-- The door and locked-facade prompts; a facade leaf rattles on interact.
		OfficeDoorSystem.listen()
		InteractionServiceServer:onInteract(OfficeConstants.DOOR_KIND, function(player, target)
			local current = built
			local id = target:GetAttribute("OfficeDoorId")
			if current == nil or type(id) ~= "string" or not target:IsA("BasePart") then
				return
			end
			local closing = target:GetAttribute("OfficeDoorOpen") == true
			if current.doors.toggle(id, player) and closing then
				for _, state in current.doors.states() do
					if state.id == id then
						NoiseServiceServer:emit(
							state.position,
							OfficeConstants.DOOR_SLAM_RADIUS,
							"door",
							{ player.UserId }
						)
					end
				end
			end
		end)
		OfficeBuildSystem.clearStrays()
		OfficeBuildPaceTracker.shared:begin()
		local current = OfficeBuildSystem.build(LAYOUT, OfficeConstants.ORIGIN)
		current.model:SetAttribute(OfficeConstants.MAP_ATTRIBUTE, layoutMap)
		built = current
		-- The office at night (exit signs, blue monitors, the elevator, ambience emitters), once.
		OfficeDecorSystem.build(LAYOUT, OfficeConstants.ORIGIN, current.model)
		OfficeShiftSpawnSystem.watch(hidden, dressing, stoppers)
	end,

	stop = function(self)
		for _, stop in stoppers do
			stop()
		end
		table.clear(stoppers)
		self:reset()
		local current = built
		if current ~= nil then
			current.doors.destroy()
			current.model:Destroy()
			built = nil
		end
	end,

	--[=[
		Resets, then rolls and places one shift's spawns. Returns the plan placed.
	]=]
	beginShift = function(self, options)
		self:reset()
		local authored = site
		if authored ~= nil then
			local folder = Instance.new("Folder")
			folder.Name = OfficeConstants.SHIFT_FOLDER_NAME
			folder.Parent = authored.model
			shiftJanitor:Add(folder, "Destroy")
			shiftFolder = folder
			CargoServiceServer:useContainer(folder)
			local placed = authored.spawn(folder)
			lastPlan = placed
			-- A site has no overtime batch.
			overtimeSpawned = true
			log:info(`site spawns: {#placed.piles} piles, {#placed.items} items`)
			ready:Fire(folder)
			return placed
		end
		assert(built ~= nil, "OfficeServiceServer:beginShift before start")
		-- The build yields a frame between pieces (OfficeBuildPaceTracker), so a rebuild never holds the server.
		while rebuilding do
			task.wait()
		end
		rebuilding = true
		OfficeBuildPaceTracker.shared:begin()
		local rebuilt, failure = pcall(rebuild, options.seed, options.map)
		rebuilding = false
		if not rebuilt then
			error(failure, 0)
		end
		local current = built
		assert(current ~= nil, "OfficeServiceServer:beginShift before start")
		local plan = OfficeShiftSpawnSystem.roll(LAYOUT, options)
		local folder = Instance.new("Folder")
		folder.Name = OfficeConstants.SHIFT_FOLDER_NAME
		folder.Parent = current.model
		shiftJanitor:Add(folder, "Destroy")
		shiftFolder = folder
		CargoServiceServer:useContainer(folder)

		OfficeShiftSpawnSystem.place(plan, current, folder, markerById, hidden)
		lastPlan = plan
		current.doors.openAtStart(layoutSeed)
		OfficeDressingSystem.build(LAYOUT, plan, layoutSeed, OfficeConstants.ORIGIN, current.model)
		OfficeOozeSystem.buildAtDock(LAYOUT, OfficeConstants.ORIGIN, OfficeLootUtils.gloomOf(plan).total, current.model)
		overtimeSpawned = false
		log:info(`shift spawns: {#plan.piles} piles, {#plan.items} items, worth {plan.value} clean`)
		ready:Fire(folder)
		return plan
	end,

	--[=[
		Spawns the shift's overtime batch (once per shift; Shift calls it when the stage turns to "overtime", since
		Shift already depends on Office): OfficeSpawnUtils.rollOvertime on the spots the first roll left free, each
		item placed through Cargo with `overtime = true`, so only it pays the overtime multiplier. Returns how many
		spawned (0 when a batch already spawned, no shift stands, or no spot is free).
	]=]
	spawnOvertimeLoot = function(_self)
		local plan = lastPlan
		local folder = shiftFolder
		if overtimeSpawned or plan == nil or folder == nil then
			return 0
		end
		overtimeSpawned = true
		local batch = OfficeSpawnUtils.rollOvertime(LAYOUT, plan, Random.new())
		local spawned = OfficeShiftSpawnSystem.placeOvertime(batch, built, folder, markerById)
		log:info(`overtime loot: {spawned} items`)
		return spawned
	end,

	--[=[
		Whether a shift's office is built and spawned (after `beginShift`, until `reset`).
	]=]
	isReady = function(_self)
		return shiftFolder ~= nil
	end,

	--[=[
		The seed of the layout standing now, or nil for the layout built at start.
	]=]
	seed = function(_self)
		return layoutSeed
	end,

	-- The map standing now ("office" at boot and on an authored site's run).
	map = function(_self)
		return layoutMap
	end,

	--[=[
		The exterior anomalies this run shows: a developer's forced set, else the seed's pick (none for the boot layout).
	]=]
	anomalies = function(_self)
		return forcedAnomalies or OfficeVariationRules.anomalies(layoutSeed)
	end,

	--[=[
		Developer override (the anomaly command): publishes exactly `ids`, or the seed's pick again for nil. False when
		no office stands. The next rebuild drops it.
	]=]
	forceAnomalies = function(self, ids)
		local current = built
		if current == nil then
			return false
		end
		forcedAnomalies = ids
		current.model:SetAttribute(OfficeAnomalyConstants.PUBLISHED_ATTRIBUTE, table.concat(self:anomalies(), ","))
		return true
	end,

	--[=[
		Destroys everything the current shift spawned (the one folder) and forgets it. The caller (Shift) resets
		Cargo and Vacuum alongside it.
	]=]
	reset = function(_self)
		shiftJanitor:Cleanup()
		CargoServiceServer:useContainer(nil)
		shiftFolder = nil
		table.clear(hidden)
		lastPlan = nil
		overtimeSpawned = false
		dressing.clear()
	end,

	--[=[
		Where the `index`-th crew member appears: in the truck's bed, facing out of its open back and down the ramp
		(OfficeLoadingBayUtils.arrivalFrame). Shift arrivals, the shift start and crew respawns all land here.
	]=]
	spawnCFrame = function(_self, index)
		return OfficeSiteUtils.spawnCFrame(site, LAYOUT, index)
	end,

	container = function(_self)
		return shiftFolder
	end,

	--[=[
		Harlow's patrol points in the world, in walking order (a loop).
	]=]
	route = function(_self)
		return OfficeSiteUtils.route(site, routePoints)
	end,

	--[=[
		Where Harlow takes his break (the break room).
	]=]
	restPoint = function(_self)
		return OfficeSiteUtils.restPoint(site, restMarker)
	end,

	--[=[
		The inside of the truck's box in the world, min and max corners: the one place Harlow never sees, hears, catches
		or walks into.
	]=]
	safeZone = function(_self)
		return OfficeSiteUtils.safeZone(site, LAYOUT)
	end,

	--[=[
		The loading bay in the world: its min and max corners, floor to wall top. Harlow may walk it, but never lingers.
	]=]
	loadingBay = function(_self)
		return OfficeSiteUtils.loadingBay(site, LAYOUT)
	end,

	--[=[
		The room a world position stands in: its name, how many rooms from the loading bay, and its camera number (its
		index in the layout). On a ground outside (the yard, the car park): its name, depth 0 and no camera. Nothing
		elsewhere.
	]=]
	whereIs = function(_self, position)
		return OfficeSiteUtils.whereIs(site, LAYOUT, depths, position)
	end,

	--[=[
		The outside's grounds in the world, min and max corners, floor to OUTSIDE.VOLUME_HEIGHT (the Outdoors safe
		volumes). Empty when the layout has no grounds (the boot layout).
	]=]
	outdoors = function(_self)
		return OfficeSiteUtils.outdoors(site, LAYOUT)
	end,

	--[=[
		Where entrance `id` sets a player down, in the world: outside (OfficeGroundsUtils.outsideFrame) and inside, in
		its exit's room (insideFrame). Nil, nil when the layout has no such entrance (or its exit's room is missing).
	]=]
	entrance = function(_self, id)
		return OfficeSiteUtils.entrance(site, LAYOUT, id)
	end,

	--[=[
		The truck bed in the loading bay (Cargo's Load zone), once the office is built.
	]=]
	truckBed = function(_self)
		local authored = site
		if authored ~= nil then
			return authored.truckBed()
		end
		local current = built
		return if current ~= nil then current.bed else nil
	end,

	--[=[
		The overtime sheet beside the time clock (Shift's Start overtime prompt), once the office is built.
	]=]
	overtimeSheet = function(_self)
		if site ~= nil then
			return nil
		end
		local current = built
		return if current ~= nil then current.overtime else nil
	end,

	--[=[
		Opens the closed doors Harlow is walking through (his think calls this): on his line of travel from `position`
		along `heading` (OfficeDoorUtils.reach with OfficeConstants.DOOR_REACH; nil: he stands still and none opens),
		plus any closed door within DOOR_CLOSE_REACH whatever the heading. True when it opened one on his line; false
		otherwise or when no office stands.
	]=]
	openDoorsNear = function(_self, position, heading)
		if site ~= nil then
			return false
		end
		local current = built
		return if current ~= nil then current.doors.openNear(position, heading) else false
	end,

	--[=[
		Puts an authored site (OfficeTypes.Site) in the generated office's place for the next `beginShift`, or the office
		back for nil. Every accessor (spawns, route, rest point, safe zone, loading bay, rooms, truck bed) then answers
		from the site; grounds, entrances, doors and overtime are absent. Takes effect from the next run: set it before
		the run's `beginShift`, and clear it once the run is over.
	]=]
	useSite = function(_self, next)
		site = next
		log:info(if next ~= nil then `using the site {next.model.Name}` else "back to the office")
	end,

	getState = function(_self)
		local plan = lastPlan
		local hiddenCount = 0
		for _ in hidden do
			hiddenCount += 1
		end
		return {
			built = built ~= nil,
			shift = shiftFolder ~= nil,
			piles = if plan ~= nil then #plan.piles else 0,
			items = if plan ~= nil then #plan.items else 0,
			value = if plan ~= nil then plan.value else 0,
			greed = if plan ~= nil and plan.greed ~= nil then `{plan.greed.kind} @ {plan.greed.marker}` else nil,
			hiddenUnderPiles = hiddenCount,
			routePoints = #routePoints,
			map = layoutMap,
			site = if site ~= nil then site.model.Name else nil,
		}
	end,
}

return OfficeServiceServer
