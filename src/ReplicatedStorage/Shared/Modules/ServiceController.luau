--!strict
--[=[
	ServiceController: Manages service lifecycle with init -> start -> stop phases.

	Lifecycle Phases:
	- init(): Called first on all services. Services should NOT call methods on other
	         services here. Use this for internal setup, event listeners, etc.
	- start(): Called after ALL services are initialized. Safe to call methods on
	           other services. Optional - only implement if needed.
	- stop(): Called during shutdown/cleanup. Use for disconnecting events, saving
	          state, releasing resources. Optional - only implement if needed.

	Restart is symmetric: stopService/stopAll reset each torn-down service to its un-initialized
	state, so restarting means calling initAll() then startAll() again (or initService/startService
	for a single service) — init() re-runs and re-establishes whatever stop() released. Consequence:
	anything a service acquires in init() MUST be released in a stop(), even a service with no other
	teardown, or it leaks across a restart (init would run twice and double it).

	Service Access Rules:
	- Services may `require()` other services directly for intellisense/autocomplete.
	- However, services must NOT call methods on other services during `init()`.
	- Cross-service method calls are only safe in `start()` and beyond.

	IMPORTANT - Why direct require() is intentional:
	Services use direct `require()` at module load time for type inference and
	autocomplete. This is NOT a dependency injection anti-pattern because:
	1. The `dependencies` array declares explicit init/start ordering
	2. Luau `require()` is cached - modules load once regardless of require count
	3. The topological sort guarantees dependencies are ready before `start()`
	4. Services only call methods on other services AFTER init phase completes

	This pattern provides full intellisense while maintaining proper lifecycle order.
	Do NOT refactor to ServiceController:getService() - it would lose type safety.

	Standard service module shape (the "lean annotated-literal" pattern):
	ALL services in this codebase MUST follow this shape so they type-check end to end
	under `--!strict` with no casts and types declared exactly once:

	1. Declare an explicit `export type MyService = { ... }` interface listing every
	   field and method (NOT `typeof(MyService)` — `typeof` widens method params at
	   generic boundaries, e.g. a literal union passed into a ByteNet `string` field,
	   which breaks every `require()` consumer).
	2. Build the module as ONE annotated table literal: `local MyService: MyService = {}`.
	   Annotating the literal makes Luau push each signature from the interface DOWN into
	   the matching method body, so method bodies need NO inline type annotations.
	3. Methods are fields: `methodName = function(self, arg) ... end`. (This replaces the
	   old `function MyService:methodName()` / `function MyService.lifecycle()` split —
	   colon method *statements* do not receive their param types from the interface, so
	   they reintroduce the widening above and would need redundant annotations.)

	`self` vs `_self` in methods:
	- Use `self` when the method reads or writes ANY field on the service table.
	- Use `_self` when the method does NOT use the service table at all (linter-safe
	  unused-param signal). Both receive the same value at runtime.

	When to use start() vs init():
	- Use init() for internal setup: event listeners, local state, config parsing
	- Use start() when you need to call methods on OTHER services at startup

	Example - a minimal service following the standard shape:
	```lua
	export type QuestService = {
		dependencies: { string },
		init: (self: QuestService) -> (),
		start: (self: QuestService) -> (),
		getActive: (self: QuestService, userId: number) -> { string },
	}

	local QuestService: QuestService = {
		dependencies = { "PlayerDataServiceServer", "CurrencyServiceServer" },

		init = function(self)
			-- Internal setup only - do NOT call other services here. No param types needed.
			janitor:Add(Players.PlayerAdded:Connect(function(player)
				self:onPlayerAdded(player)
			end))
		end,

		start = function(_self)
			-- Safe to call other services here - all are initialized.
			local CurrencyService = require(path.to.CurrencyServiceServer)
			for _, player in Players:GetPlayers() do
				if CurrencyService:getCurrencyAmount(player.UserId, "gold") == 0 then
					CurrencyService:addCurrency(player.UserId, "gold", 100)
				end
			end
		end,

		getActive = function(_self, _userId)
			return {}
		end,
	}

	return QuestService
	```

	@class ServiceController
]=]

