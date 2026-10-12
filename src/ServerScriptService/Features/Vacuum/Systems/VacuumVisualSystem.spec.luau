local Visual = require(script.Parent.VacuumVisualSystem)
return function()
	describe("vacuum visual assembly", function()
		it("builds original source around one invisible grip handle without collisions", function()
			local tool = Instance.new("Tool")
			local handle = Visual.build(tool)
			expect(handle.Name).to.equal("Handle")
			expect(handle.Transparency).to.equal(1)
			expect(tool:FindFirstChild("Wide floor head", true) ~= nil).to.equal(true)
			for _, part in tool:GetDescendants() do
				if part:IsA("BasePart") then
					expect(part.Massless).to.equal(true)
					expect(part.CanCollide or part.CanQuery or part.CanTouch).to.equal(false)
				end
			end
			tool:Destroy()
		end)
		it("welds every visible part to the single grip root", function()
			local tool = Instance.new("Tool")
			local handle = Visual.build(tool)
			local count = 0
			for _, weld in tool:GetDescendants() do
				if weld:IsA("WeldConstraint") then
					count += 1
					expect(weld.Part0).to.equal(handle)
				end
			end
			expect(count >= 38).to.equal(true)
			tool:Destroy()
		end)
	end)
end
