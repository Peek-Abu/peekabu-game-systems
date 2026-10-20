local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HideConstants = require(ReplicatedStorage.Shared.Features.Hide.Data.HideConstants)
local HideHugFormulas = require(script.Parent.HideHugFormulas)

return function()
	local function nearCFrame(actual, expected)
		local a, b = { actual:GetComponents() }, { expected:GetComponents() }
		for i = 1, 12 do
			expect(math.abs(a[i] - b[i]) < 1e-4).to.equal(true)
		end
	end

	describe("pose", function()
		it("has exactly the 15 joints of the hug", function()
			local pose = HideHugFormulas.pose()
			local expected = {
				"Neck",
				"LeftEarBase",
				"RightEarBase",
				"Waist",
				"Root",
				"LeftHip",
				"RightHip",
				"LeftKnee",
				"RightKnee",
				"LeftAnkle",
				"RightAnkle",
				"LeftShoulder",
				"RightShoulder",
				"LeftElbow",
				"RightElbow",
			}
			local count = 0
			for _ in pose do
				count += 1
			end
			expect(count).to.equal(#expected)
			for _, name in expected do
				expect(pose[name]).never.to.equal(nil)
			end
		end)

		it("rotates the left hip by the owner's angles", function()
			nearCFrame(
				HideHugFormulas.pose().LeftHip,
				CFrame.fromEulerAnglesXYZ(math.rad(105.40), math.rad(4.08), math.rad(-11.29))
			)
		end)

		it("puts the Root's offset at zero", function()
			expect(HideHugFormulas.pose().Root.Position).to.equal(Vector3.zero)
		end)

		it("mirrors left and right: the same X, Y and Z negated", function()
			local pose = HideHugFormulas.pose()
			for _, part in { "Hip", "Shoulder", "Elbow", "EarBase" } do
				local lx, ly, lz = pose["Left" .. part]:ToEulerAnglesXYZ()
				local rx, ry, rz = pose["Right" .. part]:ToEulerAnglesXYZ()
				expect(math.abs(lx - rx) < 1e-4).to.equal(true)
				expect(math.abs(ly + ry) < 1e-4).to.equal(true)
				expect(math.abs(lz + rz) < 1e-4).to.equal(true)
			end
		end)
	end)

	local function nearVector(actual, expected, tolerance)
		expect(math.abs(actual.X - expected.X) < (tolerance or 1e-4)).to.equal(true)
		expect(math.abs(actual.Y - expected.Y) < (tolerance or 1e-4)).to.equal(true)
		expect(math.abs(actual.Z - expected.Z) < (tolerance or 1e-4)).to.equal(true)
	end

	-- A root with one body part on a joint (1 up from the root), and a hat rigid on that body part.
	local function rig()
		return {
			root = "Root",
			joints = {
				{ name = "Spine", part0 = "Root", part1 = "Body", c0 = CFrame.new(0, 1, 0), c1 = CFrame.identity },
			},
			pieces = {
				{ part = "Root", offset = CFrame.identity, size = Vector3.new(2, 2, 2) },
				{ part = "Body", offset = CFrame.identity, size = Vector3.new(1, 2, 1) },
			},
		}
	end

	local quarterTurn = CFrame.Angles(0, 0, math.rad(90))

	describe("extents", function()
		it("measures a body part on its joint without a pose, leaving the root out", function()
			local low, high = HideHugFormulas.extents(rig(), {})
			nearVector(low, Vector3.new(-0.5, 0, -0.5))
			nearVector(high, Vector3.new(0.5, 2, 0.5))
		end)

		it("turns the body part with a 90 degree pose on its joint", function()
			local low, high = HideHugFormulas.extents(rig(), { Spine = quarterTurn })
			nearVector(low, Vector3.new(-1, 0.5, -0.5))
			nearVector(high, Vector3.new(1, 1.5, 0.5))
		end)

		it("takes a joint's order as it comes: a child listed before its parent", function()
			local shape = rig()
			table.insert(shape.joints, 1, {
				name = "Arm",
				part0 = "Body",
				part1 = "Hand",
				c0 = CFrame.new(0, 1, 0),
				c1 = CFrame.identity,
			})
			table.insert(shape.pieces, { part = "Hand", offset = CFrame.identity, size = Vector3.new(1, 1, 1) })
			local _, high = HideHugFormulas.extents(shape, {})
			nearVector(high, Vector3.new(0.5, 2.5, 0.5))
		end)

		it("moves a rigid piece with its base through the pose", function()
			local shape = rig()
			table.insert(shape.pieces, {
				part = "Hat",
				base = "Body",
				offset = CFrame.new(0, 1.5, 0),
				size = Vector3.new(1, 1, 1),
			})
			local low, high = HideHugFormulas.extents(shape, {})
			nearVector(low, Vector3.new(-0.5, 0, -0.5))
			nearVector(high, Vector3.new(0.5, 3, 0.5))
			low, high = HideHugFormulas.extents(shape, { Spine = quarterTurn })
			nearVector(low, Vector3.new(-2, 0.5, -0.5))
			nearVector(high, Vector3.new(1, 1.5, 0.5))
		end)

		it("skips a joint whose part0 is unknown, without error", function()
			local shape = rig()
			table.insert(shape.joints, {
				name = "Lost",
				part0 = "Nowhere",
				part1 = "Ghost",
				c0 = CFrame.new(0, 50, 0),
				c1 = CFrame.identity,
			})
			table.insert(shape.pieces, { part = "Ghost", offset = CFrame.identity, size = Vector3.new(1, 1, 1) })
			local low, high = HideHugFormulas.extents(shape, {})
			nearVector(low, Vector3.new(-0.5, 0, -0.5))
			nearVector(high, Vector3.new(0.5, 2, 0.5))
		end)
	end)

	describe("freeSize", function()
		it("sizes the desk's free box on the 5 x 3 x 3 proxy", function()
			local size = HideHugFormulas.freeSize(HideConstants.FURNITURE.desk.free, Vector3.new(5, 3, 3))
			nearVector(size, Vector3.new(3.09, 2.77, 2.68), 0.01)
		end)
	end)

	describe("hugFrame", function()
		local free = { min = Vector3.new(-0.4, -0.5, -0.5), max = Vector3.new(0.2, 0.4, 0.4) }
		local size = Vector3.new(5, 3, 3)
		local low = Vector3.new(-0.5, -0.2, -0.9)
		local high = Vector3.new(0.3, 1.5, 0.6)
		local gap = 0.05

		local function check(spot)
			local frame = HideHugFormulas.hugFrame(spot, size, free, low, high, gap)
			local at = spot:PointToObjectSpace(frame.Position)
			-- The lowest point on the free box's floor, the back gap inside its back, X centred.
			expect(math.abs(at.Y + low.Y - free.min.Y * size.Y) < 1e-4).to.equal(true)
			expect(math.abs(at.Z + high.Z - (free.max.Z * size.Z - gap)) < 1e-4).to.equal(true)
			local boxCentre = (free.min.X + free.max.X) / 2 * size.X
			expect(math.abs(at.X + (low.X + high.X) / 2 - boxCentre) < 1e-4).to.equal(true)
			nearVector(frame.LookVector, spot.LookVector)
		end

		it("places the body on an identity spot", function()
			check(CFrame.identity)
		end)

		it("holds in the spot's own frame on a spot turned half round", function()
			check(CFrame.new(10, 2, -7) * CFrame.Angles(0, math.pi, 0))
		end)
	end)
end
