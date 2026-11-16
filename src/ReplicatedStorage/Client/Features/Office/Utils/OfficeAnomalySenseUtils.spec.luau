local OfficeAnomalySenseUtils = require(script.Parent.OfficeAnomalySenseUtils)

local function part(name, parent, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	for k, v in props or {} do
		p[k] = v
	end
	p.Parent = parent
	return p
end

return function()
	local slot
	beforeEach(function()
		slot = Instance.new("Model")
		slot.Name = "SenseSlot"
	end)
	afterEach(function()
		slot:Destroy()
	end)

	describe("namedParts / firstPart", function()
		it("finds every descendant part with the name, nested or not", function()
			local a = part("LobbyDoorLeaf", slot)
			local folder = Instance.new("Folder")
			folder.Parent = slot
			local b = part("LobbyDoorLeaf", folder)
			part("Other", slot)
			local list = OfficeAnomalySenseUtils.namedParts(slot, "LobbyDoorLeaf")
			expect(#list).to.equal(2)
			expect(table.find(list, a)).to.be.ok()
			expect(table.find(list, b)).to.be.ok()
		end)

		it("returns an empty list and nil when no part has the name", function()
			part("Other", slot)
			expect(#OfficeAnomalySenseUtils.namedParts(slot, "Emitter")).to.equal(0)
			expect(OfficeAnomalySenseUtils.firstPart(slot, "Emitter")).to.equal(nil)
		end)

		it("firstPart returns a part with the name", function()
			local emitter = part("Emitter", slot)
			expect(OfficeAnomalySenseUtils.firstPart(slot, "Emitter")).to.equal(emitter)
		end)
	end)

	describe("seeThrough", function()
		it("counts glass and mostly transparent parts as see-through", function()
			local glass = part("Glass", slot, { Material = Enum.Material.Glass, Transparency = 0 })
			local clear = part("Clear", slot, { Transparency = 0.5 })
			expect(OfficeAnomalySenseUtils.seeThrough(glass)).to.equal(true)
			expect(OfficeAnomalySenseUtils.seeThrough(clear)).to.equal(true)
		end)

		it("counts a solid opaque part as hiding", function()
			local wall = part("Wall", slot, { Material = Enum.Material.Concrete, Transparency = 0.2 })
			expect(OfficeAnomalySenseUtils.seeThrough(wall)).to.equal(false)
		end)
	end)

	describe("someoneNear", function()
		it("is false for a slot far from every player", function()
			part("Far", slot, { Position = Vector3.new(1e6, 1e6, 1e6) })
			slot.PrimaryPart = slot:FindFirstChild("Far")
			expect(OfficeAnomalySenseUtils.someoneNear(slot)).to.equal(false)
		end)
	end)

	describe("views", function()
		it("is off screen and out of view when the slot has no figure", function()
			part("FigureLegs", slot)
			local screen, view = OfficeAnomalySenseUtils.views(slot)
			expect(screen).to.equal(false)
			expect(view).to.equal(false)
		end)
	end)
end
