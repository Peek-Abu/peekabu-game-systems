local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Contact = require(ReplicatedStorage.Shared.Features.Animation.Utils.AnimationCarryContactUtils)
local Cargo = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local CargoConstants = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoConstants)
local Styles = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationCarryRegistry)
return function()
	-- A stock R15 avatar, measured in HumanoidRootPart space.
	local stock = {
		leftShoulder = Vector3.new(-1, 1.2, 0),
		rightShoulder = Vector3.new(1, 1.2, 0),
		leftReach = 1.85,
		rightReach = 1.85,
		leftPalmReach = 1.75,
		rightPalmReach = 1.75,
		handLength = 0.3,
		front = -0.5,
		headFront = -0.6,
		headBottom = 1.45,
		floor = -3,
	}
	-- Pippa at 1.25x (measured in Studio 2026-10-13/14): shoulders close together, arms ~1 stud to the wrist
	-- plus a big mitt, a round belly well in front of the shoulders and a big head hanging just above them.
	local pippa = {
		leftShoulder = Vector3.new(-0.45, 1.11, 0.02),
		rightShoulder = Vector3.new(0.45, 1.11, 0.02),
		leftReach = 1.43,
		rightReach = 1.43,
		leftPalmReach = 1.41,
		rightPalmReach = 1.41,
		handLength = 0.67,
		front = -0.73,
		headFront = -1.02,
		headBottom = 1.45,
		floor = -1.375,
	}
	local function world(plan, contact)
		return plan.offset:PointToWorldSpace(contact.Position)
	end
	-- The box's near face, top and bottom in root space.
	local function bounds(plan, size)
		local near = plan.offset:PointToWorldSpace(Vector3.new(0, 0, size.Z / 2)).Z
		local top = plan.offset:PointToWorldSpace(Vector3.new(0, size.Y / 2, 0)).Y
		local bottom = plan.offset:PointToWorldSpace(Vector3.new(0, -size.Y / 2, 0)).Y
		return near, top, bottom
	end
	-- The bulky cart is pushed at a caller-owned offset, not carried.
	local function carried(id)
		return Cargo.get(id).size ~= "bulky"
	end

	for name, rig in { stock = stock, pippa = pippa } do
		describe(`the {name} rig`, function()
			it("carries every hand-held cargo kind on both palms, under its bottom, within reach", function()
				for _, id in Cargo.ids() do
					if carried(id) then
						local size = Cargo.get(id).partSize
						local plan = Contact.plan(size, rig, Styles.get(id))
						expect(plan).to.be.ok()
						expect(plan.under).to.equal(true)
						expect(plan.left).to.be.ok()
						for _, contact in { plan.right, plan.left } do
							local p = contact.Position
							-- On the bottom face, inside its footprint.
							expect(p.Y).to.be.near(-size.Y / 2, 1e-3)
							expect(math.abs(p.X) <= size.X / 2).to.equal(true)
							expect(math.abs(p.Z) <= size.Z / 2).to.equal(true)
						end
						local right, left = world(plan, plan.right), world(plan, plan.left)
						expect((right - rig.rightShoulder).Magnitude <= rig.rightPalmReach).to.equal(true)
						expect((left - rig.leftShoulder).Magnitude <= rig.leftPalmReach).to.equal(true)
						expect(right.X > left.X).to.equal(true)
					end
				end
			end)

			it("turns the palms up with the fingers forward, rolled only a little inward", function()
				local plan = Contact.plan(Vector3.new(2, 1, 1.4), rig, "twoHand")
				for _, pair in { { plan.right, 1 }, { plan.left, -1 } } do
					local contact, side = pair[1], pair[2]
					local up = plan.offset:VectorToWorldSpace(contact.UpVector)
					local fingers = plan.offset:VectorToWorldSpace(contact.LookVector)
					expect(up.Y > math.cos(math.rad(20))).to.equal(true)
					-- Toward the middle, not outward.
					expect(up.X * side <= 0).to.equal(true)
					expect(fingers.Z).to.be.near(-1, 1e-3)
				end
			end)

			it("keeps the item in front of the torso, clear of the head and above the floor", function()
				for _, id in Cargo.ids() do
					if carried(id) then
						local size = Cargo.get(id).partSize
						local plan = Contact.plan(size, rig, Styles.get(id))
						local near, top, bottom = bounds(plan, size)
						expect(near <= rig.front).to.equal(true)
						expect(bottom >= rig.floor).to.equal(true)
						expect(top <= rig.headBottom or near <= rig.headFront).to.equal(true)
					end
				end
			end)

			it("rests the item on the palms below the shoulders and above the hips", function()
				local small = Contact.plan(Vector3.new(1, 0.6, 0.8), rig, "small")
				local big = Contact.plan(Vector3.new(2, 2, 2), rig, "twoHand")
				local shoulderY = rig.rightShoulder.Y
				for _, plan in { small, big } do
					local hand = world(plan, plan.right)
					expect(hand.Y <= shoulderY - rig.rightReach * 0.25).to.equal(true)
					expect(hand.Y > rig.floor + (shoulderY - rig.floor) * 0.4).to.equal(true)
				end
			end)
		end)
	end

	it("carries a big item lower than a small one", function()
		local small = Contact.plan(Vector3.new(1, 0.6, 0.8), stock, "small")
		local big = Contact.plan(Vector3.new(2, 2, 2), stock, "twoHand")
		expect(world(big, big.right).Y < world(small, small.right).Y).to.equal(true)
	end)

	it("holds a small item at the belly with the elbows bent: palms about an upper arm below the shoulders", function()
		local size = Vector3.new(1, 0.6, 0.8)
		local plan = Contact.plan(size, stock, "small")
		expect(world(plan, plan.right).Y).to.be.near(1.2 - 1.85 * 0.55, 1e-3)
		-- The near face against the belly.
		expect((bounds(plan, size))).to.be.near(stock.front - 0.08, 1e-3)
	end)

	it("puts the hands shoulder-width apart under a wide item, and in under a narrow one", function()
		local wide = Contact.plan(Vector3.new(3, 1, 1.4), stock, "twoHand")
		expect(world(wide, wide.right).X).to.be.near(stock.rightShoulder.X, 1e-3)
		expect(world(wide, wide.left).X).to.be.near(stock.leftShoulder.X, 1e-3)
		local narrow = Contact.plan(Vector3.new(0.6, 0.4, 0.6), stock, "small")
		expect(math.abs(narrow.right.Position.X) <= 0.3).to.equal(true)
		expect(math.abs(narrow.left.Position.X) <= 0.3).to.equal(true)
	end)

	it("holds an item that cannot clear the head as far out as the arms allow, not against the belly", function()
		-- Pippa with her head nodded forward past where her arms can hold a tall item out: nothing clears it.
		local nodding = table.clone(pippa)
		nodding.headFront = -1.3
		local size = Vector3.new(3, 2.98, 2.24)
		local plan = Contact.plan(size, nodding, "twoHand")
		expect(plan).to.be.ok()
		local near = plan.offset:PointToWorldSpace(Vector3.new(0, 0, size.Z / 2)).Z
		-- Well out past the belly (front - gap = -0.81), as far as the arms reach under it.
		expect(near < -1).to.equal(true)
		local right = plan.offset:PointToWorldSpace(plan.right.Position)
		expect((right - nodding.rightShoulder).Magnitude <= nodding.rightPalmReach).to.equal(true)
	end)

	it("lifts the item for short arms that cannot reach low enough around a round belly", function()
		local plan = Contact.plan(Vector3.new(1, 0.6, 0.8), pippa, "small")
		expect(plan).to.be.ok()
		local hand = world(plan, plan.right)
		expect(hand.Y > 1.11 - 1.43 * 0.55).to.equal(true)
		expect((hand - pippa.rightShoulder).Magnitude <= pippa.rightPalmReach * 0.95 + 1e-3).to.equal(true)
	end)

	it("leaves the bulky cart hands-free: its caller-owned offset is out of every arm's reach", function()
		-- The cart's near face is 2.75 studs out; the caller then places it at its offset with no hold.
		local size = Cargo.get("filingCabinet").partSize
		expect(Contact.plan(size, stock, "twoHand", CargoConstants.BULKY_HOLD_OFFSET)).to.equal(nil)
		expect(Contact.plan(size, pippa, "twoHand", CargoConstants.BULKY_HOLD_OFFSET)).to.equal(nil)
	end)

	it("does not stretch a short arm to an unreachable caller-owned offset", function()
		expect(Contact.plan(Vector3.new(2, 2, 2), pippa, "twoHand", CFrame.new(0, -1, -4.5))).to.equal(nil)
	end)

	it("honors a reachable explicit offset and rejects invalid sizes or reaches", function()
		local offset = CFrame.new(0, 0.3, -1.6)
		local plan = Contact.plan(Vector3.new(2, 2, 2), stock, "twoHand", offset)
		expect(plan.offset).to.equal(offset)
		expect(Contact.plan(Vector3.new(0, 2, 2), stock, "twoHand")).to.equal(nil)
		local broken = table.clone(stock)
		broken.rightPalmReach = 0 / 0
		expect(Contact.plan(Vector3.new(2, 2, 2), broken, "twoHand")).to.equal(nil)
	end)

	it("rests the authored body front against the torso and puts the palms in from it (a pot under leaves)", function()
		local size = Vector3.new(1.5, 2.5, 1.5)
		local plan = Contact.plan(size, pippa, "twoHand", nil, { bodyZ = 0.55 })
		expect(plan).to.be.ok()
		expect(plan.offset.Position.Z + 0.55).to.be.near(pippa.front - 0.08, 1e-3)
		expect(plan.right.Position.Z < 0.55).to.equal(true)
		-- A body front outside the box is malformed.
		expect(Contact.plan(size, pippa, "twoHand", nil, { bodyZ = 2 })).to.equal(nil)
	end)

	describe("palmFrame", function()
		it("finds a T-posed hand's palm facing down, at its face (Pippa's rig)", function()
			local size = Vector3.new(0.67, 0.54, 0.97)
			local frame = Contact.palmFrame(Vector3.new(0.6, 0, -0.1), CFrame.identity, 1, size)
			expect((frame.LookVector - Vector3.xAxis).Magnitude < 1e-3).to.equal(true)
			expect((frame.UpVector + Vector3.yAxis).Magnitude < 1e-3).to.equal(true)
			expect((frame.Position - Vector3.new(0, -0.27, 0)).Magnitude < 1e-3).to.equal(true)
			local left = Contact.palmFrame(Vector3.new(-0.6, 0, -0.1), CFrame.identity, -1, size)
			expect((left.UpVector + Vector3.yAxis).Magnitude < 1e-3).to.equal(true)
		end)

		it("finds a hanging hand's palm facing the body (stock R15)", function()
			local size = Vector3.new(0.3, 0.3, 0.3)
			local right = Contact.palmFrame(Vector3.new(0, -0.3, 0), CFrame.identity, 1, size)
			expect((right.UpVector + Vector3.xAxis).Magnitude < 1e-3).to.equal(true)
			expect((right.LookVector + Vector3.yAxis).Magnitude < 1e-3).to.equal(true)
			local left = Contact.palmFrame(Vector3.new(0, -0.3, 0), CFrame.identity, -1, size)
			expect((left.UpVector - Vector3.xAxis).Magnitude < 1e-3).to.equal(true)
		end)
	end)

	describe("a round body (shoulders inside the torso)", function()
		local round = table.clone(pippa)
		round.torsoHalfWidth = 0.6
		local plaque = Vector3.new(0.36, 0.4, 0.16)

		it("holds a narrow item higher, the fingers turned in so the wrists sit out toward the shoulders", function()
			local flat = Contact.plan(plaque, pippa, "small")
			local plan = Contact.plan(plaque, round, "small")
			expect(plan).to.be.ok()
			local _, _, bottom = bounds(plan, plaque)
			local _, _, flatBottom = bounds(flat, plaque)
			expect(bottom > flatBottom + 0.1).to.equal(true)
			for _, pair in { { plan.right, 1 }, { plan.left, -1 } } do
				local look = plan.offset:VectorToWorldSpace(pair[1].LookVector)
				-- Fingers forward and inward, about 45 degrees.
				expect(look.X * pair[2] < -0.5).to.equal(true)
				expect(look.Z < -0.5).to.equal(true)
			end
		end)

		it("puts the palms out past the torso's sides under a wide item", function()
			local size = Vector3.new(2, 1.6, 1.6)
			local plan = Contact.plan(size, round, "handle")
			expect(plan).to.be.ok()
			expect(world(plan, plan.right).X > round.torsoHalfWidth).to.equal(true)
			expect(world(plan, plan.left).X < -round.torsoHalfWidth).to.equal(true)
		end)

		it("leaves a stock R15 (shoulders on its torso's edge) exactly as before", function()
			local edged = table.clone(stock)
			edged.torsoHalfWidth = 1
			for _, size in { plaque, Vector3.new(2, 1.6, 1.6), Vector3.new(1, 1, 1) } do
				local before = Contact.plan(size, stock, "twoHand")
				local after = Contact.plan(size, edged, "twoHand")
				expect(after.offset).to.equal(before.offset)
				expect(after.right).to.equal(before.right)
				expect(after.left).to.equal(before.left)
			end
		end)
	end)

	describe("elbow", function()
		-- The default pole for an under-the-item hold: down, a little out and behind the shoulder.
		local POLE = Vector3.new(0.4, -2, 1)
		-- Points along a segment (fractions from a to b).
		local function along(a, b, from, to)
			local points = {}
			for k = 0, 8 do
				table.insert(points, a:Lerp(b, from + (to - from) * k / 8))
			end
			return points
		end
		local function inside(point, body, pad)
			for _, shape in body do
				local d = (point - shape.centre) / (shape.radii + Vector3.one * pad)
				if d.Magnitude < 1 then
					return true
				end
			end
			return false
		end

		it("keeps the two bones' lengths and reaches the wrist", function()
			local shoulder, wrist = Vector3.new(0.45, 1.1, 0), Vector3.new(0.2, 0.4, -0.7)
			local elbow = Contact.elbow(shoulder, wrist, 0.6, 0.6, 1, POLE, {}, 0.08)
			expect((elbow - shoulder).Magnitude).to.be.near(0.6, 1e-3)
			expect((wrist - elbow).Magnitude).to.be.near(0.6, 1e-3)
		end)

		it("bends toward the default pole when that already clears the body", function()
			-- Shoulders on the torso's edge with the arms hanging outside it, as a stock R15's.
			local body = { { centre = Vector3.new(0, 0.6, 0), radii = Vector3.new(0.7, 0.8, 0.5) } }
			local shoulder, wrist = Vector3.new(1, 1.2, 0), Vector3.new(0.6, 0.1, -1)
			local elbow = Contact.elbow(shoulder, wrist, 0.9, 0.9, 1, POLE, body, 0.08)
			local free = Contact.elbow(shoulder, wrist, 0.9, 0.9, 1, POLE, {}, 0.08)
			expect((elbow - free).Magnitude).to.be.near(0, 1e-3)
		end)

		it("swings the elbows out of a round body: Pippa holding the plaque", function()
			-- Pippa at 1.25x, her torso's part boxes as ellipsoids (root space), the plaque's wrists (measured in
			-- Studio 2026-10-14): the shoulder joints are inside the torso, the wrists in front of the belly.
			local body = {
				{ centre = Vector3.new(0, 0.825, -0.1), radii = Vector3.new(0.597, 1.225, 0.629) },
				{ centre = Vector3.new(0, 0, 0.214), radii = Vector3.new(0.6, 0.475, 0.76) },
			}
			local function count(points)
				local n = 0
				for _, point in points do
					if inside(point, body, 0.08) then
						n += 1
					end
				end
				return n
			end
			for _, side in { 1, -1 } do
				local shoulder = Vector3.new(side * 0.47, 1.1, 0)
				local wrist = Vector3.new(side * 0.41, 0.65, -0.72)
				local default = Contact.elbow(shoulder, wrist, 0.525, 0.475, side, POLE, {}, 0.08)
				local elbow = Contact.elbow(shoulder, wrist, 0.525, 0.475, side, POLE, body, 0.08)
				-- The default bend (down, behind) sinks the elbow into the torso; the chosen one is outside it, out
				-- from the shoulder, with less of the upper arm and none of the forearm inside.
				expect(inside(default, body, 0.08)).to.equal(true)
				expect(inside(elbow, body, 0.08)).to.equal(false)
				expect(elbow.X * side > shoulder.X * side + 0.15).to.equal(true)
				expect(count(along(shoulder, elbow, 0.5, 1)) < count(along(shoulder, default, 0.5, 1))).to.equal(true)
				expect(count(along(elbow, wrist, 0, 0.7))).to.equal(0)
				expect((elbow - shoulder).Magnitude).to.be.near(0.525, 1e-3)
				expect((wrist - elbow).Magnitude).to.be.near(0.475, 1e-3)
			end
		end)

		it("stretches straight at a wrist out of reach", function()
			local shoulder, wrist = Vector3.zero, Vector3.new(0, 0, -3)
			local elbow = Contact.elbow(shoulder, wrist, 0.6, 0.6, 1, POLE, {}, 0.2)
			expect((elbow - Vector3.new(0, 0, -0.6)).Magnitude < 0.05).to.equal(true)
		end)
	end)
end