--[=[
	Service module interface.

	NOTE: All lifecycle methods are intentionally optional.
	Services only implement what they need. Empty stubs are an anti-pattern.
	The controller gracefully handles missing methods.
]=]
export type ServiceModule = {
	init: ((self: any, ...any) -> ())?,
	start: ((self: any) -> ())?,
	stop: ((self: any) -> ())?,
	getState: ((self: any) -> { [string]: any })?,
	dependencies: { string }?,
}

export type ServiceEntry = {
	name: string,
	module: ServiceModule,
	initialized: boolean,
	-- `started` means start was ATTEMPTED (used for scheduling/stop eligibility); it is set before
	-- start() runs so siblings in the same pass aren't double-started. `startSucceeded` means start()
	-- actually completed without error — this is what isStarted() reports, so a service whose start()
	-- threw reads as not-started even though startError is populated.
	started: boolean,
	startSucceeded: boolean?,
	dependencies: { string },
	-- Boot introspection, populated as the service moves through its lifecycle. All optional: they are
	-- nil until the matching phase runs, and the *Error fields stay nil on success. The debugger's
	-- Services health board reads these; nothing in the framework depends on them.
	initDurationMs: number?,
	startDurationMs: number?,
	initError: string?,
	startError: string?,
}

export type Phase = "registering" | "initializing" | "starting" | "running" | "stopping"

--[=[
	Public interface of the controller singleton.

	Declaring this explicitly (rather than letting Luau infer `self` per method) gives
	every method ONE shared, consistent `self` type. Without it, each method infers its
	own structural `self` from the fields it touches; those inferred selves conflict, and
	chained calls (`:register()` then `:initAll()`) fail with "Expected ServiceController
	to be exactly ServiceController". Annotating the literal below also lets us drop the
	per-field `::` casts, and lets each method body omit inline type annotations.
]=]
export type ServiceController = {
	_services: { [string]: ServiceEntry },
	_initOrder: { string },
	_sortedOrder: { { string } }?,
	_phase: Phase,

	getPhase: (self: ServiceController) -> Phase,
	assertSafeToCallServices: (self: ServiceController, serviceName: string, targetName: string?) -> (),
	register: (self: ServiceController, name: string, module: ServiceModule) -> (),
	_validateDependencyGraph: (self: ServiceController) -> (),
	_getTopologicalOrder: (self: ServiceController) -> { { string } },
	initService: (self: ServiceController, name: string, ...any) -> boolean,
	initAll: (self: ServiceController) -> (),
	startService: (self: ServiceController, name: string, onDone: (() -> ())?) -> boolean,
	startAll: (self: ServiceController) -> (),
	isInitialized: (self: ServiceController, name: string) -> boolean,
	isStarted: (self: ServiceController, name: string) -> boolean,
	getBootFailures: (self: ServiceController) -> { string },
	stopService: (self: ServiceController, name: string, onDone: (() -> ())?) -> boolean,
	stopAll: (self: ServiceController) -> (),
	getService: (self: ServiceController, name: string) -> ServiceModule?,
	getServiceState: (self: ServiceController, name: string) -> { [string]: any }?,
	getAllServices: (self: ServiceController) -> { [string]: ServiceEntry },
	getDependencies: (self: ServiceController, name: string) -> { string },
}

