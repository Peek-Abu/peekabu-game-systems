--!strict
--[=[
	Unit tests for ServiceController module.
	Tests topological ordering, lifecycle gating, phase transitions, and circular dependency detection.

	Isolation strategy: shallow-copy the module table per test so methods run on a
	fresh `_services/_initOrder/_phase` without sharing the module-level singleton state.
	Note: `_getTopologicalOrder` calls `table.freeze(_initOrder)` as a side-effect, so
	tests that need to register after sorting create a new controller instance instead.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServiceController = require(ReplicatedStorage.Shared.Modules.ServiceController)

--[[
	Creates a fully isolated controller: shallow-copies all methods from the module,
	then overrides the mutable state fields. No __index chain means nil assignments
	stay nil instead of falling through to the module singleton.
]]
local function newController()
	local c = {}
	for k, v in pairs(ServiceController) do
		c[k] = v
	end
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
			for _, n in levels[1] do lvl1[n] = true end
			expect(lvl1["A"]).to.equal(true)

			local lvl2: { [string]: boolean } = {}
			for _, n in levels[2] do lvl2[n] = true end
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

		it("should warn but not crash on circular dependencies", function()
			local c = newController()
			c:register("A", makeService({ "B" }))
			c:register("B", makeService({ "A" }))
			expect(function()
				c:_getTopologicalOrder()
			end).never.to.throw()
		end)
	end)

	-- -----------------------------------------------------------------------
	describe("initService", function()
		it("should call init() and mark service as initialized", function()
			local c = newController()
			local called = false
			c:register("A", { init = function(_self) called = true end })
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
			c:register("A", { init = function(_self) error("boom") end })
			local result = c:initService("A")
			expect(result).to.equal(false)
			expect(c:isInitialized("A")).to.equal(false)
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
