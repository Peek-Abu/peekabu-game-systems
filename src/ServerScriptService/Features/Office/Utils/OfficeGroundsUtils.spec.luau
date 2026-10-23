local ServerScriptService = game:GetService("ServerScriptService")

local OfficeGroundsUtils = require(script.Parent.OfficeGroundsUtils)
local OfficeConstants = require(ServerScriptService.Features.Office.Data.OfficeConstants)
local TruckVisual = require(ServerScriptService.Features.Depot.Data.DepotTruckVisualConstants)

local BAY = { id = "bay", name = "Loading bay", minX = 146, maxX = 190, minZ = -52, maxZ = -10 }
local RECEPTION = { id = "reception1", name = "Reception", minX = -38, maxX = -10, minZ = 138, maxZ = 166 }

local function near(a, b)
	return (a - b).Magnitude < 1e-3
end

return function()
	describe("grounds", function()
		it("is the yard then the car park, exactly", function()
			local grounds = OfficeGroundsUtils.grounds()
			expect(#grounds).to.equal(2)
			expect(grounds[1].id).to.equal("yard")
			expect(grounds[2].id).to.equal("carpark")
			expect(grounds[1].minX).to.equal(-164)
			expect(grounds[1].maxX).to.equal(322)
			expect(grounds[1].minZ).to.equal(-1921)
			expect(grounds[1].maxZ).to.equal(-1657)
			expect(grounds[2].minX).to.equal(-164)
			expect(grounds[2].maxX).to.equal(-44)
			expect(grounds[2].minZ).to.equal(-1657)
			expect(grounds[2].maxZ).to.equal(-1370)
		end)

		it("touches at z -1657 without overlapping", function()
			local yard, carpark = table.unpack(OfficeGroundsUtils.grounds())
			expect(yard.maxZ).to.equal(carpark.minZ)
		end)
	end)

	describe("truck", function()
		it("is the bed footprint centred on the pad, turned pi, inside the yard", function()
			local truck = OfficeGroundsUtils.truck()
			local bed = TruckVisual.BED_SIZE
			expect(truck.maxX - truck.minX).to.equal(bed.X)
			expect(truck.maxZ - truck.minZ).to.equal(bed.Z)
			expect((truck.minX + truck.maxX) / 2).to.equal(168)
			expect((truck.minZ + truck.maxZ) / 2).to.equal(-1876)
			expect(truck.yaw).to.equal(math.pi)
			local yard = OfficeGroundsUtils.grounds()[1]
			expect(truck.minX >= yard.minX and truck.maxX <= yard.maxX).to.equal(true)
			expect(truck.minZ >= yard.minZ and truck.maxZ <= yard.maxZ).to.equal(true)
		end)

		it("puts the clock at CLOCK_SIDE / CLOCK_BACK turned by the yaw", function()
			local truck = OfficeGroundsUtils.truck()
			expect(
				near(
					Vector2.new(truck.clockX, truck.clockZ),
					Vector2.new(168 - OfficeConstants.CLOCK_SIDE, -1876 + OfficeConstants.CLOCK_BACK)
				)
			).to.equal(true)
		end)
	end)

	describe("dockEntrance", function()
		it("has a solid exit on the bay's minZ wall at its centre", function()
			local entrance = OfficeGroundsUtils.dockEntrance(BAY)
			expect(entrance.id).to.equal("dock")
			expect(entrance.ground).to.equal("yard")
			expect(entrance.exit.a).to.equal("bay")
			expect(entrance.exit.b).to.equal("dock")
			expect(entrance.exit.x).to.equal(168)
			expect(entrance.exit.z).to.equal(-52)
			expect(entrance.exit.width).to.equal(8)
			expect(entrance.exit.kind).to.equal("solid")
			expect(entrance.outside.x).to.equal(168)
			expect(entrance.outside.z).to.equal(-1664)
			expect(entrance.outside.yaw).to.equal(0)
		end)
	end)

	describe("lobbyEntrance", function()
		it("has a glass exit on the reception's minX wall", function()
			local entrance = OfficeGroundsUtils.lobbyEntrance(RECEPTION, 152, 12)
			expect(entrance.id).to.equal("lobby")
			expect(entrance.ground).to.equal("carpark")
			expect(entrance.exit.a).to.equal("reception1")
			expect(entrance.exit.b).to.equal("lobby")
			expect(entrance.exit.x).to.equal(-38)
			expect(entrance.exit.z).to.equal(152)
			expect(entrance.exit.width).to.equal(12)
			expect(entrance.exit.kind).to.equal("glass")
			expect(entrance.outside.x).to.equal(-62)
			expect(entrance.outside.z).to.equal(-1448)
			expect(entrance.outside.yaw).to.equal(math.pi / 2)
		end)
	end)

	describe("insideFrame", function()
		it("steps INSIDE_STEP into the room, facing in", function()
			local dock = OfficeGroundsUtils.insideFrame(OfficeGroundsUtils.dockEntrance(BAY), BAY)
			expect(near(dock.Position, Vector3.new(168, 0, -48))).to.equal(true)
			expect(near(dock.LookVector, Vector3.new(0, 0, 1))).to.equal(true)
			local lobby =
				OfficeGroundsUtils.insideFrame(OfficeGroundsUtils.lobbyEntrance(RECEPTION, 152, 12), RECEPTION)
			expect(near(lobby.Position, Vector3.new(-34, 0, 152))).to.equal(true)
			expect(near(lobby.LookVector, Vector3.new(1, 0, 0))).to.equal(true)
		end)
	end)

	describe("outsideFrame", function()
		it("steps OUTSIDE_STEP out along the yaw, inside the ground", function()
			local entrance = OfficeGroundsUtils.dockEntrance(BAY)
			local frame = OfficeGroundsUtils.outsideFrame(entrance)
			expect(near(frame.Position, Vector3.new(168, 0, -1669))).to.equal(true)
			expect(near(frame.LookVector, Vector3.new(0, 0, -1))).to.equal(true)
			local yard = OfficeGroundsUtils.grounds()[1]
			expect(OfficeGroundsUtils.groundAt({ yard }, frame.Position.X, frame.Position.Z)).to.equal(yard)
			local lobby = OfficeGroundsUtils.outsideFrame(OfficeGroundsUtils.lobbyEntrance(RECEPTION, 152, 12))
			expect(near(lobby.Position, Vector3.new(-67, 0, -1448))).to.equal(true)
			expect(near(lobby.LookVector, Vector3.new(-1, 0, 0))).to.equal(true)
		end)
	end)

	describe("groundAt", function()
		it("finds the ground a point stands on", function()
			local grounds = OfficeGroundsUtils.grounds()
			expect(OfficeGroundsUtils.groundAt(grounds, 168, -1800).id).to.equal("yard")
			expect(OfficeGroundsUtils.groundAt(grounds, -100, -1450).id).to.equal("carpark")
			expect(OfficeGroundsUtils.groundAt(grounds, 168, -30)).to.equal(nil)
		end)
	end)

	describe("markers", function()
		it("names the arrival markers yard.spawn.N, in the yard, on the truck", function()
			local truck = OfficeGroundsUtils.truck()
			local markers = OfficeGroundsUtils.arrivalMarkers(truck)
			expect(#markers).to.equal(#OfficeConstants.ARRIVAL_OFFSETS)
			for index, marker in markers do
				expect(marker.id).to.equal(`yard.spawn.{index}`)
				expect(marker.room).to.equal("yard")
				expect(marker.kind).to.equal("spawn")
				expect(marker.x > truck.minX and marker.x < truck.maxX).to.equal(true)
				expect(marker.z > truck.minZ and marker.z < truck.maxZ).to.equal(true)
			end
		end)

		it("stands one bay shelf against each x wall, MARKER_MARGIN in, centred", function()
			local shelves = OfficeGroundsUtils.bayShelves(BAY)
			expect(#shelves).to.equal(2)
			expect(shelves[1].x).to.equal(BAY.minX + OfficeConstants.MARKER_MARGIN)
			expect(shelves[2].x).to.equal(BAY.maxX - OfficeConstants.MARKER_MARGIN)
			expect(shelves[1].z).to.equal(-31)
			expect(shelves[2].z).to.equal(-31)
			expect(shelves[1].kind).to.equal("shelf")
		end)

		it("turns each bay shelf to face into the room, by the kits' convention", function()
			-- The kits (OfficeKitRegistry) face a shelf on the maxX wall with +pi/2 (the storage closet's and the
			-- open office's right-wall shelves) and a minX-wall prop with -pi/2 (the closet's sconce).
			local shelves = OfficeGroundsUtils.bayShelves(BAY)
			expect(shelves[1].rotation).to.equal(-math.pi / 2)
			expect(shelves[2].rotation).to.equal(math.pi / 2)
		end)
	end)

	describe("exitFacades", function()
		it(
			"is each entrance's exit as a facade on its room: a solid exit one leaf, a glass exit a double door",
			function()
				local layout = {
					rooms = { BAY, RECEPTION },
					entrances = {
						OfficeGroundsUtils.dockEntrance(BAY),
						OfficeGroundsUtils.lobbyEntrance(RECEPTION, 152, 12),
					},
				}
				local facades = OfficeGroundsUtils.exitFacades(layout)
				expect(#facades).to.equal(2)
				expect(facades[1].room).to.equal("bay")
				expect(facades[1].x).to.equal(168)
				expect(facades[1].z).to.equal(-52)
				expect(facades[1].width).to.equal(8)
				expect(facades[1].kind).to.equal("stairwell")
				expect(facades[2].room).to.equal("reception1")
				expect(facades[2].x).to.equal(-38)
				expect(facades[2].z).to.equal(152)
				expect(facades[2].width).to.equal(12)
				expect(facades[2].kind).to.equal("entrance")
			end
		)

		it("is empty without entrances", function()
			expect(#OfficeGroundsUtils.exitFacades({ rooms = { BAY } })).to.equal(0)
		end)
	end)

	describe("problems", function()
		it("is empty without grounds and for the real outside", function()
			expect(#OfficeGroundsUtils.problems({ rooms = { BAY }, truck = OfficeGroundsUtils.truck() })).to.equal(0)
			local layout = {
				rooms = { BAY, RECEPTION },
				grounds = OfficeGroundsUtils.grounds(),
				truck = OfficeGroundsUtils.truck(),
				entrances = {
					OfficeGroundsUtils.dockEntrance(BAY),
					OfficeGroundsUtils.lobbyEntrance(RECEPTION, 152, 12),
				},
			}
			expect(#OfficeGroundsUtils.problems(layout)).to.equal(0)
		end)

		it("names a truck off the ground and an exit off its wall", function()
			local layout = {
				rooms = { BAY },
				grounds = OfficeGroundsUtils.grounds(),
				truck = { minX = 0, maxX = 5, minZ = 0, maxZ = 5, clockX = 1, clockZ = 1 },
				entrances = { OfficeGroundsUtils.dockEntrance(BAY) },
			}
			layout.entrances[1].exit.x = 100
			expect(#OfficeGroundsUtils.problems(layout)).to.equal(2)
		end)
	end)
end
