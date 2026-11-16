local EmployeeLanyardPartUtils = require(script.Parent.EmployeeLanyardPartUtils)

return function()
	it("turns a number triple into a Vector3", function()
		expect(EmployeeLanyardPartUtils.v3({ 1, -2, 3.5 })).to.equal(Vector3.new(1, -2, 3.5))
	end)

	it("turns an RGB triple (0-255) into a Color3", function()
		expect(EmployeeLanyardPartUtils.rgb({ 255, 0, 51 })).to.equal(Color3.fromRGB(255, 0, 51))
	end)

	it("quiets a part: unanchored, no collision, query, touch or shadow, and massless", function()
		local part = Instance.new("Part")
		part.Anchored = true
		EmployeeLanyardPartUtils.quiet(part)
		expect(part.Anchored).to.equal(false)
		expect(part.CanCollide).to.equal(false)
		expect(part.CanQuery).to.equal(false)
		expect(part.CanTouch).to.equal(false)
		expect(part.Massless).to.equal(true)
		expect(part.CastShadow).to.equal(false)
		part:Destroy()
	end)
end
