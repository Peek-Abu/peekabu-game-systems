local OccupantRigSystem = require(script.Parent.OccupantRigSystem)

return function()
	describe("sweep", function()
		-- Its own list of tagged instances and its own remover: whatever wears the tag in the place is not touched.
		local made = {}
		local function model(name)
			local created = Instance.new("Model")
			created.Name = name
			table.insert(made, created)
			return created
		end
		afterEach(function()
			for _, instance in made do
				instance:Destroy()
			end
			table.clear(made)
		end)

		it("removes every tagged model but the one kept, and counts them", function()
			local kept, twinA, twinB = model("Harlow"), model("Harlow"), model("Harlow")
			local removed = {}
			local count = OccupantRigSystem.sweep(kept, { kept, twinA, twinB }, function(rig)
				table.insert(removed, rig)
			end)
			expect(count).to.equal(2)
			expect(#removed).to.equal(2)
			expect(table.find(removed, kept)).to.equal(nil)
			expect(table.find(removed, twinA) ~= nil).to.equal(true)
			expect(table.find(removed, twinB) ~= nil).to.equal(true)
		end)

		it("removes them all with nothing kept, and skips anything that is not a model", function()
			local rig = model("Harlow")
			local stray = Instance.new("Part")
			table.insert(made, stray)
			local removed = {}
			local count = OccupantRigSystem.sweep(nil, { rig, stray }, function(found)
				table.insert(removed, found)
			end)
			expect(count).to.equal(1)
			expect(removed[1]).to.equal(rig)
		end)

		it("finds nothing to remove in an empty list", function()
			expect(OccupantRigSystem.sweep(nil, {}, function() end)).to.equal(0)
		end)
	end)

	describe("alignRigAttachments", function()
		-- A torso and an arm joined by a Motor6D whose C1 turns the arm 90 degrees (as Bramble's wings are authored), and
		-- the plain, unturned rig attachments the Humanoid rebuilds the joint from.
		local function body()
			local model = Instance.new("Model")
			local torso = Instance.new("Part")
			torso.Name = "UpperTorso"
			torso.Parent = model
			local arm = Instance.new("Part")
			arm.Name = "LeftUpperArm"
			arm.Parent = model
			local motor = Instance.new("Motor6D")
			motor.Name = "LeftShoulder"
			motor.Part0 = torso
			motor.Part1 = arm
			motor.C0 = CFrame.new(-1.3, 0.1, 0)
			motor.C1 = CFrame.new(0.3, 0.55, 0) * CFrame.Angles(0, 0, math.rad(90))
			motor.Parent = torso
			local at0 = Instance.new("Attachment")
			at0.Name = "LeftShoulderRigAttachment"
			at0.CFrame = CFrame.new(-1.3, 0.1, 0)
			at0.Parent = torso
			local at1 = Instance.new("Attachment")
			at1.Name = "LeftShoulderRigAttachment"
			at1.CFrame = CFrame.new(0.3, 0.55, 0)
			at1.Parent = arm
			return model, motor, at0, at1
		end

		it(
			"sets each joint's rig attachments to its authored C0 and C1 (owner 11-14: the wings sat inside him)",
			function()
				local model, motor, at0, at1 = body()
				local changed = OccupantRigSystem.alignRigAttachments(model)
				expect(changed).to.equal(1)
				expect(at0.CFrame).to.equal(motor.C0)
				expect(at1.CFrame).to.equal(motor.C1)
				model:Destroy()
			end
		)

		it("leaves joints whose attachments already match, and joints with no rig attachments", function()
			local model, _, at0, at1 = body()
			OccupantRigSystem.alignRigAttachments(model)
			expect(OccupantRigSystem.alignRigAttachments(model)).to.equal(0)
			at0:Destroy()
			at1:Destroy()
			expect(OccupantRigSystem.alignRigAttachments(model)).to.equal(0)
			model:Destroy()
		end)
	end)
end
