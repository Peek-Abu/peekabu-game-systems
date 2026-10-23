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

	Doors: it registers the door prompt (OfficeConstants.DOOR_KIND, "Open / close"), toggles the door on interact
	(a player's accepted close slams: a "door" noise, DOOR_SLAM_RADIUS; a close with Harlow about is refused), and
	`openDoorsNear` lets Harlow open the closed doors he is walking through (within DOOR_REACH, ahead of his heading;
	true when it opened one, false when no office stands). Facade leaves are locked set dressing: their prompt
	(OfficeConstants.FACADE_KIND, "Locked") only rattles the leaf.

	Ordering guarantee for anything that spawns into a shift (Occupant's Manager): `ready` fires (deferred, with the shift
	folder) once `beginShift` has rebuilt the office and placed every spawn, and `isReady` says whether that shift is
	still standing (false after `reset`). Shift's transit calls `beginShift` before Shift enters `running`, so by the
	time ShiftServiceServer.changed reports `running` the office, its route and `container()` are already the new
	shift's. `seed` is the rebuilt layout's seed (the model's LayoutSeed attribute), which the transit hands clients.
	When generation from the shift's seed errors, the rebuild warns and tries the next seed up (GENERATE_RETRIES more
	times) before raising, so `seed` is the seed actually used.

	The office is built only where the shift role runs (QueueServiceServer:runsRole); a hub-only server builds nothing.

	Stray guard: `rebuild` and the first build at `start` destroy every Workspace child named
	OfficeConstants.MODEL_NAME that is not the tracked model (OfficeBuildSystem.clearStrays) and warn "removed N stray
	office model(s)" when there were any: a transit whose reset errored (it runs guarded) must never leave an old office,
	with its door leaves, standing beside the new one. `stop` still destroys the tracked model.

	Spec-exempt shell (Instances, signals); the decisions are the specced OfficeLayoutRules, OfficeLayoutUtils,
	OfficeSpawnUtils and OfficeSpawnRules.

	@class OfficeServiceServer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OfficeServer = ServerScriptService.Features.Office
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local CargoTypes = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoTypes)
local CargoAppraisalFormulas = require(ReplicatedStorage.Shared.Features.Cargo.Utils.CargoAppraisalFormulas)
local Logger = require(ReplicatedStorage.Shared.Core.Logger)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeLayoutConstants = require(OfficeServer.Data.OfficeLayoutConstants)
local OfficeTypes = require(OfficeServer.Data.OfficeTypes)
local OfficeLayoutRules = require(OfficeServer.Rules.OfficeLayoutRules)
local OfficeSpawnRules = require(OfficeServer.Rules.OfficeSpawnRules)
local OfficeLayoutUtils = require(OfficeServer.Utils.OfficeLayoutUtils)
local OfficeLayoutGenerationUtils = require(OfficeServer.Utils.OfficeLayoutGenerationUtils)
local OfficeLoadingBayUtils = require(OfficeServer.Utils.OfficeLoadingBayUtils)
local OfficeFurniturePlacementUtils = require(OfficeServer.Utils.OfficeFurniturePlacementUtils)
local OfficeSurfaceUtils = require(OfficeServer.Utils.OfficeSurfaceUtils)
local OfficeSpawnUtils = require(OfficeServer.Utils.OfficeSpawnUtils)
local OfficeBuildSystem = require(OfficeServer.Systems.OfficeBuildSystem)
local OfficeDecorSystem = require(OfficeServer.Systems.OfficeDecorSystem)
local OfficeSearchedDressingSystem = require(OfficeServer.Systems.OfficeSearchedDressingSystem)
local CargoServiceServer = require(ServerScriptService.Features.Cargo.CargoServiceServer)
local VacuumServiceServer = require(ServerScriptService.Features.Vacuum.VacuumServiceServer)
local QueueServiceServer = require(ServerScriptService.Features.Queue.QueueServiceServer)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local InteractionRegistry = require(ReplicatedStorage.Shared.Features.Interaction.Data.InteractionRegistry)
local InteractionServiceServer = require(ServerScriptService.Features.Interaction.InteractionServiceServer)
local NoiseServiceServer = require(ServerScriptService.Features.Noise.NoiseServiceServer)

type Marker = OfficeTypes.Marker

local log = Logger.new("OfficeServiceServer")

-- Desks and break tables grew (HIDE_FURNITURE_SCALE): any that no longer fit where it stands is removed.
local function fitted(layout: OfficeTypes.Layout): OfficeTypes.Layout
	local kept, dropped = OfficeLayoutUtils.dropUnfit(layout, OfficeLayoutRules)
	if dropped > 0 then
		log:info(`dropped {dropped} desk(s) and table(s) that no longer fit`)
	end
	return kept
