local CarrySpeedSystem = require(script.Parent.CarrySpeedSystem)

local function humanoid(speed)
	local model = Instance.new("Model")
	local h = Instance.new("Humanoid")
	h.WalkSpeed = speed or 16
	h.Parent = model
	return h, model
end

return function()
	afterEach(function()
		CarrySpeedSystem.reset()
	end)

	it("slows a loaded humanoid from its unloaded walk and gives it back when the load is gone", function()
		local h, model = humanoid(16)
		CarrySpeedSystem.applyTo(1, h, 4, nil)
		expect(h.WalkSpeed).to.be.near(12.8, 1e-6)
		CarrySpeedSystem.applyTo(1, h, 5.5, nil)
		expect(h.WalkSpeed).to.be.near(11.6, 1e-6)
		CarrySpeedSystem.applyTo(1, h, 0, nil)
		expect(h.WalkSpeed).to.equal(16)
		expect(CarrySpeedSystem.count()).to.equal(0)
		model:Destroy()
	end)

	it("starts from the game's speed base, never from a boost that was on", function()
		local h, model = humanoid(23)
		CarrySpeedSystem.applyTo(1, h, 2, 16)
		expect(h.WalkSpeed).to.be.near(14.4, 1e-6)
		CarrySpeedSystem.applyTo(1, h, 0, 16)
		expect(h.WalkSpeed).to.equal(16)
		model:Destroy()
	end)

	it("gives an old body its speed back when the player has a new one", function()
		local old, oldModel = humanoid(16)
		CarrySpeedSystem.applyTo(1, old, 4, nil)
		local fresh, freshModel = humanoid(16)
		CarrySpeedSystem.applyTo(1, fresh, 0, nil)
		expect(old.WalkSpeed).to.equal(16)
		expect(fresh.WalkSpeed).to.equal(16)
		CarrySpeedSystem.applyTo(1, nil, 4, nil)
		expect(CarrySpeedSystem.count()).to.equal(0)
		oldModel:Destroy()
		freshModel:Destroy()
	end)

	it("names a carrier's load: the game's, else the hands item's, never below 0", function()
		CarrySpeedSystem.setHeld(1, 4)
		expect(CarrySpeedSystem.weightFor({ UserId = 1 })).to.equal(4)
		CarrySpeedSystem.setLoadSource(function()
			return 2.5
		end)
		expect(CarrySpeedSystem.weightFor({ UserId = 1 })).to.equal(2.5)
		CarrySpeedSystem.setLoadSource(function()
			return -1
		end)
		expect(CarrySpeedSystem.weightFor({ UserId = 1 })).to.equal(0)
		CarrySpeedSystem.setLoadSource(function()
			return nil
		end)
		expect(CarrySpeedSystem.weightFor({ UserId = 1 })).to.equal(4)
		CarrySpeedSystem.setHeld(1, nil)
		expect(CarrySpeedSystem.weightFor({ UserId = 1 })).to.equal(0)
	end)
end
