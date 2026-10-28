local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local DepotPlaceUtils = require(script.Parent.DepotPlaceUtils)

return function()
	describe("timecard hub authorization", function()
		local floor = { minX = 0, maxX = 96, minZ = 0, maxZ = 72 }
		local here = Vector3.new(40, 3, 26)
		it("allows hub players while another local crew works", function()
			expect(DepotPlaceUtils.canPunchTimecard(true, "running", false, here, floor, 22)).to.equal(true)
		end)
		it("rejects departed crew, wrong role, missing roots and outside native positions", function()
			expect(DepotPlaceUtils.canPunchTimecard(true, "running", true, here, floor, 22)).to.equal(false)
			expect(DepotPlaceUtils.canPunchTimecard(false, "lobby", false, here, floor, 22)).to.equal(false)
			expect(DepotPlaceUtils.canPunchTimecard(true, "lobby", false, nil, floor, 22)).to.equal(false)
			expect(DepotPlaceUtils.canPunchTimecard(true, "lobby", false, Vector3.new(2000, 3, 26), floor, 22)).to.equal(
				false
			)
			expect(DepotPlaceUtils.canPunchTimecard(true, "lobby", false, Vector3.new(40, 40, 26), floor, 22)).to.equal(
				false
			)
		end)
	end)

	describe("roles", function()
		it("maps both real ids to their roles", function()
			local roles = DepotPlaceUtils.roles(113354563835664, 222)
			expect(roles[DepotConstants.ROLE_DEPOT]).to.equal(113354563835664)
			expect(roles[DepotConstants.ROLE_SHIFT]).to.equal(222)
		end)

		it("keeps both roles placeholders while the shift id is unknown", function()
			local roles = DepotPlaceUtils.roles(113354563835664, 0)
			expect(roles[DepotConstants.ROLE_DEPOT]).to.equal(0)
			expect(roles[DepotConstants.ROLE_SHIFT]).to.equal(0)
		end)

		it("keeps both roles placeholders while the hub id is unknown", function()
			local roles = DepotPlaceUtils.roles(0, 222)
			expect(roles[DepotConstants.ROLE_DEPOT]).to.equal(0)
			expect(roles[DepotConstants.ROLE_SHIFT]).to.equal(0)
		end)

		it("refuses one real id for both places", function()
			expect(function()
				DepotPlaceUtils.roles(555, 555)
			end).to.throw()
		end)

		it("returns a frozen table", function()
			expect(table.isfrozen(DepotPlaceUtils.roles(1, 2))).to.equal(true)
		end)

		it("is what the constants register today", function()
			local roles = DepotPlaceUtils.roles(DepotConstants.HUB_PLACE_ID, DepotConstants.SHIFT_PLACE_ID)
			expect(roles[DepotConstants.ROLE_DEPOT]).to.be.a("number")
			expect(roles[DepotConstants.ROLE_SHIFT]).to.be.a("number")
		end)
	end)

	describe("depotOwnsSpawns", function()
		it("is the depot's job in a hub-only server", function()
			expect(DepotPlaceUtils.depotOwnsSpawns(true, false)).to.equal(true)
		end)

		it("stays Shift's job when both roles run here (Studio, local mode)", function()
			expect(DepotPlaceUtils.depotOwnsSpawns(true, true)).to.equal(false)
		end)

		it("is never the depot's job in a shift-only server", function()
			expect(DepotPlaceUtils.depotOwnsSpawns(false, true)).to.equal(false)
			expect(DepotPlaceUtils.depotOwnsSpawns(false, false)).to.equal(false)
		end)
	end)
end
