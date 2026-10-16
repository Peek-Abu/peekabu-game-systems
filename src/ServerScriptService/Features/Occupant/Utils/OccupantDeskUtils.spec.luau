local OccupantDeskUtils = require(script.Parent.OccupantDeskUtils)

local function desk(id, x, z, spotId)
	return { id = id, seat = CFrame.new(x, 4.6, z), front = true, spotId = spotId }
end

local DESKS = {
	desk("near", 30, 0, "s1"),
	desk("close", 5, 0, "s2"),
	desk("far", 120, 0, "s3"),
	desk("far2", 0, 140, "s4"),
}

local function input(extra)
	local value = {
		crew = { Vector3.new(0, 0, 0) },
		occupied = {},
		last = nil,
		near = true,
		roll = 0,
	}
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

return function()
	describe("pick", function()
		it("near the crew: the desk in the band closest to the ideal distance", function()
			local chosen = OccupantDeskUtils.pick(DESKS, input())
			expect(chosen.id).to.equal("near")
		end)
		it("elsewhere: a desk far from everyone, by roll", function()
			expect(OccupantDeskUtils.pick(DESKS, input({ near = false, roll = 0 })).id).to.equal("far")
			expect(OccupantDeskUtils.pick(DESKS, input({ near = false, roll = 0.99 })).id).to.equal("far2")
		end)
		it("never a desk someone hides under, nor the last one, nor one a player stands by", function()
			local chosen = OccupantDeskUtils.pick(DESKS, input({ occupied = { s1 = true } }))
			expect(chosen == nil or chosen.id ~= "near").to.equal(true)
			chosen = OccupantDeskUtils.pick(DESKS, input({ last = "near" }))
			expect(chosen == nil or chosen.id ~= "near").to.equal(true)
			for _ = 1, 4 do
				local pick = OccupantDeskUtils.pick(DESKS, input({ near = false, roll = 0.5 }))
				expect(pick.id).never.to.equal("close")
			end
		end)
		it("falls back to any free desk when the band is empty", function()
			local chosen = OccupantDeskUtils.pick({ desk("far", 120, 0, "s3") }, input())
			expect(chosen.id).to.equal("far")
		end)
		it("skips desks in the bay", function()
			local bay = { min = Vector3.new(100, -5, -10), max = Vector3.new(140, 20, 10) }
			local chosen = OccupantDeskUtils.pick({ desk("far", 120, 0, "s3") }, input({ bay = bay }))
			expect(chosen).to.equal(nil)
		end)
		it("is nil with no desks", function()
			expect(OccupantDeskUtils.pick({}, input())).to.equal(nil)
		end)
	end)

	describe("seatFrame", function()
		it("stands the root over the chair at standing height, facing the desk", function()
			local deskFrame = CFrame.new(10, 1.5, 10)
			local seat, front = OccupantDeskUtils.seatFrame(Vector3.new(10, 1.8, 6.95), deskFrame, 0, 4.6)
			expect(seat.Position).to.equal(Vector3.new(10, 4.6, 6.95))
			expect((seat.LookVector - Vector3.new(0, 0, 1)).Magnitude < 1e-4).to.equal(true)
			-- The desk's front (its knee-hole) is its -Z: this chair sits there.
			expect(front).to.equal(true)
		end)
		it("is not on the front for a chair behind the desk", function()
			local _, front = OccupantDeskUtils.seatFrame(Vector3.new(10, 1.8, 13.05), CFrame.new(10, 1.5, 10), 0, 4.6)
			expect(front).to.equal(false)
		end)
	end)

	describe("fallbackChair", function()
		it("is 3.05 studs in front of the desk on the floor", function()
			local point = OccupantDeskUtils.fallbackChair(CFrame.new(0, 1.5, 0))
			expect((point - Vector3.new(0, 1.5, -3.05)).Magnitude < 1e-4).to.equal(true)
		end)
	end)

	describe("standPoint", function()
		it("is the gap off the front edge and to the side, on the floor", function()
			local point = OccupantDeskUtils.standPoint(CFrame.new(0, 1.5, 0), Vector3.new(5, 3, 3), 1.6, 1.9)
			expect((point - Vector3.new(1.9, 0, -3.1)).Magnitude < 1e-4).to.equal(true)
		end)
	end)

	describe("sitBack", function()
		it("moves the seat back, away from the desk", function()
			local seat = CFrame.lookAt(Vector3.new(0, 4.6, 0), Vector3.new(0, 4.6, -5))
			local back = OccupantDeskUtils.sitBack(seat, 0.7)
			expect((back.Position - Vector3.new(0, 4.6, 0.7)).Magnitude < 1e-4).to.equal(true)
		end)
	end)

	describe("facing", function()
		it("looks from a point at a target on the same height", function()
			local frame = OccupantDeskUtils.facing(Vector3.new(0, 4.6, 0), Vector3.new(0, 1, -10))
			expect(frame.Position).to.equal(Vector3.new(0, 4.6, 0))
			expect((frame.LookVector - Vector3.new(0, 0, -1)).Magnitude < 1e-4).to.equal(true)
		end)
	end)
end
