local EmployeeRigUtils = require(script.Parent.EmployeeRigUtils)

return function()
	local function near(a, b)
		return (a.Position - b.Position).Magnitude < 1e-4
			and a.LookVector:Dot(b.LookVector) > 0.9999
			and a.UpVector:Dot(b.UpVector) > 0.9999
	end

	local function find(placements, part, name)
		for _, placement in placements do
			if placement.part == part and placement.name == name then
				return placement
			end
		end
		return nil
	end

	describe("rigAttachments", function()
		it("places a matching R15 rig attachment on both sides of each joint, at the joint's C0 and C1", function()
			local placements = EmployeeRigUtils.rigAttachments({
				{
					name = "Neck",
					part0 = "UpperTorso",
					part1 = "Head",
					c0 = CFrame.new(0, 0.61, 0.08),
					c1 = CFrame.new(0, -0.69, 0),
				},
			})
			expect(#placements).to.equal(2)
			local upper = find(placements, "UpperTorso", "NeckRigAttachment")
			local head = find(placements, "Head", "NeckRigAttachment")
			expect(upper).to.be.ok()
			expect(head).to.be.ok()
			expect(near(upper.cframe, CFrame.new(0, 0.61, 0.08))).to.equal(true)
			expect(near(head.cframe, CFrame.new(0, -0.69, 0))).to.equal(true)
		end)

		it("covers custom joints by the same naming rule (BuildRigFromAttachments round-trips it)", function()
			local placements = EmployeeRigUtils.rigAttachments({
				{ name = "LeftEarBase", part0 = "Head", part1 = "LeftEar", c0 = CFrame.new(), c1 = CFrame.new() },
			})
			expect(find(placements, "Head", "LeftEarBaseRigAttachment")).to.be.ok()
			expect(find(placements, "LeftEar", "LeftEarBaseRigAttachment")).to.be.ok()
		end)

		it("does not place the same attachment twice", function()
			local joint =
				{ name = "Waist", part0 = "LowerTorso", part1 = "UpperTorso", c0 = CFrame.new(), c1 = CFrame.new() }
			expect(#EmployeeRigUtils.rigAttachments({ joint, joint })).to.equal(2)
		end)
	end)

	describe("gripAttachment", function()
		it("matches the stock R15 RightGripAttachment for an arms-down hand", function()
			local grip = EmployeeRigUtils.gripAttachment("Right", Vector3.new(1, 0.3, 1), CFrame.new(0, 0.125, 0))
			expect(grip.part).to.equal("RightHand")
			expect(grip.name).to.equal("RightGripAttachment")
			expect(near(grip.cframe, CFrame.new(0, -0.15, 0) * CFrame.Angles(-math.pi / 2, 0, 0))).to.equal(true)
		end)

		it("follows a T-posed right hand: the grip sits at the hand's end along +X", function()
			local size = Vector3.new(0.54, 0.43, 0.78)
			-- Pippa's RightWrist C1: the wrist pivot sits on the hand's -X side, so the arm runs along +X.
			local grip = EmployeeRigUtils.gripAttachment("Right", size, CFrame.new(-0.23, 0, 0.087))
			expect(math.abs(grip.cframe.Position.X - 0.27) < 1e-4).to.equal(true)
			-- The stock grip frame is rotated so that "down the arm" (stock -Y) becomes +X.
			local downArm = grip.cframe:VectorToWorldSpace(
				(CFrame.Angles(-math.pi / 2, 0, 0)):VectorToObjectSpace(Vector3.new(0, -1, 0))
			)
			expect(downArm:Dot(Vector3.new(1, 0, 0)) > 0.999).to.equal(true)
		end)

		it("mirrors for a T-posed left hand", function()
			local grip = EmployeeRigUtils.gripAttachment("Left", Vector3.new(0.54, 0.43, 0.78), CFrame.new(0.23, 0, 0.087))
			expect(grip.name).to.equal("LeftGripAttachment")
			expect(math.abs(grip.cframe.Position.X + 0.27) < 1e-4).to.equal(true)
		end)

		it("handles a hand whose arm runs up its +Y", function()
			local grip = EmployeeRigUtils.gripAttachment("Right", Vector3.new(1, 0.3, 1), CFrame.new(0, -0.125, 0))
			expect(math.abs(grip.cframe.Position.Y - 0.15) < 1e-4).to.equal(true)
		end)
	end)
end