local ServiceController: ServiceController = {
	_services = {},
	_initOrder = {},
	_sortedOrder = nil, -- Cached topological sort
	_phase = "registering",

	--[=[
		Returns the current lifecycle phase.
		Useful for debugging or runtime assertions.
		@return Phase -- Current phase: "registering", "initializing", "starting", "running", or "stopping"
	]=]
	getPhase = function(self)
		return self._phase
	end,

	--[=[
		Asserts that cross-service calls are allowed. Call this at the start of service methods that
		depend on other services.

		Two levels of check:
		- COARSE (always): the phase is past init — a call during "initializing" is refused. This is all
		  the guard can enforce from the caller's name alone. It does NOT prove any specific callee has
		  finished start(): during the "starting" phase a service at a later topological level may not
		  have started yet. The real "your dependency is ready" guarantee comes from declaring it in
		  `dependencies` (the topological sort then starts it first) — NOT from this guard. In
		  particular, a call to an UNDECLARED service that hasn't started is invisible to the coarse check.
		- PRECISE (opt-in): pass `targetName` and the guard additionally asserts that specific service
		  has actually finished start() (isStarted). Use it at a call site that reaches a service it did
		  not declare as a dependency, to turn the silent-ordering-bug into a loud error.

		Runs everywhere (not just Studio): this is the one invariant the "direct require is safe"
		convention rests on, and a string comparison per guarded call is negligible — a violation that
		only manifests under live-server timing must fail loudly there too.

		@param serviceName string -- Name of the calling service (for error messages)
		@param targetName string? -- Optional callee to additionally assert has started
	]=]
	assertSafeToCallServices = function(self, serviceName, targetName)
		-- Standalone/test context: no services registered means the controller never booted, so
		-- there is no lifecycle to police. Skip. (During a real boot the registry is non-empty from
		-- the register phase onward, so this never masks an actual init-phase violation.)
		if next(self._services) == nil then
			return
		end
		assert(
			self._phase == "running" or self._phase == "starting",
			`[{serviceName}] Cannot call other services during "{self._phase}" phase. Wait until start() or later.`
		)
		-- Opt-in precise check: the named callee must have finished start(). This is the guarantee the
		-- coarse phase check cannot give for an undeclared callee.
		if targetName ~= nil and not self:isStarted(targetName) then
			error(
				`[{serviceName}] Cannot call "{targetName}": it has not finished start() (phase "{self._phase}"). `
					.. "Declare it in this service's `dependencies` so the topological sort starts it first, "
					.. "or defer the call."
			)
		end
	end,

	--[=[
		Registers a service with the controller.
		@param name string -- Unique service name
		@param module ServiceModule -- The service module table
	]=]
	register = function(self, name, module)
		assert(type(name) == "string", `name must be a string, got {type(name)}`)
		assert(type(module) == "table", `module must be a table, got {type(module)}`)
		assert(not self._services[name], `Service "{name}" is already registered`)

		local dependencies = module.dependencies or {}

		self._services[name] = {
			name = name,
			module = module,
			initialized = false,
			started = false,
			dependencies = dependencies,
		}
		table.insert(self._initOrder, name)
		self._sortedOrder = nil -- Invalidate cache when new service registered
	end,

	--[=[
		Validates that every declared dependency names a registered service, erroring with the FULL
		list of bad edges. Runs on every fresh topological sort (the choke point every lifecycle pass
		goes through), so a typo'd or unregistered dependency fails the boot loudly instead of
		silently voiding that service's ordering guarantee — the same fail-loud policy as initAll's
		failure collection and the circular-dependency error.
	]=]
	_validateDependencyGraph = function(self)
		local missing: { string } = {}
		for name, entry in pairs(self._services) do
			for _, depName in entry.dependencies do
				if not self._services[depName] then
					table.insert(missing, `"{name}" -> "{depName}"`)
				end
			end
		end
		if #missing > 0 then
			table.sort(missing)
			error(
				`[ServiceController] {#missing} dependency edge(s) reference unregistered services: `
					.. `{table.concat(missing, ", ")}. Register the missing services or fix the names in `
					.. "the depending services' `dependencies` arrays."
			)
		end
	end,

	--[=[
		Performs a topological sort of all registered services and groups them into dependency levels.

		Level 0: Services with no dependencies.
		Level N: Services whose deepest dependency is at Level N-1.

		Levels are solved by iterative fixpoint relaxation (Bellman-Ford-style longest-path): each
		pass raises a node to `max(dep levels) + 1` until nothing changes. This grouping allows
		concurrent operations within a level while guaranteeing that all dependencies (previous
		levels) are fully processed first, and the pass count doubles as the cycle check (see below).

		@return { { string } } -- 1-indexed array of levels, each a list of service names.
	]=]
	_getTopologicalOrder = function(self)
		if self._sortedOrder then
			return self._sortedOrder
		end

		-- A fresh sort means the registry changed since the last one — re-check every edge first,
		-- so the level solver below can rely on every dependency having a level.
		self:_validateDependencyGraph()

		local serviceLevels: { [string]: number } = {}
		local maxLevel = 0

		-- Initialize all registered services to level 0
		for name, _ in pairs(self._services) do
			serviceLevels[name] = 0
		end

		-- Iteratively solve for correct levels (max dependency depth). If levels keep increasing past
		-- the service count there is a dependency cycle — this loop is also the cycle check.
		-- (`_initOrder` is intentionally left mutable so services can still be registered later; an
		-- earlier version froze it here as a counting side effect, which silently forbade late
		-- registration.)
		local serviceCount = #self._initOrder
		local iterations = 0
		local changed = true

		while changed do
			changed = false
			iterations += 1
			if iterations > serviceCount then
				-- A cycle would otherwise boot the involved services in an arbitrary order. For a base
				-- reused across many games that must be a loud, deterministic failure, not a warning.
				-- Identify the participants (nodes still able to increase) for an actionable message.
				local cyclic: { string } = {}
				for name, entry in pairs(self._services) do
					for _, depName in entry.dependencies do
						if serviceLevels[depName] + 1 > serviceLevels[name] then
							table.insert(cyclic, name)
							break
						end
					end
				end
				error(
					`[ServiceController] Circular dependency detected among services: {table.concat(cyclic, ", ")}. `
						.. "Break the cycle in the involved services' `dependencies` arrays."
				)
			end

			for name, entry in pairs(self._services) do
				local currentLevel = serviceLevels[name]
				local newLevel = 0

				for _, depName in entry.dependencies do
					-- _validateDependencyGraph ran above, so every dependency has a level.
					newLevel = math.max(newLevel, serviceLevels[depName] + 1)
				end

				if newLevel > currentLevel then
					serviceLevels[name] = newLevel
					maxLevel = math.max(maxLevel, newLevel)
					changed = true
				end
			end
		end

		-- Group services into a 1-indexed array for clean iteration
		local levels: { { string } } = {}
		for i = 1, maxLevel + 1 do
			levels[i] = {}
		end

		for name, level in pairs(serviceLevels) do
			table.insert(levels[level + 1], name)
		end

		self._sortedOrder = levels
		return levels
	end,

	--[=[
		Initializes a single service with optional config.
		@param name string -- The service name
		@param ... any -- Optional arguments passed to init()
	]=]
	initService = function(self, name, ...)
		local entry = self._services[name]
		assert(entry, `Service "{name}" is not registered`)
		assert(not entry.initialized, `Service "{name}" is already initialized`)

		-- A dependency on an unregistered service is a registration bug (typo or missing register
		-- call) that would silently void this service's ordering guarantee — fail loud, matching the
		-- asserts above. initAll validates the whole graph up front; this guards direct calls.
		for _, dep in entry.dependencies do
			assert(self._services[dep], `Service "{name}" depends on "{dep}" which is not registered`)
		end

		if entry.module.init then
			local args = { ... }
			local startedAt = os.clock()
			local success, err = xpcall(function()
				entry.module.init(entry.module, table.unpack(args))
			end, debug.traceback)
			entry.initDurationMs = (os.clock() - startedAt) * 1000
			if not success then
				entry.initError = tostring(err)
				warn(`[ServiceController] Failed to init "{name}": {err}`)
				return false
			end
		end
		entry.initialized = true
		return true
	end,

	--[=[
		Initializes all registered services that haven't been initialized.
		Services are initialized in dependency order (dependencies first).
	]=]
	initAll = function(self)
		self._phase = "initializing"
		-- Collect every service whose init() failed and fail the whole boot afterwards. A swallowed
		-- init failure otherwise leaves a dead service that startAll silently skips while dependents
		-- start anyway — a partially-dead system that still logs "initialized successfully". Each
		-- failure's detail (traceback) is already captured on the entry and warned by initService.
		local failures: { string } = {}
		for _, levelServices in self:_getTopologicalOrder() do
			for _, name in levelServices do
				local entry = self._services[name]
				if not entry.initialized then
					if not self:initService(name) then
						table.insert(failures, name)
					end
				end
			end
		end
		if #failures > 0 then
			error(
				`[ServiceController] {#failures} service(s) failed to init: {table.concat(failures, ", ")}. `
					.. "See the warnings above for each failure's traceback."
			)
		end
	end,

	--[=[
		Starts a single service. Always uses `task.spawn` so a yielding `start()` never
		blocks the caller. `entry.started` is set to `true` immediately (before the spawn)
		so that subsequent services in the same topological pass see it as started.

		@param name string -- The service name
		@param onDone (() -> ())? -- Optional callback invoked when `start()` completes.
		  Used internally by `startAll()` for phase tracking. Omit for manual one-off starts.
	]=]
	startService = function(self, name, onDone)
		local entry = self._services[name]
		assert(entry, `Service "{name}" is not registered`)
		assert(entry.initialized, `Service "{name}" must be initialized before starting`)
		assert(not entry.started, `Service "{name}" is already started`)
		-- Same fail-loud policy as initService's registration check: starting a service whose
		-- dependency never initialized means the dependency guarantee is already broken — refuse
		-- rather than start into a half-booted graph.
		for _, dep in entry.dependencies do
			assert(self:isInitialized(dep), `Service "{name}" depends on "{dep}" which is not initialized`)
		end

		entry.started = true

		if entry.module.start then
			task.spawn(function()
				local startedAt = os.clock()
				local success, err = xpcall(function()
					entry.module.start(entry.module)
				end, debug.traceback)
				-- Includes any yields inside start(), which is intentional — the health board wants the
				-- wall-clock a service took to finish starting, waits and all.
				entry.startDurationMs = (os.clock() - startedAt) * 1000
				if not success then
					entry.startError = tostring(err)
					warn(`[ServiceController] Failed to start "{name}": {err}`)
				else
					entry.startSucceeded = true
				end
				if onDone then
					-- Defer so onDone is always async. This ensures startAll loop finishes
					-- and reaches coroutine.yield() before any pending decrement / resume.
					task.defer(onDone)
				end
			end)
		else
			-- No start() to run: the service is trivially started successfully.
			entry.startSucceeded = true
			if onDone then
				-- Defer for the same race-protection reason as above.
				task.defer(onDone)
			end
		end

		return true
	end,

	--[=[
		Starts all initialized services level-by-level, with services WITHIN each level
		running concurrently.

		How levels work (see `_getTopologicalOrder`):
		- Level 0: services with no dependencies — all start concurrently.
		- Level N: services whose deepest dependency is at level N-1.
		  They only begin after ALL level N-1 services have FULLY completed `start()`.

		This gives the dependency-safety guarantee the flat concurrent approach lacked:
		when your `start()` runs, every service you depend on has completely finished theirs.
		Services at the same level (no shared deps) still start concurrently, so one
		yielding service never delays a sibling at the same level.

		Join mechanism: zero-allocation coroutine resume. `task.defer` in `startService`
		for services without `start()` ensures `pending` only decrements after we yield,
		so the counter is always accurate when we check `if pending > 0`.

		If a service needs long-running background work, spawn it internally inside
		`start()` and return immediately — the level join will complete correctly.
	]=]
	startAll = function(self)
		self._phase = "starting"

		for _, levelServices in self:_getTopologicalOrder() do
			local pending = 0
			local callerThread = coroutine.running()

			local function onDone()
				pending -= 1
				if pending == 0 then
					task.spawn(callerThread)
				end
			end

			for _, name in levelServices do
				local entry = self._services[name]
				if entry.initialized and not entry.started then
					pending += 1
					self:startService(name, onDone)
				end
			end

			-- Yield until ALL services in this level have fully completed start().
			if pending > 0 then
				coroutine.yield()
			end
		end
		self._phase = "running"
	end,

	--[=[
		Checks if a service is initialized.
		@param name string -- The service name
		@return boolean
	]=]
	isInitialized = function(self, name)
		local entry = self._services[name]
		return entry and entry.initialized or false
	end,

	--[=[
		Checks if a service is started.
		@param name string -- The service name
		@return boolean
	]=]
	isStarted = function(self, name)
		local entry = self._services[name]
		-- Reports actual success, not merely that start was attempted (see ServiceEntry.startSucceeded).
		return entry and entry.startSucceeded == true or false
	end,

	--[=[
		Returns the names of every service whose init() or start() failed, sorted for stable output.
		The boot handlers call this after startAll() to decide between a success log and an ERROR
		summary — startAll's level join guarantees every start() has fully completed (and recorded any
		startError) by the time it returns, so this is an accurate post-boot health check.
		@return { string } -- Failed service names; empty when the boot is healthy
	]=]
	getBootFailures = function(self)
		local failures: { string } = {}
		for name, entry in self._services do
			if entry.initError or entry.startError then
				table.insert(failures, name)
			end
		end
		table.sort(failures)
		return failures
	end,

	--[=[
		Stops a single service and calls its stop() method if defined.
		Always uses `task.spawn` for the `stop()` call to be non-blocking.

		@param name string -- The service name
		@param onDone (() -> ())? -- Optional callback invoked when `stop()` completes.
	]=]
	stopService = function(self, name, onDone)
		local entry = self._services[name]
		assert(entry, `Service "{name}" is not registered`)

		-- Fully reset the entry to its just-registered state once teardown has run: a stopped service is
		-- UN-initialized, so a restart re-runs init() -> start() symmetrically (init is where a service
		-- wires the connections/state that stop() released — a start-only restart would leave it wired to
		-- nothing). Also clears the boot-introspection fields so a restarted service doesn't report a
		-- stale error via getBootFailures. Only called on the teardown paths below, never on the
		-- not-started early-return: that path ran no stop(), so init()'s resources are still live and
		-- clearing `initialized` would let a re-init double them.
		local function resetToUnbooted()
			entry.started = false
			entry.startSucceeded = false
			entry.initialized = false
			entry.initError = nil
			entry.startError = nil
			entry.initDurationMs = nil
			entry.startDurationMs = nil
		end

		if not entry.started then
			if onDone then
				task.defer(onDone)
			end
			return true
		end

		if entry.module.stop then
			-- Keep `started`/`startSucceeded` TRUE until stop() has actually finished, then reset inside
			-- the spawned thread. Clearing synchronously (as this did) opened a race: a startService
			-- called between this return and stop()'s completion would pass its `not entry.started`
			-- assert and run start() while the old stop() was still executing. Now the service reads as
			-- started for its whole teardown, so a restart is refused until stop() completes. (stopAll is
			-- unaffected — it yields per level until every onDone fires.)
			task.spawn(function()
				local success, err = xpcall(function()
					entry.module.stop(entry.module)
				end, debug.traceback)
				if not success then
					warn(`[ServiceController] Failed to stop "{name}": {err}`)
				end
				resetToUnbooted()
				if onDone then
					task.defer(onDone)
				end
			end)
		else
			-- No stop() to run: nothing async, so resetting synchronously is race-free.
			resetToUnbooted()
			if onDone then
				task.defer(onDone)
			end
		end

		return true
	end,

	--[=[
		Stops all started services level-by-level in reverse dependency order.
		Each level's services are stopped concurrently, and the system yields until
		a level is fully stopped before proceeding to the next (dependencies).

		Every stopped service is reset to its un-initialized state (see stopService), and the phase
		returns to "registering", so the controller is ready for a fresh initAll() -> startAll().
	]=]
	stopAll = function(self)
		self._phase = "stopping"
		local levels = self:_getTopologicalOrder()

		for i = #levels, 1, -1 do
			local levelServices = levels[i]
			local pending = 0
			local callerThread = coroutine.running()

			local function onDone()
				pending -= 1
				if pending == 0 then
					task.spawn(callerThread)
				end
			end

			for _, name in levelServices do
				local entry = self._services[name]
				if entry.started then
					pending += 1
					self:stopService(name, onDone)
				end
			end

			if pending > 0 then
				coroutine.yield()
			end
		end

		self._phase = "registering" -- Reset to initial phase after full stop
	end,

	--[=[
		Gets a registered service module by name.
		@param name string -- The service name
		@return ServiceModule? -- The service module or nil if not found
	]=]
	getService = function(self, name)
		local entry = self._services[name]
		return entry and entry.module
	end,

	--[=[
		Gets the state of a service if it implements getState().
		@param name string -- The service name
		@return { [string]: any }? -- The service state or nil
	]=]
	getServiceState = function(self, name)
		local entry = self._services[name]
		if entry and entry.module.getState then
			local success, state = xpcall(function()
				return entry.module.getState(entry.module)
			end, debug.traceback)
			if success then
				return state
			end
			warn(`[ServiceController] Failed to get state for "{name}": {state}`)
		end
		return nil
	end,

	--[=[
		Gets all registered service entries for debugging.
		@return { [string]: ServiceEntry } -- Map of service names to entries
	]=]
	getAllServices = function(self)
		return self._services
	end,

	--[=[
		Gets the dependencies of a service.
		@param name string -- The service name
		@return { string } -- Array of dependency names
	]=]
	getDependencies = function(self, name)
		local entry = self._services[name]
		return entry and entry.dependencies or {}
	end,
}

return ServiceController
