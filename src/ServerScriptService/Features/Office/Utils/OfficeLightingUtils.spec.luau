local OfficeConstants = require(script.Parent.Parent.Data.OfficeConstants)
local OfficeLightingUtils = require(script.Parent.OfficeLightingUtils)

local function room(minX, maxX, minZ, maxZ)
	return { id = "r", name = "r", minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ }
end

local function countLit(panels)
	local n = 0
	for _, panel in panels do
		if panel.lit then
			n += 1
		end
	end
	return n
end

return function()
	describe("OfficeLightingUtils", function()
		it("hall panels every 8, all lit", function()
			local plan = OfficeLightingUtils.roomLights(room(0, 80, 0, 14), "hallway")
			expect(#plan.panels).to.equal(10)
			for i, panel in plan.panels do
				expect(panel.lit).to.equal(true)
				expect(panel.rotated).to.equal(false)
				expect(panel.z).to.equal(7)
				expect(panel.x).to.equal(4 + (i - 1) * 8)
				expect(panel.brightness).to.equal(0.2)
			end
		end)

		it("hall fills alternate sides every 16 at Y 5", function()
			local r = room(0, 80, 0, 14)
			local plan = OfficeLightingUtils.roomLights(r, "hallway")
			local spots = OfficeLightingUtils.sconceSpots(r)
			expect(#plan.fills).to.equal(5)
			expect(#spots).to.equal(5)
			for i, fill in plan.fills do
				expect(fill.position.X).to.equal(8 + (i - 1) * 16)
				expect(fill.position.Y).to.equal(5)
				expect(fill.brightness).to.equal(1.3)
				expect(fill.range).to.equal(12)
				local minSide = i % 2 == 1
				expect(fill.position.Z).to.equal(if minSide then 3 else 11)
				expect(spots[i].side).to.equal(if minSide then "minZ" else "maxZ")
				expect(spots[i].x).to.equal(fill.position.X)
				expect(spots[i].z).to.equal(if minSide then 0 else 14)
			end
		end)

		it("z-run panels are rotated", function()
			local plan = OfficeLightingUtils.roomLights(room(0, 10, 0, 64), "hallway")
			expect(#plan.panels).to.equal(8)
			for _, panel in plan.panels do
				expect(panel.rotated).to.equal(true)
				expect(panel.x).to.equal(5)
			end
		end)

		it("room panels ~2/3 lit, the spike pattern", function()
			local plan = OfficeLightingUtils.roomLights(room(0, 60, 0, 44), "pods")
			expect(#plan.panels).to.equal(20)
			expect(countLit(plan.panels)).to.equal(13)
			for _, panel in plan.panels do
				expect(panel.brightness).to.equal(0.22)
			end
			local storage = OfficeLightingUtils.roomLights(room(0, 12, 0, 12), "storage")
			expect(#storage.panels).to.equal(1)
			expect(storage.panels[1].lit).to.equal(true)
			expect(storage.panels[1].brightness).to.equal(0.15)
		end)

		it("deterministic", function()
			local a = OfficeLightingUtils.roomLights(room(0, 60, 0, 44), "pods")
			local b = OfficeLightingUtils.roomLights(room(0, 60, 0, 44), "pods")
			expect(#a.panels).to.equal(#b.panels)
			expect(#a.fills).to.equal(#b.fills)
			for i, panel in a.panels do
				expect(panel.x).to.equal(b.panels[i].x)
				expect(panel.z).to.equal(b.panels[i].z)
				expect(panel.lit).to.equal(b.panels[i].lit)
			end
			for i, fill in a.fills do
				expect(fill.position).to.equal(b.fills[i].position)
			end
		end)

		it("only fills cast shadows; colours are the warm pair", function()
			local plan = OfficeLightingUtils.roomLights(room(0, 60, 0, 44), "pods")
			expect(#plan.fills > 0).to.equal(true)
			for _, fill in plan.fills do
				expect(fill.shadows).to.equal(true)
				expect(fill.color).to.equal(OfficeConstants.FILL_COLOR)
				expect(fill.position.Y).to.equal(4)
			end
		end)

		it("accentFor", function()
			local accent = OfficeLightingUtils.accentFor("ScreenLight")
			expect(accent).to.be.ok()
			expect(accent.brightness).to.equal(0.7)
			expect(accent.range).to.equal(6)
			expect(OfficeLightingUtils.accentFor("NopeLight")).to.equal(nil)
		end)

		it("unknown room type falls back to pods", function()
			local a = OfficeLightingUtils.roomLights(room(0, 60, 0, 44), "mystery")
			local b = OfficeLightingUtils.roomLights(room(0, 60, 0, 44), "pods")
			expect(a.panels[1].brightness).to.equal(b.panels[1].brightness)
			expect(a.fills[1].brightness).to.equal(b.fills[1].brightness)
			local c = OfficeLightingUtils.roomLights(room(0, 60, 0, 44), nil)
			expect(c.fills[1].range).to.equal(b.fills[1].range)
		end)
	end)
end
