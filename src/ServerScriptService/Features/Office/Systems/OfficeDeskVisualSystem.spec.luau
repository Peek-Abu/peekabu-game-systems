local Visual = require(script.Parent.OfficeDeskVisualSystem)
return function()
	it("builds a five-row keyboard with recognizable space bar without blocking search", function()
		local desk = Instance.new("Part")
		desk.Size = Vector3.new(5, 3, 3)
		desk.CFrame = CFrame.new(20, 1.5, 30)
		Visual.build(desk)
		local keys, rows = 0, {}
		for _, part in desk:GetDescendants() do
			if part.Name == "Keycap" then
				keys += 1
				rows[part:GetAttribute("KeyRow")] = true
			end
			if part:IsA("BasePart") then
				expect(part.CanQuery).to.equal(false)
				expect(part.CanCollide).to.equal(false)
			end
		end
		expect(keys >= 45).to.equal(true)
		expect(desk:FindFirstChild("SpaceBar", true) ~= nil).to.equal(true)
		for row = 1, 5 do
			expect(rows[row]).to.equal(true)
		end
		desk:Destroy()
	end)
end
