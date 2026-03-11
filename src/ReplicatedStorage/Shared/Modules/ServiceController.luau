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

	Standardized Method Syntax (`.` vs `:`):
	ALL services in this codebase MUST follow this convention:

	- Lifecycle methods (init, start, stop) → DOT syntax: `function Service.init(self)`
	  → Called BY ServiceController (framework-managed)

	- Runtime methods (all others) → COLON syntax: `function Service:doSomething()`
	  → Called BY other services/scripts (user-called)

	Rationale:
	- The dot syntax visually distinguishes "framework-managed" from "user-called" methods
	- This convention helps engineers and AI identify method ownership at a glance
	- Lifecycle methods are invoked by the controller, not by service authors
	
	When writing a new service:
	```lua
	function MyService.init(self)      -- DOT - called by ServiceController
	function MyService.start(self)     -- DOT - called by ServiceController
	function MyService.stop(self)      -- DOT - called by ServiceController
	function MyService:publicMethod()  -- COLON - called by other code
	```

	`self` vs `_self` in Lifecycle Methods:
	- Use `self` when the method reads or writes ANY field on the service table (e.g., `self.PlayerStore = ...`)
	- Use `_self` when the method does NOT use the service table at all (linter-safe unused-param signal)
	- The `@param` annotation ALWAYS matches the actual parameter name MINUS UNDERSCORE:
	  - `@param self MyService` when the method uses self
	  - `@param self MyService` when self is unused
	- This is purely a code-quality signal for linters; both names receive the same value at runtime

	Example:
	```lua
	-- Uses self → param is named self
	function MyService.init(self: MyService, config: Config)
	    self.store = config.store  -- reading/writing self
	end

	-- Doesn't use self → param is named _self (linter won't complain about unused param)
	function MyService.stop(_self: MyService)
	    janitor:Cleanup()  -- only touching module-scoped state
	end
	```

	When to use start() vs init():
	- Use init() for internal setup: event listeners, local state, config parsing
	- Use start() when you need to call methods on OTHER services at startup

	Example - QuestService that checks player currency on startup:
	```lua
	local QuestService = {}
	QuestService.dependencies = { "PlayerDataServiceServer", "CurrencyServiceServer" }

	function QuestService.init(self)
		-- Internal setup only - do NOT call other services here
		self.activeQuests = {}
		janitor:Add(Players.PlayerAdded:Connect(function(player)
			self:onPlayerAdded(player)
		end))
	end

	function QuestService.start(self)
		-- Safe to call other services here - all are initialized
		local CurrencyService = require(path.to.CurrencyServiceServer)

		-- Example: Grant daily login bonus if player has no gold
		for _, player in Players:GetPlayers() do
			local gold = CurrencyService:getCurrencyAmount(player.UserId, "gold")
			if gold == 0 then
				CurrencyService:addCurrency(player.UserId, "gold", 100)
			end
		end
	end
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
	started: boolean,
	dependencies: { string },
}

export type Phase = "registering" | "initializing" | "starting" | "running" | "stopping"

local ServiceController = {}
ServiceController._services = {} :: { [string]: ServiceEntry }
ServiceController._initOrder = {} :: { string }
ServiceController._sortedOrder = nil :: { { string } }? -- Cached topological sort
ServiceController._phase = "registering" :: Phase

--[=[
	Returns the current lifecycle phase.
	Useful for debugging or runtime assertions.
	@return Phase -- Current phase: "registering", "initializing", "starting", "running", or "stopping"
]=]
function ServiceController:getPhase(): Phase
	return self._phase
end

--[=[
	Asserts that cross-service calls are allowed (not in init phase).
	Call this at the start of service methods that depend on other services.
	Only runs in Studio for performance.
	@param serviceName string -- Name of the calling service (for error messages)
]=]
function ServiceController:assertSafeToCallServices(serviceName: string)
	if game:GetService("RunService"):IsStudio() then
		assert(
			self._phase == "running" or self._phase == "starting",
			`[{serviceName}] Cannot call other services during "{self._phase}" phase. Wait until start() or later.`
		)
	end
end

--[=[
	Registers a service with the controller.
	@param name string -- Unique service name
	@param module ServiceModule -- The service module table
]=]
function ServiceController:register(name: string, module: ServiceModule)
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
end

--[=[
	Performs a topological sort of all registered services and groups them into dependency levels.

	Level 0: Services with no dependencies.
	Level N: Services whose deepest dependency is at Level N-1.

	This grouping (Kahn-like) allows for concurrent operations within a level while 
	guaranteeing that all dependencies (previous levels) are fully processed first.

	@return { { string } } -- 1-indexed array of levels, each a list of service names.
]=]
function ServiceController:_getTopologicalOrder(): { { string } }
	if self._sortedOrder then
		return self._sortedOrder
	end

	local serviceLevels: { [string]: number } = {}
	local maxLevel = 0

	-- Initialize all registered services to level 0
	for name, _ in pairs(self._services) do
		serviceLevels[name] = 0
	end

	-- Iteratively solve for correct levels (max dependency depth)
	-- This also serves as a check: if levels keep increasing beyond N, there's a cycle
	local serviceCount = table.freeze(self._initOrder) and #self._initOrder
	local iterations = 0
	local changed = true

	while changed do
		changed = false
		iterations += 1
		if iterations > serviceCount then
			warn("[ServiceController] Possible circular dependency detected during level computation")
			break
		end

		for name, entry in pairs(self._services) do
			local currentLevel = serviceLevels[name]
			local newLevel = 0

			for _, depName in entry.dependencies do
				local depLevel = serviceLevels[depName]
				if depLevel ~= nil then
					newLevel = math.max(newLevel, depLevel + 1)
				end
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
end

--[=[
	Initializes a single service with optional config.
	@param name string -- The service name
	@param ... any -- Optional arguments passed to init()
]=]
function ServiceController:initService(name: string, ...: any)
	local entry = self._services[name]
	assert(entry, `Service "{name}" is not registered`)
	assert(not entry.initialized, `Service "{name}" is already initialized`)

	-- Validate dependencies are registered
	for _, dep in entry.dependencies do
		if not self._services[dep] then
			warn(`[ServiceController] Service "{name}" depends on "{dep}" which is not registered`)
		end
	end

	if entry.module.init then
		local args = { ... }
		local success, err = xpcall(function()
			entry.module.init(entry.module, table.unpack(args))
		end, debug.traceback)
		if not success then
			warn(`[ServiceController] Failed to init "{name}": {err}`)
			return false
		end
	end
	entry.initialized = true
	return true
end

--[=[
	Initializes all registered services that haven't been initialized.
	Services are initialized in dependency order (dependencies first).
]=]
function ServiceController:initAll()
	self._phase = "initializing"
	for _, levelServices in self:_getTopologicalOrder() do
		for _, name in levelServices do
			local entry = self._services[name]
			if not entry.initialized then
				self:initService(name)
			end
		end
	end
end

--[=[
	Starts a single service. Always uses `task.spawn` so a yielding `start()` never
	blocks the caller. `entry.started` is set to `true` immediately (before the spawn)
	so that subsequent services in the same topological pass see it as started.

	@param name string -- The service name
	@param onDone (() -> ())? -- Optional callback invoked when `start()` completes.
	  Used internally by `startAll()` for phase tracking. Omit for manual one-off starts.
]=]
function ServiceController:startService(name: string, onDone: (() -> ())?)
	local entry = self._services[name]
	assert(entry, `Service "{name}" is not registered`)
	assert(entry.initialized, `Service "{name}" must be initialized before starting`)
	assert(not entry.started, `Service "{name}" is already started`)
	-- Validate dependencies are initialized
	for _, dep in entry.dependencies do
		if not self:isInitialized(dep) then
			warn(`[ServiceController] Service "{name}" depends on "{dep}" which is not initialized`)
		end
	end

	entry.started = true

	if entry.module.start then
		task.spawn(function()
			local success, err = xpcall(function()
				entry.module.start(entry.module)
			end, debug.traceback)
			if not success then
				warn(`[ServiceController] Failed to start "{name}": {err}`)
			end
			if onDone then
				-- Defer so onDone is always async. This ensures startAll loop finishes
				-- and reaches coroutine.yield() before any pending decrement / resume.
				task.defer(onDone)
			end
		end)
	elseif onDone then
		-- No start() — defer for the same race-protection reason
		task.defer(onDone)
	end

	return true
end

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
function ServiceController:startAll()
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
end

--[=[
	Checks if a service is initialized.
	@param name string -- The service name
	@return boolean
]=]
function ServiceController:isInitialized(name: string): boolean
	local entry = self._services[name]
	return entry and entry.initialized or false
end

--[=[
	Checks if a service is started.
	@param name string -- The service name
	@return boolean
]=]
function ServiceController:isStarted(name: string): boolean
	local entry = self._services[name]
	return entry and entry.started or false
end

--[=[
	Stops a single service and calls its stop() method if defined.
	Always uses `task.spawn` for the `stop()` call to be non-blocking.
	
	@param name string -- The service name
	@param onDone (() -> ())? -- Optional callback invoked when `stop()` completes.
]=]
function ServiceController:stopService(name: string, onDone: (() -> ())?)
	local entry = self._services[name]
	assert(entry, `Service "{name}" is not registered`)

	if not entry.started then
		if onDone then
			task.defer(onDone)
		end
		return true
	end

	if entry.module.stop then
		task.spawn(function()
			local success, err = xpcall(function()
				entry.module.stop(entry.module)
			end, debug.traceback)
			if not success then
				warn(`[ServiceController] Failed to stop "{name}": {err}`)
			end
			if onDone then
				task.defer(onDone)
			end
		end)
	elseif onDone then
		task.defer(onDone)
	end

	entry.started = false
	return true
end

--[=[
	Stops all started services level-by-level in reverse dependency order.
	Each level's services are stopped concurrently, and the system yields until
	a level is fully stopped before proceeding to the next (dependencies).
]=]
function ServiceController:stopAll()
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
end

--[=[
	Gets a registered service module by name.
	@param name string -- The service name
	@return ServiceModule? -- The service module or nil if not found
]=]
function ServiceController:getService(name: string): ServiceModule?
	local entry = self._services[name]
	return entry and entry.module
end

--[=[
	Gets the state of a service if it implements getState().
	@param name string -- The service name
	@return { [string]: any }? -- The service state or nil
]=]
function ServiceController:getServiceState(name: string): { [string]: any }?
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
end

--[=[
	Gets all registered service entries for debugging.
	@return { [string]: ServiceEntry } -- Map of service names to entries
]=]
function ServiceController:getAllServices(): { [string]: ServiceEntry }
	return self._services
end

--[=[
	Gets the dependencies of a service.
	@param name string -- The service name
	@return { string } -- Array of dependency names
]=]
function ServiceController:getDependencies(name: string): { string }
	local entry = self._services[name]
	return entry and entry.dependencies or {}
end

return ServiceController
