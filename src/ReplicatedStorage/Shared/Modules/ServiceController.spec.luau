--!strict
--[=[
	Unit tests for ServiceController module.
	Tests topological ordering, lifecycle gating, phase transitions, and circular dependency detection.

	Isolation strategy: shallow-copy the module table per test so methods run on a
	fresh `_services/_initOrder/_phase` without sharing the module-level singleton state.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServiceController = require(ReplicatedStorage.Shared.Modules.ServiceController)

--[[
	Creates a fully isolated controller: shallow-copies all methods from the module,
	then overrides the mutable state fields. No __index chain means nil assignments
	stay nil instead of falling through to the module singleton.
]]
local function newController()
	local c = table.clone(ServiceController)
	c._services = {}
	c._initOrder = {}
	c._phase = "registering"
	c._sortedOrder = nil -- DO NOT REMOVE: explicitly clear caching from module singleton
	return c
end

local function makeService(deps: { string }?): ServiceController.ServiceModule
	return { dependencies = deps or {} }
end

return function()
	-- -----------------------------------------------------------------------
	describe("register", function()
		it("should register a service successfully", function()
			local c = newController()
			c:register("A", makeService())
			expect(c._services["A"]).to.be.ok()
		end)

		it("should throw when registering the same name twice", function()
			local c = newController()
			c:register("A", makeService())
			expect(function()
				c:register("A", makeService())
			end).to.throw()
		end)

		it("should throw for non-string name", function()
			local c = newController()
			expect(function()
				c:register(123 :: any, makeService())
			end).to.throw()
		end)

		it("should start with nil sorted cache", function()
			local c = newController()
			expect(c._sortedOrder).to.equal(nil)
		end)
	end)

	-- -----------------------------------------------------------------------
	describe("_getTopologicalOrder", function()
		it("should place two no-dep services in a single level", function()
			local c = newController()
			c:register("A", makeService())
			c:register("B", makeService())
			local levels = c:_getTopologicalOrder()
			expect(#levels).to.equal(1)
			expect(#levels[1]).to.equal(2)
		end)

		it("should place a dependent service one level above its dep", function()
			local c = newController()
			c:register("A", makeService())
			c:register("B", makeService({ "A" }))
			local levels = c:_getTopologicalOrder()
			expect(#levels).to.equal(2)

			local lvl1: { [string]: boolean } = {}
			for _, n in levels[1] do
				lvl1[n] = true
			end
			expect(lvl1["A"]).to.equal(true)

			local lvl2: { [string]: boolean } = {}
			for _, n in levels[2] do
				lvl2[n] = true
			end
			expect(lvl2["B"]).to.equal(true)
		end)

		it("should handle a three-level chain", function()
			local c = newController()
			c:register("A", makeService())
			c:register("B", makeService({ "A" }))
			c:register("C", makeService({ "B" }))
			local levels = c:_getTopologicalOrder()
			expect(#levels).to.equal(3)
		end)

		it("should populate _sortedOrder as a cache after first call", function()
			local c = newController()
			c:register("A", makeService())
			expect(c._sortedOrder).to.equal(nil)
			c:_getTopologicalOrder()
			expect(c._sortedOrder).to.be.ok()
		end)

		it("should return the same table on repeated calls (cache hit)", function()
			local c = newController()
			c:register("A", makeService())
			local first = c:_getTopologicalOrder()
			local second = c:_getTopologicalOrder()
			expect(first).to.equal(second)
		end)

		it("should error (fail loud) on circular dependencies", function()
			local c = newController()
			c:register("A", makeService({ "B" }))
			c:register("B", makeService({ "A" }))
			expect(function()
				c:_getTopologicalOrder()
			end).to.throw()
		end)

		it("should allow registering a service after a sort (order stays mutable)", function()
			-- A previous version froze _initOrder while counting, which silently forbade this.
			local c = newController()
			c:register("A", makeService())
			c:_getTopologicalOrder()
			expect(function()
				c:register("B", makeService({ "A" }))
			end).never.to.throw()
			-- The new service participates in a fresh sort (cache was invalidated by register).
			local levels = c:_getTopologicalOrder()
			expect(#levels).to.equal(2)
		end)
	end)

	-- -----------------------------------------------------------------------
	describe("initService", function()
		it("should call init() and mark service as initialized", function()
			local c = newController()
			local called = false
			c:register("A", {
				init = function(_self)
					called = true
				end,
			})
			c:initService("A")
			expect(called).to.equal(true)
			expect(c:isInitialized("A")).to.equal(true)
		end)

		it("should throw for unknown service", function()
			local c = newController()
			expect(function()
				c:initService("Unknown")
			end).to.throw()
		end)

		it("should throw when already initialized", function()
			local c = newController()
			c:register("A", makeService())
			c:initService("A")
			expect(function()
				c:initService("A")
			end).to.throw()
		end)

		it("should work for services with no init()", function()
			local c = newController()
			c:register("A", makeService())
			expect(function()
				c:initService("A")
			end).never.to.throw()
			expect(c:isInitialized("A")).to.equal(true)
		end)

		it("should return false and not mark initialized when init() errors", function()
			local c = newController()
			c:register("A", {
				init = function(_self)
					error("boom")
				end,
			})
			local result = c:initService("A")
			expect(result).to.equal(false)
			expect(c:isInitialized("A")).to.equal(false)
		end)
	end)

	-- -----------------------------------------------------------------------
	describe("initAll", function()
		it("should init every registered service in dependency order", function()
			local c = newController()
			local order: { string } = {}
			c:register("A", {
				init = function(_self)
					table.insert(order, "A")
				end,
			})
			c:register("B", {
				dependencies = { "A" },
				init = function(_self)
					table.insert(order, "B")
				end,
			})
			c:initAll()
			expect(c:isInitialized("A")).to.equal(true)
			expect(c:isInitialized("B")).to.equal(true)
			-- A is a dependency of B, so it inits first.
			expect(order[1]).to.equal("A")
			expect(order[2]).to.equal("B")
		end)

		it("should error (fail loud) when any service's init() fails", function()
			local c = newController()
			c:register("A", makeService())
			c:register("B", {
				init = function(_self)
					error("boom")
				end,
			})
			expect(function()
				c:initAll()
			end).to.throw()
			-- The failing service is left un-initialized (initService did not mark it).
			expect(c:isInitialized("B")).to.equal(false)
		end)
	end)

	-- -----------------------------------------------------------------------
	describe("startService", function()
		it("should throw when service is not initialized", function()
			local c = newController()
			c:register("A", makeService())
			expect(function()
				c:startService("A")
			end).to.throw()
		end)

		it("should mark service as started", function()
			local c = newController()
			c:register("A", makeService())
			c:initService("A")
			c:startService("A")
			expect(c:isStarted("A")).to.equal(true)
		end)

		it("should throw when already started", function()
			local c = newController()
			c:register("A", makeService())
			c:initService("A")
			c:startService("A")
			expect(function()
				c:startService("A")
			end).to.throw()
		end)

		it("should report isStarted() = false when start() throws", function()
			local c = newController()
			c:register("A", {
				start = function(_self)
					error("boom")
				end,
			})
			c:initService("A")
			c:startService("A")
			-- start() ran synchronously via task.spawn and threw; the attempt is recorded but
			-- isStarted reflects actual success (startSucceeded), so it stays false.
			expect(c:isStarted("A")).to.equal(false)
		end)
	end)

	-- -----------------------------------------------------------------------
	describe("getBootFailures", function()
		it("returns empty when every service booted cleanly", function()
			local c = newController()
			c:register("A", makeService())
			c:initService("A")
			c:startService("A")
			local failures = c:getBootFailures()
			expect(#failures).to.equal(0)
		end)

		it("reports a service whose init() failed", function()
			local c = newController()
			c:register("Bad", {
				init = function(_self)
					error("boom")
				end,
			})
			c:initService("Bad")
			local failures = c:getBootFailures()
			expect(#failures).to.equal(1)
			expect(failures[1]).to.equal("Bad")
		end)

		it("reports a service whose start() failed, sorted by name", function()
			local c = newController()
			c:register("Zed", {
				start = function(_self)
					error("boom")
				end,
			})
			c:register("Alpha", {
				start = function(_self)
					error("boom")
				end,
			})
			c:initService("Zed")
			c:initService("Alpha")
			-- start() runs synchronously up to its error via task.spawn, so the failure is
			-- recorded by the time startService returns.
			c:startService("Zed")
			c:startService("Alpha")
			local failures = c:getBootFailures()
			expect(#failures).to.equal(2)
			expect(failures[1]).to.equal("Alpha")
			expect(failures[2]).to.equal("Zed")
		end)
	end)

	-- -----------------------------------------------------------------------
	describe("getPhase", function()
		it("should start at registering", function()
			local c = newController()
			expect(c:getPhase()).to.equal("registering")
		end)

		it("should be initializing during initAll", function()
			local c = newController()
			local phaseOnInit = nil
			c:register("A", {
				init = function(_self)
					phaseOnInit = c:getPhase()
				end,
			})
			c:initAll()
			expect(phaseOnInit).to.equal("initializing")
		end)
	end)

	-- -----------------------------------------------------------------------
	describe("dependency validation (fail loud)", function()
		it("errors from _getTopologicalOrder when a dependency is unregistered (typo)", function()
			local c = newController()
			c:register("A", makeService({ "PlayerDataSevrice" })) -- deliberate typo
			expect(function()
				c:_getTopologicalOrder()
			end).to.throw()
		end)

		it("errors from initAll when any service depends on an unregistered service", function()
			local c = newController()
			c:register("A", makeService())
			c:register("B", makeService({ "Missing" }))
			expect(function()
				c:initAll()
			end).to.throw()
			-- Nothing initialized: the graph is validated before any init() runs.
			expect(c:isInitialized("A")).to.equal(false)
		end)

		it("errors from a direct initService call when a dependency is not registered", function()
			local c = newController()
			c:register("A", makeService({ "Missing" }))
			expect(function()
				c:initService("A")
			end).to.throw()
		end)

		it("errors from startService when a dependency is not initialized", function()
			local c = newController()
			c:register("A", makeService())
			c:register("B", makeService({ "A" }))
			c:initService("B") -- A is registered, so init succeeds — but A is never initialized
			expect(function()
				c:startService("B")
			end).to.throw()
		end)
	end)

	-- -----------------------------------------------------------------------
	describe("startAll — level ordering and concurrency", function()
		it("does not start a dependent until its dependency has FULLY finished a yielding start()", function()
			local c = newController()
			local events: { string } = {}
			c:register("A", {
				start = function(_self)
					table.insert(events, "A-begin")
					task.wait(0.05) -- yielding start: the level join must wait this out
					table.insert(events, "A-end")
				end,
			})
			c:register("B", {
				dependencies = { "A" },
				start = function(_self)
					table.insert(events, "B-begin")
				end,
			})
			c:initAll()
			c:startAll()
			expect(events[1]).to.equal("A-begin")
			expect(events[2]).to.equal("A-end")
			expect(events[3]).to.equal("B-begin")
		end)

		it("starts same-level siblings concurrently (a yielding sibling does not delay the other)", function()
			local c = newController()
			local events: { string } = {}
			c:register("Slow", {
				start = function(_self)
					table.insert(events, "Slow-begin")
					task.wait(0.05)
					table.insert(events, "Slow-end")
				end,
			})
			c:register("Fast", {
				start = function(_self)
					table.insert(events, "Fast-begin")
				end,
			})
			c:initAll()
			c:startAll()
			-- Fast must have begun (and finished) while Slow was still yielding: both are level 0.
			-- assert() doubles as the nil-narrowing so the comparison below is cast-free.
			local fastBegin = assert(table.find(events, "Fast-begin"), "Fast-begin was never recorded")
			local slowEnd = assert(table.find(events, "Slow-end"), "Slow-end was never recorded")
			expect(fastBegin < slowEnd).to.equal(true)
		end)

		it("is 'starting' during start() and 'running' only after every level completes", function()
			local c = newController()
			local phaseDuringStart: string? = nil
			c:register("A", {
				start = function(_self)
					task.wait(0.05)
					phaseDuringStart = c:getPhase()
				end,
			})
			c:initAll()
			c:startAll()
			expect(phaseDuringStart).to.equal("starting")
			expect(c:getPhase()).to.equal("running")
		end)
	end)

	-- -----------------------------------------------------------------------
	describe("stopService — teardown race", function()
		it("refuses a restart while a yielding stop() is executing, and allows it after", function()
			local c = newController()
			local stopFinished = false
			c:register("A", {
				stop = function(_self)
					task.wait(0.05)
					stopFinished = true
				end,
			})
			c:initService("A")
			c:startService("A")
			c:stopService("A")
			-- stop() is still yielding: the service must read as started so a restart is refused.
			expect(stopFinished).to.equal(false)
			expect(function()
				c:startService("A")
			end).to.throw()
			task.wait(0.1)
			-- Teardown complete: the service is now fully un-booted (restart is symmetric — see
			-- stopService). A start alone is refused (it must be re-initialized first)...
			expect(stopFinished).to.equal(true)
			expect(c:isInitialized("A")).to.equal(false)
			expect(function()
				c:startService("A")
			end).to.throw()
			-- ...and re-init -> re-start succeeds.
			expect(function()
				c:initService("A")
				c:startService("A")
			end).never.to.throw()
			expect(c:isStarted("A")).to.equal(true)
		end)
	end)

	-- -----------------------------------------------------------------------
	describe("stopAll", function()
		it("stops dependents before their dependencies (reverse level order)", function()
			local c = newController()
			local events: { string } = {}
			c:register("A", {
				stop = function(_self)
					table.insert(events, "A-stop")
				end,
			})
			c:register("B", {
				dependencies = { "A" },
				stop = function(_self)
					table.insert(events, "B-stop")
				end,
			})
			c:initAll()
			c:startAll()
			c:stopAll()
			expect(events[1]).to.equal("B-stop")
			expect(events[2]).to.equal("A-stop")
			expect(c:getPhase()).to.equal("registering")
		end)
	end)

	-- -----------------------------------------------------------------------
	describe("assertSafeToCallServices", function()
		it("skips the check entirely when no services are registered (standalone/test context)", function()
			local c = newController()
			expect(function()
				c:assertSafeToCallServices("Anything")
			end).never.to.throw()
		end)

		it("throws during the initializing phase", function()
			local c = newController()
			local okDuringInit: boolean? = nil
			c:register("A", {
				init = function(_self)
					okDuringInit = pcall(function()
						c:assertSafeToCallServices("A")
					end)
				end,
			})
			c:initAll()
			expect(okDuringInit).to.equal(false)
		end)

		it("allows calls during starting and running", function()
			local c = newController()
			local okDuringStart: boolean? = nil
			c:register("A", {
				start = function(_self)
					okDuringStart = pcall(function()
						c:assertSafeToCallServices("A")
					end)
				end,
			})
			c:initAll()
			c:startAll()
			expect(okDuringStart).to.equal(true)
			expect(function()
				c:assertSafeToCallServices("A")
			end).never.to.throw()
		end)

		it("with a target, passes when that service has started", function()
			local c = newController()
			c:register("A", makeService())
			c:register("B", makeService())
			c:initAll()
			c:startAll()
			expect(function()
				c:assertSafeToCallServices("A", "B")
			end).never.to.throw()
		end)

		it("with a target, throws when that service has not started (undeclared/unregistered)", function()
			local c = newController()
			c:register("A", makeService())
			c:initAll()
			c:startAll()
			-- Phase is "running" (coarse check passes) but the target never started, so the precise
			-- check fires — exactly the undeclared-callee case the coarse phase check cannot see.
			expect(function()
				c:assertSafeToCallServices("A", "Ghost")
			end).to.throw()
		end)
	end)

	-- -----------------------------------------------------------------------
	describe("restart after stop", function()
		it("resets a stopped service to un-initialized so restart re-runs init() then start()", function()
			local c = newController()
			local initCount = 0
			local startCount = 0
			c:register("A", {
				init = function(_self)
					initCount += 1
				end,
				start = function(_self)
					startCount += 1
				end,
			})

			c:initAll()
			c:startAll()
			expect(initCount).to.equal(1)
			expect(startCount).to.equal(1)

			c:stopAll()
			-- A stopped service is fully un-booted: init() may run again.
			expect(c:isInitialized("A")).to.equal(false)
			expect(c:isStarted("A")).to.equal(false)

			-- Symmetric restart: init() re-runs, then start() re-runs.
			c:initAll()
			c:startAll()
			expect(initCount).to.equal(2)
			expect(startCount).to.equal(2)
			expect(c:isStarted("A")).to.equal(true)
		end)

		it("clears stale boot-introspection so getBootFailures is empty after a clean restart", function()
			local c = newController()
			local failStart = true
			c:register("A", {
				start = function(_self)
					if failStart then
						error("boom on first start")
					end
				end,
			})

			c:initAll()
			c:startAll()
			expect(#c:getBootFailures()).to.equal(1)

			-- Stop clears the recorded startError; a succeeding restart must not report the old one.
			failStart = false
			c:stopAll()
			c:initAll()
			c:startAll()
			expect(#c:getBootFailures()).to.equal(0)
		end)
	end)

	-- -----------------------------------------------------------------------
	describe("getServiceState", function()
		it("returns nil for a service without getState", function()
			local c = newController()
			c:register("A", makeService())
			expect(c:getServiceState("A")).to.equal(nil)
		end)

		it("returns the table produced by getState", function()
			local c = newController()
			c:register("A", {
				getState = function(_self)
					return { healthy = true }
				end,
			})
			-- assert() doubles as the nil-narrowing so the field read below is cast-free.
			local state = assert(c:getServiceState("A"), "getServiceState returned nil")
			expect(state.healthy).to.equal(true)
		end)

		it("returns nil without throwing when getState errors", function()
			local c = newController()
			c:register("A", {
				getState = function(_self): { [string]: any }
					error("boom")
				end,
			})
			local state: { [string]: any }? = nil
			expect(function()
				state = c:getServiceState("A")
			end).never.to.throw()
			expect(state).to.equal(nil)
		end)
	end)

	-- -----------------------------------------------------------------------
	describe("getService / getDependencies", function()
		it("should return nil for unregistered service", function()
			local c = newController()
			expect(c:getService("Unknown")).to.equal(nil)
		end)

		it("should return the module for a registered service", function()
			local c = newController()
			local svc = makeService()
			c:register("A", svc)
			expect(c:getService("A")).to.equal(svc)
		end)

		it("should return empty table for unknown service dependencies", function()
			local c = newController()
			local deps = c:getDependencies("Unknown")
			expect(type(deps)).to.equal("table")
			expect(#deps).to.equal(0)
		end)

		it("should return declared dependencies", function()
			local c = newController()
			c:register("A", makeService({ "B", "C" }))
			local deps = c:getDependencies("A")
			expect(#deps).to.equal(2)
		end)
	end)
end
