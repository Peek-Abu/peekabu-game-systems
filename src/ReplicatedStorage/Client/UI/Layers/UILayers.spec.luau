--!nocheck
--[=[
	Unit tests for the UILayers core (`UILayers.new`).

	The core is the pure bookkeeping half: lazy per-layer root acquisition, caching, and ordered
	teardown. It takes an injectable factory so these tests run with no PlayerGui and no renderer —
	the real Instance/ReactRoblox factory (UILayerHost) is the exempt shell, verified in Studio.
]=]

local UILayers = require(script.Parent.UILayers)

-- Builds a spy factory: records every call, returns handles whose render/unmount/destroy record too.
local function spyFactory()
	local record = {
		calls = {}, -- { { name = ..., displayOrder = ... }, ... }
		events = {}, -- ordered log of "render:Name" / "unmount:Name" / "destroy:Name"
	}
	local factory = function(name, displayOrder)
		table.insert(record.calls, { name = name, displayOrder = displayOrder })
		return {
			render = function(_element)
				table.insert(record.events, "render:" .. name)
			end,
			unmount = function()
				table.insert(record.events, "unmount:" .. name)
			end,
			destroy = function()
				table.insert(record.events, "destroy:" .. name)
			end,
		}
	end
	return factory, record
end

return function()
	describe("lazy acquisition", function()
		it("creates no root until a layer is acquired", function()
			local factory, record = spyFactory()
			UILayers.new(factory)
			expect(#record.calls).to.equal(0)
		end)

		it("creates a root on first acquire, with the display order from the ladder", function()
			local factory, record = spyFactory()
			local layers = UILayers.new(factory)
			layers.acquire("Panel")
			expect(#record.calls).to.equal(1)
			expect(record.calls[1].name).to.equal("Panel")
			expect(record.calls[1].displayOrder).to.equal(100)
		end)

		it("returns a working render function for the acquired layer", function()
			local factory, record = spyFactory()
			local layers = UILayers.new(factory)
			local render = layers.acquire("Hud")
			render(nil)
			expect(record.events[1]).to.equal("render:Hud")
		end)
	end)

	describe("caching", function()
		it("reuses the same root across repeated acquire calls", function()
			local factory, record = spyFactory()
			local layers = UILayers.new(factory)
			layers.acquire("Panel")
			layers.acquire("Panel")
			layers.acquire("Panel")
			expect(#record.calls).to.equal(1)
		end)

		it("creates a distinct root per layer", function()
			local factory, record = spyFactory()
			local layers = UILayers.new(factory)
			layers.acquire("Hud")
			layers.acquire("Panel")
			expect(#record.calls).to.equal(2)
		end)
	end)

	describe("teardown", function()
		it("unmounts each root BEFORE destroying its host", function()
			local factory, record = spyFactory()
			local layers = UILayers.new(factory)
			layers.acquire("Hud")
			layers.teardown()
			expect(record.events[1]).to.equal("unmount:Hud")
			expect(record.events[2]).to.equal("destroy:Hud")
		end)

		it("tears down every acquired layer in acquisition order", function()
			local factory, record = spyFactory()
			local layers = UILayers.new(factory)
			layers.acquire("Panel")
			layers.acquire("Hud")
			layers.teardown()
			-- Panel acquired first, so it tears down first.
			expect(record.events[1]).to.equal("unmount:Panel")
			expect(record.events[2]).to.equal("destroy:Panel")
			expect(record.events[3]).to.equal("unmount:Hud")
			expect(record.events[4]).to.equal("destroy:Hud")
		end)

		it("clears state so a later acquire recreates the root", function()
			local factory, record = spyFactory()
			local layers = UILayers.new(factory)
			layers.acquire("Hud")
			layers.teardown()
			layers.acquire("Hud")
			expect(#record.calls).to.equal(2)
		end)

		it("is a no-op when nothing was acquired", function()
			local factory, record = spyFactory()
			local layers = UILayers.new(factory)
			expect(function()
				layers.teardown()
			end).never.to.throw()
			expect(#record.events).to.equal(0)
		end)
	end)

	describe("validation", function()
		it("errors when acquiring an unknown layer, without calling the factory", function()
			local factory, record = spyFactory()
			local layers = UILayers.new(factory)
			expect(function()
				layers.acquire("Nope")
			end).to.throw()
			expect(#record.calls).to.equal(0)
		end)
	end)
end