end

local LAYOUT = fitted(OfficeFurniturePlacementUtils.normalize(OfficeLayoutConstants.LAYOUT))
local depths = OfficeLayoutUtils.depths(LAYOUT)

local markerById: { [string]: Marker } = {}
for _, marker in LAYOUT.markers do
	markerById[marker.id] = marker
end

local built: OfficeBuildSystem.Built? = nil
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
-- Fired (with the shift folder) once a shift's office is rebuilt and every spawn placed.
local ready: SignalTyped.Signal<Folder> = SignalTyped.new()

-- The floor point under a marker, in the world.
local function floorAt(marker: Marker): CFrame
	return OfficeConstants.ORIGIN * CFrame.new(marker.x, 0, marker.z)
end

-- Where an item stands: furniture tops for surface markers, the floor otherwise.
local function spotFrame(marker: Marker): CFrame
	local top = OfficeLayoutUtils.surfaceTopFor(marker)
	if top ~= nil then
		local current = built
		if current ~= nil then
			for _, part in current.model:GetDescendants() do
				if
					part:IsA("BasePart")
					and (
						part:GetAttribute("OfficeMarkerId") == marker.id
						or part:GetAttribute("OfficeDeskMarker") == marker.id
					)
				then
					local onArt = OfficeSurfaceUtils.surfaceOnPart(
						part.CFrame,
						part.Size,
						part:GetAttribute("ArtSupportSurfaceY")
					)
					if onArt ~= nil then
						return onArt
					end
				end
			end
		end
		return OfficeConstants.ORIGIN * CFrame.new(marker.x, top, marker.z)
	end
	return floorAt(marker)
end

-- Harlow's route in the world, in walking order, and his rest point (M2).
local routePoints: { Vector3 } = {}
for _, id in LAYOUT.route do
	local marker = markerById[id]
	if marker ~= nil then
		table.insert(routePoints, floorAt(marker).Position)
	end
end
local restMarker = markerById[LAYOUT.rest]

-- Seeds tried after the shift's own when generation fails (each the next seed up), before the error is raised.
local GENERATE_RETRIES = 3

-- The layout generated from `seed`, or, when generation errors (every attempt invalid), from the next seed up, up to
-- GENERATE_RETRIES more times, so a shift still starts; then the last error is raised. Returns the seed used.
local function generateLayout(seed: number): (OfficeTypes.Layout, number)
	local lastError = ""
	for retry = 0, GENERATE_RETRIES do
		local tried = seed + retry
		local ok, result = pcall(OfficeLayoutGenerationUtils.generate, OfficeLayoutConstants.LAYOUT, tried)
		if ok then
			return result, tried
		end
		lastError = tostring(result)
		log:warn(`office generation from seed {tried} failed: {lastError}`)
	end
	error(`office generation failed from seed {seed} to {seed + GENERATE_RETRIES}: {lastError}`, 0)
end

-- Destroys every office model in Workspace except the tracked one, warning with the count (it should never find one).
local function clearStrays()
	local current = built
	local removed = OfficeBuildSystem.clearStrays(if current ~= nil then current.model else nil)
	if removed > 0 then
		log:warn(`removed {removed} stray office model(s)`)
	end
end

local function rebuild(requested: number)
	local layout, seed = generateLayout(requested)
	local ok, errors = OfficeLayoutRules.validate(layout)
	assert(ok, `generated office layout is invalid: {table.concat(errors, "; ")}`)
	local capacity, reason = OfficeLayoutRules.checkCapacity(layout)
	assert(capacity, reason or "generated layout capacity")
	local routeOk, routeReason = OfficeLayoutRules.checkRoute(layout)
	assert(routeOk, routeReason or "generated layout route")
	local hideOk, hideReason = OfficeLayoutRules.checkHideSpots(layout)
	assert(hideOk, hideReason or "generated layout hide spots")
	local walkOk, walkReason =
		OfficeLayoutRules.checkWalk(layout, OfficeConstants.WALK_SPEED * OfficeConstants.MAX_WALK_SECONDS)
	assert(walkOk, walkReason or "generated layout walk")
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
		old.doors.destroy()
		old.model:Destroy()
	end
	-- Guard: any other office model in Workspace (one a past cleanup missed) goes too, with a warning as evidence.
	clearStrays()
	local current = OfficeBuildSystem.build(layout, OfficeConstants.ORIGIN)
	current.model:SetAttribute("LayoutSeed", seed)
	built = current
	layoutSeed = seed
	OfficeDecorSystem.build(layout, OfficeConstants.ORIGIN, current.model)
