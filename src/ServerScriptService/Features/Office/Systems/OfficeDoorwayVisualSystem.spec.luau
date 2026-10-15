local System = require(script.Parent.OfficeDoorwayVisualSystem)
return function()
	local root
	afterEach(function()
		if root then
			root:Destroy()
		end
	end)
	it("builds narrow nonblocking trim on both rotated wall faces below the ceiling", function()
		for _, angle in { 0, math.pi / 2, math.pi, -math.pi / 2 } do
			root = Instance.new("Part")
			root.Size = Vector3.new(10, 12, 1)
			root.CFrame = CFrame.new(1000, 6, 0) * CFrame.Angles(0, angle, 0)
			root.Transparency = 1
			local original = root.CFrame
			System.build(root)
			local sides = { [1] = 0, [-1] = 0 }
			for _, trim in root:GetChildren() do
				local position = root.CFrame:PointToObjectSpace(trim.Position)
				local side = if position.Z > 0 then 1 else -1
				sides[side] += 1
				expect(math.abs(position.Z) - trim.Size.Z / 2 >= 0.5 - 0.001).to.equal(true)
				expect(trim.Anchored).to.equal(true)
				expect(trim.CanCollide or trim.CanQuery or trim.CanTouch).to.equal(false)
				if trim.Name == "Jamb" then
					expect(math.abs(position.X) - trim.Size.X / 2).to.be.near(5, 0.001)
					expect(trim.Size.X <= 0.2).to.equal(true)
				else
					expect(position.Y + trim.Size.Y / 2).to.be.near(6, 0.001)
					expect(position.Y - trim.Size.Y / 2 >= 5.75).to.equal(true)
				end
			end
			expect(sides[1]).to.equal(3)
			expect(sides[-1]).to.equal(3)
			expect(root.CFrame).to.equal(original)
			root:Destroy()
			root = nil
		end
	end)
end
