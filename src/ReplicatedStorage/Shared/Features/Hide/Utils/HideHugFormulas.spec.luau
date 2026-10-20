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
end
