local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotTopperRules)
local TOPPER = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotSpotConstants).TOPPER

return function()
	describe("DepotTopperRules.lane", function()
		it("lays the lane flat on the floor ahead of the anchor, along its facing", function()
			-- An anchor up in the air at (10, 8, 0) facing +Z (readers stand at +Z).
			local anchor = CFrame.lookAt(Vector3.new(10, 8, 0), Vector3.new(10, 8, 5))
			local at, size = Rules.lane(anchor, 1, 2, 6)
			expect(size.Z).to.be.near(6, 1e-6)
			expect(size.X).to.be.near(TOPPER.LANE.WIDTH, 1e-6)
			-- Centre: 2 studs ahead, then half its length: z = 5; on the floor (1) plus its lift and half thickness.
			expect(at.Position.X).to.be.near(10, 1e-6)
			expect(at.Position.Z).to.be.near(5, 1e-6)
			expect(at.Position.Y).to.be.near(1 + TOPPER.LANE.LIFT + TOPPER.LANE.THICKNESS / 2, 1e-6)
			-- It runs away from the station (its LookVector is the anchor's facing) and lies flat.
			expect(at.LookVector:Dot(Vector3.new(0, 0, 1))).to.be.near(1, 1e-6)
			expect(at.UpVector:Dot(Vector3.yAxis)).to.be.near(1, 1e-6)
		end)
		it("ignores a tilted anchor's pitch (the lane stays flat)", function()
			local anchor = CFrame.lookAt(Vector3.zero, Vector3.new(0, -1, 1))
			local at = Rules.lane(anchor, 0, 1, 4)
			expect(at.UpVector:Dot(Vector3.yAxis)).to.be.near(1, 1e-6)
			expect(at.Position.Z).to.be.near(3, 1e-6)
		end)
		it("uses the defaults when the anchor gives none", function()
			local anchor = CFrame.lookAt(Vector3.zero, Vector3.new(1, 0, 0))
			local at, size = Rules.lane(anchor, 0, nil, nil)
			expect(size.Z).to.be.near(TOPPER.LANE.LENGTH, 1e-6)
			expect(at.Position.X).to.be.near(TOPPER.LANE.START + TOPPER.LANE.LENGTH / 2, 1e-6)
		end)
	end)

	describe("DepotTopperRules.chevrons", function()
		it("lays two bars per chevron flat on the lane, each pointing back at the station", function()
			-- A lane running away from a station at the origin along +Z (its LookVector).
			local laneAt, laneSize = Rules.lane(CFrame.lookAt(Vector3.zero, Vector3.zAxis), 0, 2, 6)
			local bars, barSize = Rules.chevrons(laneAt, laneSize)
			expect(#bars).to.equal(2 * TOPPER.LANE.CHEVRONS)
			local top = laneAt.Position.Y + laneSize.Y / 2
			for index = 1, #bars, 2 do
				local left, right = bars[index], bars[index + 1]
				for _, bar in { left, right } do
					-- Flat, sitting on the lane's top, inside the lane.
					expect(bar.UpVector:Dot(Vector3.yAxis)).to.be.near(1, 1e-6)
					expect(bar.Position.Y - barSize.Y / 2).to.be.near(top, 1e-3)
					expect(math.abs(bar.Position.X) < laneSize.X / 2).to.equal(true)
					-- The bar's near end (towards -Z, the station) sits nearer the lane's middle than its far end:
					-- the two bars meet at a point aimed at the station.
					local near = bar.Position - bar.LookVector * (barSize.Z / 2)
					local far = bar.Position + bar.LookVector * (barSize.Z / 2)
					if near.Z > far.Z then
						near, far = far, near
					end
					expect(math.abs(near.X) < math.abs(far.X)).to.equal(true)
				end
				-- The pair is a mirror image across the lane's middle.
				expect(left.Position.X).to.be.near(-right.Position.X, 1e-6)
				expect(left.Position.Z).to.be.near(right.Position.Z, 1e-6)
			end
		end)
	end)

	describe("DepotTopperRules.poolRange", function()
		it("reaches the floor and a little past it, never less than the minimum", function()
			expect(Rules.poolRange(14, 1)).to.equal(13 + TOPPER.POOL.REACH)
			expect(Rules.poolRange(2, 1)).to.equal(TOPPER.POOL.MIN_RANGE)
		end)
	end)

	describe("DepotTopperRules.onShell", function()
		it("stands the topper on the sign's top edge, facing the way its face looks", function()
			-- A 3 x 1.5 sign at the origin whose drawn face is its Back (+Z) face.
			local at = Rules.onShell(CFrame.new(), Vector3.new(3, 1.5, 0.2), Enum.NormalId.Back)
			expect(at.LookVector:Dot(Vector3.new(0, 0, 1))).to.be.near(1, 1e-6)
			-- Bottom of the topper canvas sits SHELL_GAP above the sign's top.
			expect(at.Position.Y - TOPPER.PLATE.Y / 2).to.be.near(0.75 + TOPPER.SHELL_GAP, 1e-6)
		end)
	end)

	describe("DepotTopperRules.station", function()
		it("names the station of every hub interaction kind, and nothing for others", function()
			expect(Rules.station("depot-spot-shop")).to.equal("shop")
			expect(Rules.station("depot-spot-radio")).to.equal("radio")
			expect(Rules.station("TimecardClock")).to.equal("clock")
			expect(Rules.station("DailyWorkOrder")).to.equal("daily")
			expect(Rules.station("depot-spot-standee")).to.equal(nil)
			expect(Rules.station("shift-pile")).to.equal(nil)
			expect(Rules.station(nil)).to.equal(nil)
		end)
	end)

	describe("DepotTopperRules.outlineOf", function()
		it("outlines a visible target itself and a hit box's parent model", function()
			local model = Instance.new("Model")
			local hitbox = Instance.new("Part")
			hitbox.Transparency = 1
			hitbox.Parent = model
			local board = Instance.new("Part")
			board.Parent = model
			expect(Rules.outlineOf(hitbox)).to.equal(model)
			expect(Rules.outlineOf(board)).to.equal(board)
			expect(Rules.outlineOf(model)).to.equal(model)
			local loose = Instance.new("Part")
			loose.Transparency = 1
			expect(Rules.outlineOf(loose)).to.equal(loose)
			model:Destroy()
			loose:Destroy()
		end)
	end)
end
