local Sway = require(script.Parent.CarrySwaySystem)
return function()
	local hand, bag, motor, system, release
	-- A bag hung from a hand at its handle: the handle 0.9 above the bag's middle.
	local contact = CFrame.new(0, 0.9, 0)
	beforeEach(function()
		hand = Instance.new("Part")
		hand.Anchored = true
		hand.CFrame = CFrame.new(0, 3, 0)
		bag = Instance.new("Part")
		motor = Instance.new("Motor6D")
		motor.Part0 = hand
		motor.Part1 = bag
		motor.C0 = CFrame.new(0, -0.3, 0)
		motor.C1 = contact
		motor.Parent = hand
		system = Sway.new()
		release = system.track(motor)
	end)
	afterEach(function()
		release()
		hand:Destroy()
		bag:Destroy()
	end)
	local function bagFrame()
		return hand.CFrame * motor.C0 * motor.Transform * motor.C1:Inverse()
	end

	it("hangs the bag plumb under its handle whatever the hand's angle", function()
		hand.CFrame = CFrame.new(0, 3, 0) * CFrame.Angles(0.3, 0, math.rad(40))
		system.step(1 / 60)
		system.step(1 / 60)
		expect(bagFrame().UpVector:Dot(Vector3.yAxis)).to.be.near(1, 1e-4)
		-- Still hung from the handle: the joint does not move.
		local handle = (hand.CFrame * motor.C0).Position
		expect((bagFrame() * contact).Position:FuzzyEq(handle, 1e-4)).to.equal(true)
	end)

	it("trails behind a hand that sets off, then swings back toward plumb", function()
		for frame = 1, 12 do
			-- Speeding up along +X.
			local t = frame / 60
			hand.CFrame = CFrame.new(4 * t * t, 3, 0)
			system.step(1 / 60)
		end
		-- The bottom swung back (-X): the bag's up leans forward (+X).
		local lean = bagFrame().UpVector.X
		expect(lean > 0.02).to.equal(true)
		local still = hand.CFrame
		for _ = 1, 240 do
			hand.CFrame = still
			system.step(1 / 60)
		end
		expect(math.abs(bagFrame().UpVector.X) < 0.01).to.equal(true)
	end)

	it("puts the joint back at rest when released, and stops driving it", function()
		hand.CFrame = CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(40))
		system.step(1 / 60)
		expect(system.getState().tracked).to.equal(1)
		release()
		expect(motor.Transform).to.equal(CFrame.identity)
		expect(system.getState().tracked).to.equal(0)
		system.step(1 / 60)
		expect(motor.Transform).to.equal(CFrame.identity)
	end)
end
