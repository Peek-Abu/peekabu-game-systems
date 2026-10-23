local OfficeConstants = require(script.Parent.Parent.Data.OfficeConstants)
local OfficeShellUtils = require(script.Parent.OfficeShellUtils)

local H = OfficeConstants.WALL_HEIGHT
local S = OfficeConstants.SHELL

local function named(boxes, material, name)
	local out = {}
	for _, box in boxes do
		if box.material == material and (name == nil or box.name == name) then
			table.insert(out, box)
		end
	end
	return out
end

-- Axis-aligned footprint { minX, maxX, minZ, maxZ } of a box (all shell boxes are unrotated).
local function footprint(box)
	local p = box.cframe.Position
	return {
		minX = p.X - box.size.X / 2,
		maxX = p.X + box.size.X / 2,
		minZ = p.Z - box.size.Z / 2,
		maxZ = p.Z + box.size.Z / 2,
	}
end

local function straight()
	return OfficeShellUtils.wall({ x1 = 0, z1 = 0, x2 = 20, z2 = 0 }, 0.5, 0.5)
end

return function()
	describe("OfficeShellUtils", function()
		it("a wall is two slabs from -1 to WALL_HEIGHT + 1", function()
			local slabs = named(straight(), "plaster")
			expect(#slabs).to.equal(2)
			local sides = {}
			for _, slab in slabs do
				expect(slab.size.X).to.be.near(21, 1e-6)
				expect(slab.size.Y).to.be.near(H + 2, 1e-6)
				expect(slab.size.Z).to.be.near(0.5, 1e-6)
				expect(slab.cframe.Position.X).to.be.near(10, 1e-6)
				expect(slab.cframe.Position.Y).to.be.near(H / 2, 1e-6)
				expect(slab.collide).to.equal(true)
				table.insert(sides, slab.cframe.Position.Z)
			end
			table.sort(sides)
			expect(sides[1]).to.be.near(-0.25, 1e-6)
			expect(sides[2]).to.be.near(0.25, 1e-6)
		end)

		it("trim on both faces", function()
			local boxes = straight()
			local wainscot = named(boxes, "oak")
			local rails = named(boxes, "rail")
			local skirts = named(boxes, "skirt")
			expect(#wainscot).to.equal(2)
			expect(#rails).to.equal(2)
			expect(#skirts).to.equal(2)
			for _, box in wainscot do
				expect(box.size.Y).to.be.near(3, 1e-6)
				expect(box.size.Z).to.be.near(0.3, 1e-6)
				expect(math.abs(box.cframe.Position.Z) + box.size.Z / 2).to.be.near(0.8, 1e-6)
				expect(box.collide).to.equal(false)
			end
			for _, box in rails do
				expect(box.size.Y).to.be.near(0.25, 1e-6)
				expect(box.size.Z).to.be.near(0.5, 1e-6)
				expect(box.cframe.Position.Y + box.size.Y / 2).to.be.near(3.25, 1e-6)
				expect(box.collide).to.equal(false)
			end
			for _, box in skirts do
				expect(box.size.Y).to.be.near(0.6, 1e-6)
				expect(box.size.Z).to.be.near(0.4, 1e-6)
				expect(math.abs(box.cframe.Position.Z) + box.size.Z / 2).to.be.near(0.9, 1e-6)
				expect(box.collide).to.equal(false)
			end
		end)

		it("trim closes inside corners", function()
			-- An L: a wall along x and a wall along z meeting at (0, 0); the inside is +x, +z.
			local alongX = OfficeShellUtils.wall({ x1 = 0, z1 = 0, x2 = 20, z2 = 0 }, 0.5, 0.5)
			local alongZ = OfficeShellUtils.wall({ x1 = 0, z1 = 0, x2 = 0, z2 = 20 }, 0.5, 0.5)
			local function inside(boxes, pick)
				for _, box in named(boxes, "oak") do
					if pick(footprint(box)) then
						return footprint(box)
					end
				end
			end
			local a = inside(alongX, function(f)
				return f.minZ > 0
			end)
			local b = inside(alongZ, function(f)
				return f.minX > 0
			end)
			-- Overlap in both axes: no gap at the corner.
			expect(a.minX < b.maxX and b.minX < a.maxX).to.equal(true)
			expect(a.minZ < b.maxZ and b.minZ < a.maxZ).to.equal(true)
			-- Neither reaches past the other wall's outer face (-0.5).
			expect(a.minX >= -0.5 - 1e-6).to.equal(true)
			expect(b.minZ >= -0.5 - 1e-6).to.equal(true)
		end)

		it("trim stops flush at a door", function()
			local boxes = OfficeShellUtils.wall({ x1 = 0, z1 = 0, x2 = 20, z2 = 0 }, 0, 0.5)
			for _, box in named(boxes, "oak") do
				expect(footprint(box).minX).to.be.near(0, 1e-6)
			end
			for _, box in named(boxes, "plaster") do
				expect(footprint(box).minX).to.be.near(0, 1e-6)
			end
		end)

		it("closes outer corners once: the run along X wraps the corner, the run along Z butts against it", function()
			local walls = {
				{ x1 = 0, z1 = 0, x2 = 20, z2 = 0 },
				{ x1 = 0, z1 = 0, x2 = 0, z2 = 20 },
			}
			local outerX = OfficeShellUtils.outerSide(walls, 0, 0, true)
			local outerZ = OfficeShellUtils.outerSide(walls, 0, 0, false)
			expect(outerX).to.equal(-1)
			expect(outerZ).to.equal(-1)
			local alongX = OfficeShellUtils.wall(walls[1], 0.5, 0.5, { outerFirst = outerX })
			local alongZ = OfficeShellUtils.wall(walls[2], 0.5, 0.5, { outerFirst = outerZ })
			for _, spec in { { "oak", 0.3 }, { "rail", 0.5 }, { "skirt", 0.4 } } do
				local material, proud = spec[1], spec[2]
				local a, b, innerA, innerB
				for _, box in named(alongX, material) do
					local f = footprint(box)
					if f.minZ < 0 then
						a = f
					else
						innerA = f
					end
				end
				for _, box in named(alongZ, material) do
					local f = footprint(box)
					if f.minX < 0 then
						b = f
					else
						innerB = f
					end
				end
				-- The X run wraps: it reaches the slab end (-0.5) plus its depth, covering the corner square.
				expect(a.minX).to.be.near(-0.5 - proud, 1e-6)
				expect(a.minZ).to.be.near(-0.5 - proud, 1e-6)
				-- The Z run stops at the slab end, flush against the X run's back: its end meets that face.
				expect(b.minZ).to.be.near(-0.5, 1e-6)
				expect(b.minZ).to.be.near(a.maxZ, 1e-6)
				expect(b.minX).to.be.near(a.minX, 1e-6)
				-- No overlapping volume (no coplanar faces to flicker) and no gap: the boxes touch in Z and share X.
				local overlapX = math.min(a.maxX, b.maxX) - math.max(a.minX, b.minX)
				local overlapZ = math.min(a.maxZ, b.maxZ) - math.max(a.minZ, b.minZ)
				expect(overlapX > 0).to.equal(true)
				expect(overlapZ <= 1e-6).to.equal(true)
				expect(overlapZ >= -1e-6).to.equal(true)
				-- The inner faces keep today's reach.
				expect(innerA.minX).to.be.near(-proud, 1e-6)
				expect(innerB.minZ).to.be.near(-proud, 1e-6)
			end
		end)

		it("leaves a T-junction end unchanged, and names no outer face there", function()
			local stem = { x1 = 0, z1 = 0, x2 = 20, z2 = 0 }
			local through = { x1 = 0, z1 = -10, x2 = 0, z2 = 10 }
			expect(OfficeShellUtils.outerSide({ stem, through }, 0, 0, true)).to.equal(nil)
			expect(OfficeShellUtils.outerSide({ stem }, 0, 0, true)).to.equal(nil)
			local plain = OfficeShellUtils.wall(stem, 0.5, 0.5)
			local same = OfficeShellUtils.wall(stem, 0.5, 0.5, { gaps = {} })
			expect(#same).to.equal(#plain)
			for index, box in plain do
				expect(footprint(same[index]).minX).to.be.near(footprint(box).minX, 1e-6)
				expect(footprint(same[index]).maxX).to.be.near(footprint(box).maxX, 1e-6)
			end
		end)

		it("breaks the trim at a facade on its face only, and the plaster stays whole", function()
			local gap = OfficeShellUtils.facadeGap({ room = "a", x = 10, z = 0, width = 6, kind = "entrance" }, "minZ")
			expect(gap.side).to.equal(1)
			expect(gap.from).to.be.near(7, 1e-6)
			expect(gap.to).to.be.near(13, 1e-6)
			local boxes = OfficeShellUtils.wall({ x1 = 0, z1 = 0, x2 = 20, z2 = 0 }, 0.5, 0.5, { gaps = { gap } })
			expect(#named(boxes, "plaster")).to.equal(2)
			for _, slab in named(boxes, "plaster") do
				expect(slab.size.X).to.be.near(21, 1e-6)
			end
			for _, material in { "oak", "rail", "skirt" } do
				local onFace, other = 0, 0
				for _, box in named(boxes, material) do
					local f = footprint(box)
					if f.minZ > 0 then
						onFace += 1
						expect(f.maxX <= 7 + 1e-6 or f.minX >= 13 - 1e-6).to.equal(true)
					else
						other += 1
						expect(f.minX < 7 and f.maxX > 13).to.equal(true)
					end
				end
				expect(onFace).to.equal(2)
				expect(other).to.equal(1)
			end
		end)

		it("gives a facade an oak casing of two jambs and a head on its face", function()
			local facade = { room = "a", x = 10, z = 0, width = 6, kind = "entrance" }
			local boxes = OfficeShellUtils.facadeCasing(facade, "minZ")
			expect(#boxes).to.equal(3)
			local jambs, heads = 0, 0
			for _, box in boxes do
				expect(box.material).to.equal("oak")
				local f = footprint(box)
				expect(f.minZ).to.be.near(0, 1e-6)
				expect(f.maxZ).to.be.near(OfficeConstants.WALL_THICKNESS / 2 + S.casing, 1e-6)
				if box.name == "Jamb" then
					jambs += 1
					expect(box.size.X).to.be.near(S.casing, 1e-6)
					expect(box.size.Y).to.be.near(OfficeConstants.DOOR_HEIGHT, 1e-6)
				elseif box.name == "Head" then
					heads += 1
					expect(box.size.X).to.be.near(6, 1e-6)
					expect(box.cframe.Position.Y + box.size.Y / 2).to.be.near(OfficeConstants.DOOR_HEIGHT, 1e-6)
				end
			end
			expect(jambs).to.equal(2)
			expect(heads).to.equal(1)
			-- On a max edge the casing is on the -Z face.
			local back =
				OfficeShellUtils.facadeCasing({ room = "a", x = 10, z = 20, width = 6, kind = "stairwell" }, "maxZ")
			expect(footprint(back[1]).maxZ).to.be.near(20, 1e-6)
		end)

		it("casing", function()
			local door = { a = "a", b = "b", x = 10, z = 0, width = 6.8, kind = "solid" }
			local boxes = OfficeShellUtils.doorCasing(door, "minZ")
			local oak = named(boxes, "oak")
			expect(#oak).to.equal(3)
			for _, piece in oak do
				expect(piece.collide).to.equal(true)
			end
			local jambs = {}
			local head
			for _, box in oak do
				if box.size.Y > 1 then
					table.insert(jambs, box)
				else
					head = box
				end
			end
			expect(#jambs).to.equal(2)
			local left = jambs[1].cframe.Position.X < jambs[2].cframe.Position.X and jambs[1] or jambs[2]
			local right = left == jambs[1] and jambs[2] or jambs[1]
			local clear = (right.cframe.Position.X - right.size.X / 2) - (left.cframe.Position.X + left.size.X / 2)
			expect(clear).to.be.near(6.1, 1e-6)
			expect(head.cframe.Position.Y - head.size.Y / 2).to.be.near(OfficeConstants.DOOR_HEIGHT - 0.35, 1e-6)
			expect(head.size.Z).to.be.near(OfficeConstants.WALL_THICKNESS + 2 * S.casing, 1e-6)
		end)

		it("a wide open archway gets pilasters", function()
			local door = { a = "a", b = "b", x = 10, z = 0, width = 14 }
			local boxes = OfficeShellUtils.doorCasing(door, "minZ")
			expect(#named(boxes, "plaster")).to.equal(2)
			expect(#named(boxes, "oak")).to.equal(0)
			for _, box in boxes do
				expect(box.size.X).to.be.near(0.6, 1e-6)
			end
			local narrow = { a = "a", b = "b", x = 10, z = 0, width = 6 }
			expect(#OfficeShellUtils.doorCasing(narrow, "minZ")).to.equal(0)
		end)

		it("framed glass", function()
			local boxes = OfficeShellUtils.glassPane({ x1 = 0, z1 = 0, x2 = 22, z2 = 0 })
			expect(#named(boxes, "frame", "FrameEnd")).to.equal(2)
			expect(#named(boxes, "frame", "BaseRail")).to.equal(1)
			expect(named(boxes, "frame", "BaseRail")[1].size.Y).to.be.near(0.35, 1e-6)
			-- Every gap between neighbouring uprights (end frames and mullions) is at most 6.
			local uprights = {}
			for _, box in boxes do
				if box.material == "frame" and (box.name == "FrameEnd" or box.name == "Mullion") then
					table.insert(uprights, footprint(box))
				end
			end
			table.sort(uprights, function(p, q)
				return p.minX < q.minX
			end)
			expect(#uprights > 2).to.equal(true)
			for i = 2, #uprights do
				expect(uprights[i].minX - uprights[i - 1].maxX <= 6 + 1e-6).to.equal(true)
			end
			local glass = named(boxes, "glass")
			expect(#glass).to.equal(1)
			expect(glass[1].collide).to.equal(true)
			expect(glass[1].cframe.Position.Y + glass[1].size.Y / 2).to.be.near(12.5, 1e-6)
		end)

		it("ceiling grid every 4", function()
			local room = { id = "r", name = "r", minX = 0, maxX = 12, minZ = 0, maxZ = 12 }
			local boxes = OfficeShellUtils.ceiling(room)
			expect(#named(boxes, "ceiling")).to.equal(1)
			expect(named(boxes, "ceiling")[1].collide).to.equal(true)
			local strips = named(boxes, "grid")
			expect(#strips).to.equal(4)
			for _, strip in strips do
				expect(math.min(strip.size.X, strip.size.Z)).to.be.near(0.15, 1e-6)
				expect(strip.size.Y).to.be.near(0.08, 1e-6)
				expect(strip.collide).to.equal(false)
				expect(strip.cframe.Position.Y).to.be.near(H - 0.04, 1e-6)
			end
		end)
	end)
end
