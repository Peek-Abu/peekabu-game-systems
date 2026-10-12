local Visual = require(script.Parent.DepotTruckVisualSystem)
return function()
	local model
	afterEach(function()
		if model then
			model:Destroy()
		end
	end)
	it("keeps boarding clear and builds a narrower cab with four wheel arches", function()
		model = Instance.new("Model")
		local pad = Instance.new("Part")
		pad.Size = Vector3.new(12, 1, 16)
		pad.CFrame = CFrame.new(0, 0.5, 0)
		pad.Parent = model
		Visual.build(pad, model)
		expect(pad.Size).to.equal(Vector3.new(12, 1, 16))
		expect(model:FindFirstChild("TruckCab", true).Size.X < pad.Size.X).to.equal(true)
		local arches, steps = 0, 0
		for _, part in model:GetDescendants() do
			if part.Name == "WheelArch" then
				arches += 1
			end
			if part.Name == "BoardingStep" then
				steps += 1
			end
			if part:IsA("BasePart") and part ~= pad and part.Name ~= "TruckCab" and part.Name ~= "BoardingStep" then
				expect(part.CanCollide).to.equal(false)
				expect(part.CanQuery).to.equal(false)
				expect(part.CanTouch).to.equal(false)
			end
		end
		expect(arches).to.equal(4)
		expect(steps).to.equal(2)
	end)
end
