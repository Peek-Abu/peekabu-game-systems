local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Contact = require(ReplicatedStorage.Shared.Features.Animation.Utils.AnimationCarryContactUtils)
local Cargo = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
local Styles = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationCarryRegistry)
return function()
	-- A stock R15 avatar, measured in HumanoidRootPart space.
	local stock = {
		leftShoulder = Vector3.new(-1, 1.2, 0),
		rightShoulder = Vector3.new(1, 1.2, 0),
		leftReach = 1.85,
		rightReach = 1.85,
		front = -0.5,
		headFront = -0.6,
		headBottom = 1.45,
		floor = -3,
	}
	-- Pippa at 1.25x (measured in Studio 2026-10-13): shoulders close together, arms ~1 stud to the wrist
	-- plus the mitt, a round torso and a big head hanging just above the shoulders.
	local pippa = {
		leftShoulder = Vector3.new(-0.45, 1.11, 0.02),
		rightShoulder = Vector3.new(0.45, 1.11, 0.02),
		leftReach = 1.43,
		rightReach = 1.43,
		front = -0.73,
		headFront = -1.02,
		headBottom = 1.45,
		floor = -1.375,
	}
	local function onSurface(point, size)
		return math.abs(math.abs(point.X) - size.X / 2) < 0.001
			or math.abs(math.abs(point.Y) - size.Y / 2) < 0.001
			or math.abs(math.abs(point.Z) - size.Z / 2) < 0.001
	end
	local function world(plan, contact)
		return plan.offset:PointToWorldSpace(contact.Position)
	end
	-- The box's corners in root space: its near face, top and bottom.
	local function bounds(plan, size)
		local near = plan.offset:PointToWorldSpace(Vector3.new(0, 0, size.Z / 2)).Z
		local top = plan.offset:PointToWorldSpace(Vector3.new(0, size.Y / 2, 0)).Y
		local bottom = plan.offset:PointToWorldSpace(Vector3.new(0, -size.Y / 2, 0)).Y
		return near, top, bottom
	end

	for name, rig in { stock = stock, pippa = pippa } do
		describe(`the {name} rig`, function()
			it("holds every cargo kind with both hands on its real surface, within reach", function()
				for _, id in Cargo.ids() do
					local size = Cargo.get(id).partSize
					local plan = Contact.plan(size, rig, Styles.get(id))
					expect(plan).to.be.ok()
					expect(plan.left).to.be.ok()
					expect(onSurface(plan.right.Position, size)).to.equal(true)
					expect(onSurface(plan.left.Position, size)).to.equal(true)
					expect((world(plan, plan.right) - rig.rightShoulder).Magnitude <= rig.rightReach).to.equal(true)
					expect((world(plan, plan.left) - rig.leftShoulder).Magnitude <= rig.leftReach).to.equal(true)
					-- Right hand on the right, left on the left.
					expect(world(plan, plan.right).X > world(plan, plan.left).X).to.equal(true)
				end
			end)

			it("keeps the item in front of the torso, clear of the head and above the floor", function()
				for _, id in Cargo.ids() do
					local size = Cargo.get(id).partSize
					local plan = Contact.plan(size, rig, Styles.get(id))
					local near, top, bottom = bounds(plan, size)
					expect(near <= rig.front).to.equal(true)
					expect(bottom >= rig.floor).to.equal(true)
					-- Under the head, or out past its face.
					expect(top <= rig.headBottom or near <= rig.headFront).to.equal(true)
				end
			end)

			it("holds the item at chest/belly height: the hands below the shoulders, above the hips", function()
				local size = Vector3.new(2, 2, 2)
				local plan = Contact.plan(size, rig, "twoHand")
				local hand = world(plan, plan.right)
				expect(hand.Y < rig.rightShoulder.Y).to.equal(true)
				expect(hand.Y > rig.floor + (rig.rightShoulder.Y - rig.floor) * 0.4).to.equal(true)
			end)
		end)
	end

	it("grips a box Pippa can reach around by its sides, a wide one on its near face", function()
		local small = Contact.plan(Vector3.new(1, 0.4, 0.8), pippa, "small")
		expect(math.abs(math.abs(small.right.Position.X) - 0.5) < 0.001).to.equal(true)
		local wide = Contact.plan(Vector3.new(3, 3, 3), pippa, "twoHand")
		-- Palms on the near (+Z) face of a box wider than her arms can wrap.
		expect(math.abs(wide.right.Position.Z - 1.5) < 0.001).to.equal(true)
		expect(math.abs(wide.left.Position.Z - 1.5) < 0.001).to.equal(true)
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
		broken.rightReach = 0 / 0
		expect(Contact.plan(Vector3.new(2, 2, 2), broken, "twoHand")).to.equal(nil)
	end)

	it("raises an authored grip height to the hands: a pot rim low on a tall plant", function()
		-- Pippa's hands go half an arm below her shoulders.
		local handY = 1.11 - 1.43 * 0.5
		local size = Vector3.new(1.5, 2.5, 1.5)
		local plan = Contact.plan(size, pippa, "twoHand", nil, { gripY = -0.4 })
		expect(plan).to.be.ok()
		expect(plan.offset.Position.Y - 0.4).to.be.near(handY, 1e-3)
		-- Too tall to fit under her head, it is still held against her body at the grips' height (lowering it
		-- or pushing it out past her face would take the grips out of her reach).
		expect(plan.offset.Position.Z + size.Z / 2).to.be.near(pippa.front - 0.08, 1e-3)
		-- Without one, the box's middle is at the hands.
		expect(Contact.plan(Vector3.new(1, 1, 1), pippa, "twoHand").offset.Position.Y).to.be.near(handY, 1e-3)
		-- Never into the floor.
		local low = Contact.plan(size, pippa, "twoHand", nil, { gripY = 1.2 })
		expect(low.offset.Position.Y - size.Y / 2 >= pippa.floor).to.equal(true)
		expect(Contact.plan(size, pippa, "twoHand", nil, { gripY = 0 / 0 })).to.equal(nil)
	end)

	it("rests the authored body front against the torso, not the box's near face (a pot under wide leaves)", function()
		local size = Vector3.new(1.5, 2.5, 1.5)
		local plan = Contact.plan(size, pippa, "twoHand", nil, { gripY = -0.4, bodyZ = 0.55 })
		expect(plan).to.be.ok()
		expect(plan.offset.Position.Z + 0.55).to.be.near(pippa.front - 0.08, 1e-3)
		-- A body front outside the box is malformed.
		expect(Contact.plan(size, pippa, "twoHand", nil, { bodyZ = 2 })).to.equal(nil)
	end)

	it("authored handle targets override box grips only when the arms can reach them", function()
		local plan = Contact.plan(Vector3.new(2, 2, 2), stock, "twoHand")
		local custom = Contact.withGrips(plan, CFrame.new(0.8, 0.2, 1), nil, stock)
		expect(custom.right.Position).to.equal(Vector3.new(0.8, 0.2, 1))
		expect(custom.left).to.equal(nil)
		expect(Contact.withGrips(plan, CFrame.new(0, 0, -10), nil, stock)).to.equal(nil)
	end)
end