end

-- A rolled valuable as it spawns (fully grimy, unappraised); nil for trash.
local function fresh(roll: CargoTypes.AppraisalRoll?): CargoTypes.Appraisal?
	return if roll ~= nil then CargoAppraisalFormulas.fresh(roll) else nil
end

local function rollPlan(options: { seed: number, variant: string, quota: number }): OfficeTypes.SpawnPlan
	local rollOptions: OfficeTypes.RollOptions = {
		quota = options.quota,
		variant = options.variant,
		dirtyRooms = OfficeConstants.DIRTY_ROOMS,
		pilesPerRoom = OfficeConstants.PILES_PER_ROOM,
		valuables = OfficeConstants.VALUABLES,
	}
	local plan: OfficeTypes.SpawnPlan
	for attempt = 0, OfficeConstants.ROLL_ATTEMPTS - 1 do
		local seed = options.seed + attempt
		plan = OfficeSpawnUtils.roll(LAYOUT, rollOptions, Random.new(seed))
		local ok, reason = OfficeSpawnRules.check(plan, LAYOUT, options.quota)
		if ok then
			return plan
		end
		log:warn(`spawn roll {seed} missed a guarantee: {reason or "?"}`)
	end
	log:warn(`no spawn roll from seed {options.seed} met the guarantees; using the last one`)
	return plan
end

