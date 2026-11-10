--!nocheck
--[=[
	Unit tests for HudRegistry. The registry is a global singleton that persists across a Studio test
	session, so these tests use "HudSpec.*" keys, guarded by `has`, and only assert relative order.
]=]

local HudRegistry = require(script.Parent.HudRegistry)

local function widget()
	return nil
end

local function ensure(key, order)
	if not HudRegistry.has(key) then
		HudRegistry.register(key, widget, order)
	end
end

local function indexOf(key)
	for index, entry in HudRegistry.list() do
		if entry.key == key then
			return index
		end
	end
	return nil
end

return function()
	it("lists a registered widget with its component", function()
		ensure("HudSpec.Coins")
		local index = indexOf("HudSpec.Coins")
		expect(index).to.be.ok()
		expect(HudRegistry.list()[index].component).to.equal(widget)
	end)

	it("defaults order to 0", function()
		ensure("HudSpec.Default")
		expect(HudRegistry.list()[indexOf("HudSpec.Default")].order).to.equal(0)
	end)

	it("sorts by order, then by key", function()
		ensure("HudSpec.Late", 10)
		ensure("HudSpec.Early", -10)
		ensure("HudSpec.B", 5)
		ensure("HudSpec.A", 5)
		expect(indexOf("HudSpec.Early") < indexOf("HudSpec.A")).to.equal(true)
		expect(indexOf("HudSpec.A") < indexOf("HudSpec.B")).to.equal(true)
		expect(indexOf("HudSpec.B") < indexOf("HudSpec.Late")).to.equal(true)
	end)

	it("stacks widgets by their order: a later widget draws over an earlier one", function()
		ensure("HudSpec.Under", -20)
		ensure("HudSpec.Over", 2500)
		local zOf = {}
		for _, layer in HudRegistry.layers() do
			zOf[layer.key] = layer.zIndex
		end
		expect(zOf["HudSpec.Under"] < zOf["HudSpec.A"]).to.equal(true)
		expect(zOf["HudSpec.A"] < zOf["HudSpec.B"]).to.equal(true)
		expect(zOf["HudSpec.B"] < zOf["HudSpec.Over"]).to.equal(true)
	end)

	it("gives every widget its own layer, numbered from 1", function()
		local layers = HudRegistry.layers()
		expect(#layers).to.equal(#HudRegistry.list())
		for index, layer in layers do
			expect(layer.zIndex).to.equal(index)
			expect(layer.component).to.be.ok()
		end
	end)

	it("errors on a duplicate key", function()
		ensure("HudSpec.Dup")
		expect(function()
			HudRegistry.register("HudSpec.Dup", widget)
		end).to.throw()
	end)
end
