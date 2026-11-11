local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotSpotRules = require(script.Parent.DepotSpotRules)
local DepotSpotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotSpotConstants)

return function()
	describe("spots", function()
		it("lists every spot once, each with its own kind", function()
			local seen = {}
			for _, spot in DepotSpotRules.spots() do
				expect(seen[spot]).to.equal(nil)
				seen[spot] = true
				expect(DepotSpotConstants.KINDS[spot]).to.be.ok()
			end
			for spot in DepotSpotConstants.KINDS do
				expect(seen[spot]).to.equal(true)
			end
		end)
	end)

	describe("spotOf", function()
		it("names the spot of each hub kind and nothing else", function()
			for spot, kind in DepotSpotConstants.KINDS do
				expect(DepotSpotRules.spotOf(kind)).to.equal(spot)
			end
			expect(DepotSpotRules.spotOf("depot-board")).to.equal(nil)
			expect(DepotSpotRules.spotOf("")).to.equal(nil)
		end)
	end)

	describe("open", function()
		it("opens every plain spot", function()
			for _, spot in { "shop", "coffee", "crew", "rank", "radio", "bell", "locker" } do
				local opened = DepotSpotRules.open(spot, nil)
				expect(opened).to.be.ok()
				expect(opened.spot).to.equal(spot)
				expect(opened.employee).to.equal("")
			end
		end)

		it("opens a standee only on a real employee", function()
			local opened = DepotSpotRules.open("standee", "Cappy")
			expect(opened).to.be.ok()
			expect(opened.employee).to.equal("Cappy")
			expect(DepotSpotRules.open("standee", nil)).to.equal(nil)
			expect(DepotSpotRules.open("standee", "Nobody")).to.equal(nil)
			expect(DepotSpotRules.open("standee", 42)).to.equal(nil)
		end)
	end)

	describe("decode", function()
		it("turns a sent spot back into one the client opens, and drops anything else", function()
			local opened = DepotSpotRules.decode({ spot = "standee", employee = "Prickles" })
			expect(opened.spot).to.equal("standee")
			expect(opened.employee).to.equal("Prickles")
			expect(DepotSpotRules.decode({ spot = "jukebox", employee = "" })).to.equal(nil)
			expect(DepotSpotRules.decode({ spot = "standee", employee = "Nobody" })).to.equal(nil)
		end)
	end)

	describe("nextStation", function()
		it("moves to the next station and wraps round", function()
			local count = #DepotSpotConstants.STATIONS
			expect(DepotSpotRules.nextStation(1)).to.equal(if count > 1 then 2 else 1)
			expect(DepotSpotRules.nextStation(count)).to.equal(1)
			expect(DepotSpotRules.nextStation(0)).to.equal(1)
			expect(DepotSpotRules.nextStation(99)).to.equal(1)
		end)
	end)

	describe("bellReady", function()
		it("rings a fresh bell, then rests for the cooldown", function()
			expect(DepotSpotRules.bellReady(nil, 100)).to.equal(true)
			expect(DepotSpotRules.bellReady(100, 100 + DepotSpotConstants.BELL_COOLDOWN - 0.1)).to.equal(false)
			expect(DepotSpotRules.bellReady(100, 100 + DepotSpotConstants.BELL_COOLDOWN)).to.equal(true)
		end)
	end)

	describe("driveGap", function()
		it("waits between the shortest and the longest gap", function()
			local drive = DepotSpotConstants.DRIVE_BY
			expect(DepotSpotRules.driveGap(0)).to.equal(drive.MIN_GAP)
			expect(DepotSpotRules.driveGap(1)).to.equal(drive.MAX_GAP)
			expect(DepotSpotRules.driveGap(-5)).to.equal(drive.MIN_GAP)
			expect(DepotSpotRules.driveGap(0.5)).to.equal((drive.MIN_GAP + drive.MAX_GAP) / 2)
		end)
	end)

	describe("road", function()
		it("orders the road's points and needs two at least", function()
			local road = DepotSpotRules.road({
				{ order = 2, position = Vector3.new(10, 0, 0) },
				{ order = 1, position = Vector3.new(0, 0, 0) },
				{ order = 3, position = Vector3.new(20, 0, 5) },
			})
			expect(#road).to.equal(3)
			expect(road[1]).to.equal(Vector3.new(0, 0, 0))
			expect(road[3]).to.equal(Vector3.new(20, 0, 5))
			expect(DepotSpotRules.road({ { order = 1, position = Vector3.new() } })).to.equal(nil)
		end)

		it("refuses missing or repeated orders", function()
			expect(DepotSpotRules.road({
				{ order = 1, position = Vector3.new() },
				{ order = 1, position = Vector3.new(1, 0, 0) },
			})).to.equal(nil)
			expect(DepotSpotRules.road({
				{ order = 1, position = Vector3.new() },
				{ order = "two", position = Vector3.new(1, 0, 0) },
			})).to.equal(nil)
		end)
	end)

	describe("roadLength", function()
		it("adds up the legs", function()
			expect(DepotSpotRules.roadLength({ Vector3.new(0, 0, 0), Vector3.new(3, 0, 4), Vector3.new(3, 0, 14) })).to.equal(
				15
			)
		end)
	end)

	describe("along", function()
		it("finds the point and heading a distance down the road", function()
			local road = { Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), Vector3.new(10, 0, 10) }
			local at, heading = DepotSpotRules.along(road, 5)
			expect(at).to.equal(Vector3.new(5, 0, 0))
			expect(heading).to.equal(Vector3.new(1, 0, 0))
			at, heading = DepotSpotRules.along(road, 15)
			expect(at).to.equal(Vector3.new(10, 0, 5))
			expect(heading).to.equal(Vector3.new(0, 0, 1))
			at = DepotSpotRules.along(road, 99)
			expect(at).to.equal(Vector3.new(10, 0, 10))
		end)
	end)
	describe("bellSwing", function()
		local swing = DepotSpotConstants.BELL_SWING
		it("starts still, swings out, dies down and stops at the end", function()
			expect(DepotSpotRules.bellSwing(0)).to.equal(0)
			local peak = 0
			for t = 0, swing.SECONDS, 0.02 do
				peak = math.max(peak, math.abs(DepotSpotRules.bellSwing(t)))
			end
			expect(peak > swing.DEGREES * 0.5).to.equal(true)
			expect(peak <= swing.DEGREES + 1e-6).to.equal(true)
			expect(math.abs(DepotSpotRules.bellSwing(swing.SECONDS * 0.9)) < swing.DEGREES * 0.25).to.equal(true)
			expect(DepotSpotRules.bellSwing(swing.SECONDS)).to.equal(0)
			expect(DepotSpotRules.bellSwing(swing.SECONDS + 5)).to.equal(0)
			expect(DepotSpotRules.bellSwing(-1)).to.equal(0)
		end)
	end)

	describe("noteRate", function()
		it("plays notes on a station with music and none on a quiet one", function()
			for _, station in DepotSpotConstants.STATIONS do
				local rate = DepotSpotRules.noteRate(station)
				if station.track == nil then
					expect(rate).to.equal(0)
				else
					expect(rate > 0).to.equal(true)
				end
			end
		end)
	end)
end