export type OfficeServiceServer = {
	dependencies: { string },
	ready: SignalTyped.Signal<Folder>,
	isReady: (self: OfficeServiceServer) -> boolean,
	seed: (self: OfficeServiceServer) -> number?,
	start: (self: OfficeServiceServer) -> (),
	stop: (self: OfficeServiceServer) -> (),
	getState: (self: OfficeServiceServer) -> { [string]: any },
	beginShift: (
		self: OfficeServiceServer,
		options: { seed: number, variant: string, quota: number }
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
	truckBed: (self: OfficeServiceServer) -> BasePart?,
	overtimeSheet: (self: OfficeServiceServer) -> BasePart?,
	openDoorsNear: (self: OfficeServiceServer, position: Vector3, heading: Vector3?) -> boolean,
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
		if not InteractionRegistry.has(OfficeConstants.DOOR_KIND) then
			InteractionRegistry.register(OfficeConstants.DOOR_KIND, {
				actionText = "Open / close",
				objectText = "Door",
				maxDistance = 8,
			})
		end
		if not InteractionRegistry.has(OfficeConstants.FACADE_KIND) then
			InteractionRegistry.register(OfficeConstants.FACADE_KIND, {
				actionText = "Locked",
				objectText = "Door",
				maxDistance = 8,
			})
		end
		InteractionServiceServer:onInteract(OfficeConstants.FACADE_KIND, function(_player, target)
			local current = built
			if current ~= nil and target:IsA("BasePart") then
				current.doors.rattle(target)
			end
		end)
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
		clearStrays()
		local current = OfficeBuildSystem.build(LAYOUT, OfficeConstants.ORIGIN)
		built = current
		-- The office at night (exit signs, blue monitors, the elevator, ambience emitters), once.
		OfficeDecorSystem.build(LAYOUT, OfficeConstants.ORIGIN, current.model)
		local cleared = VacuumServiceServer.pileCleared:Connect(function(pile)
			local item: BasePart? = hidden[pile]
			hidden[pile] = nil
			if item ~= nil and item.Parent ~= nil then
				CargoServiceServer:reveal(item)
			end
		end)
		table.insert(stoppers, function()
			cleared:Disconnect()
		end)
		-- Searched desks and lockers stay visibly open until the shift ends.
		local dressed = CargoServiceServer.searched:Connect(function(part)
			if part.Name == "Desk" then
				dressing.apply(part, "desk")
			elseif part.Name == "Locker" then
				dressing.apply(part, "locker")
			end
		end)
		table.insert(stoppers, function()
			dressed:Disconnect()
		end)
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
		assert(built ~= nil, "OfficeServiceServer:beginShift before start")
		rebuild(options.seed)
		local current = built
		assert(current ~= nil, "OfficeServiceServer:beginShift before start")
		local plan = rollPlan(options)
		local folder = Instance.new("Folder")
		folder.Name = OfficeConstants.SHIFT_FOLDER_NAME
		folder.Parent = current.model
		shiftJanitor:Add(folder, "Destroy")
		shiftFolder = folder
		CargoServiceServer:useContainer(folder)

		for _, pilePlan in plan.piles do
			local marker = markerById[pilePlan.marker]
			if marker ~= nil then
				local floor = floorAt(marker)
				local pile = VacuumServiceServer:spawnPile(pilePlan.kind, floor, folder)
				local hides = pilePlan.hides
				if hides ~= nil then
					hidden[pile] = CargoServiceServer:spawnItem(
						hides,
						floor,
						folder,
						{ hidden = true, appraisal = fresh(pilePlan.appraisal) }
					)
					pile:SetAttribute(CargoConstants.BURIED_ATTRIBUTE, true)
				end
			end
		end
		for _, itemPlan in plan.items do
			local marker = markerById[itemPlan.marker]
			if marker ~= nil then
				CargoServiceServer:spawnItem(
					itemPlan.kind,
					spotFrame(marker),
					folder,
					{ appraisal = fresh(itemPlan.appraisal) }
				)
			end
		end
		for _, search in plan.searchables do
			local part: BasePart? = current.searchables[search.marker]
			if part ~= nil then
				CargoServiceServer:stockSearchable(part, search.kind, fresh(search.appraisal))
			end
		end
		lastPlan = plan
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
		local spawned = 0
		for _, itemPlan in batch do
			local marker = markerById[itemPlan.marker]
			if marker ~= nil then
				CargoServiceServer:spawnItem(
					itemPlan.kind,
					spotFrame(marker),
					folder,
					{ appraisal = fresh(itemPlan.appraisal), overtime = true }
				)
				spawned += 1
			end
		end
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
		return OfficeConstants.ORIGIN * OfficeLoadingBayUtils.arrivalFrame(LAYOUT.truck, index)
	end,

	container = function(_self)
		return shiftFolder
	end,

	--[=[
		Harlow's patrol points in the world, in walking order (a loop).
	]=]
	route = function(_self)
		return table.clone(routePoints)
	end,

	--[=[
		Where Harlow takes his break (the break room).
	]=]
	restPoint = function(_self)
		if restMarker == nil then
			error("OfficeServiceServer:restPoint: the layout has no rest marker")
		end
		return floorAt(restMarker).Position
	end,

	--[=[
		The inside of the truck's box in the world, min and max corners: the one place Harlow never sees, hears, catches
		or walks into.
	]=]
	safeZone = function(_self)
		local min, max = OfficeLoadingBayUtils.truckBox(LAYOUT.truck)
		local low = OfficeConstants.ORIGIN:PointToWorldSpace(min)
		local high = OfficeConstants.ORIGIN:PointToWorldSpace(max)
		return low:Min(high), low:Max(high)
	end,

	--[=[
		The loading bay in the world: its min and max corners, floor to wall top. Harlow may walk it, but never lingers.
	]=]
	loadingBay = function(_self)
		local start = OfficeLayoutUtils.room(LAYOUT, LAYOUT.startRoom)
		if start == nil then
			error("OfficeServiceServer:loadingBay: the layout has no start room")
		end
		local min, max = OfficeLayoutUtils.bounds(start, OfficeConstants.WALL_HEIGHT)
		return OfficeConstants.ORIGIN:PointToWorldSpace(min), OfficeConstants.ORIGIN:PointToWorldSpace(max)
	end,

	--[=[
		The room a world position stands in: its name, how many rooms from the loading bay, and its camera number (its
		index in the layout). Nothing outside the office.
	]=]
	whereIs = function(_self, position)
		local localPoint = OfficeConstants.ORIGIN:PointToObjectSpace(position)
		local room, index = OfficeLayoutUtils.roomAt(LAYOUT, localPoint.X, localPoint.Z)
		if room == nil then
			return nil, nil, nil
		end
		return room.name, depths[room.id], index
	end,

	--[=[
		The truck bed in the loading bay (Cargo's Load zone), once the office is built.
	]=]
	truckBed = function(_self)
		local current = built
		return if current ~= nil then current.bed else nil
	end,

	--[=[
		The overtime sheet beside the time clock (Shift's Start overtime prompt), once the office is built.
	]=]
	overtimeSheet = function(_self)
		local current = built
		return if current ~= nil then current.overtime else nil
	end,

	--[=[
		Opens every closed door within OfficeConstants.DOOR_REACH of `position` and ahead of `heading` (nil: any door
		counts): the doors Harlow is walking through (his think calls this). True when it opened one; false when none did
		or no office stands.
	]=]
	openDoorsNear = function(_self, position, heading)
		local current = built
		return if current ~= nil then current.doors.openNear(position, heading) else false
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
		}
	end,
}

return OfficeServiceServer
