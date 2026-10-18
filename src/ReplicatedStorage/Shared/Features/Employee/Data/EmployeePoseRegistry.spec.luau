local EmployeePoseRegistry = require(script.Parent.EmployeePoseRegistry)

return function()
	local R15_JOINTS = {
		Root = true,
		Waist = true,
		Neck = true,
		LeftShoulder = true,
		RightShoulder = true,
		LeftElbow = true,
		RightElbow = true,
		LeftWrist = true,
		RightWrist = true,
		LeftHip = true,
		RightHip = true,
		LeftKnee = true,
		RightKnee = true,
		LeftAnkle = true,
		RightAnkle = true,
		LeftEarBase = true,
		RightEarBase = true,
	}
	local FACES = { Happy = true, Worried = true, Content = true, Dazed = true }

	describe("get", function()
		it("has Pippa's portrait set", function()
			expect(EmployeePoseRegistry.get("Pippa")).to.be.ok()
		end)

		it("returns nil for an employee with no portrait set", function()
			expect(EmployeePoseRegistry.get("Nobody")).never.to.be.ok()
		end)
	end)

	describe("every set", function()
		for _, name in EmployeePoseRegistry.names() do
			local set = EmployeePoseRegistry.get(name)

			it(`{name}: covers every context`, function()
				for _, context in EmployeePoseRegistry.CONTEXTS do
					expect(set.contexts[context]).to.be.ok()
				end
			end)

			it(`{name}: names only poses it has`, function()
				for _, entry in set.contexts do
					expect(set.poses[entry.pose]).to.be.ok()
					for _, pose in entry.byLevel or {} do
						expect(set.poses[pose]).to.be.ok()
					end
					for _, pose in entry.byGrade or {} do
						expect(set.poses[pose]).to.be.ok()
					end
				end
			end)

			it(`{name}: poses only R15 joints and known faces`, function()
				for poseName, pose in set.poses do
					expect(pose.name).to.equal(poseName)
					for joint, angles in pose.joints do
						expect(R15_JOINTS[joint]).to.equal(true)
						expect(typeof(angles)).to.equal("Vector3")
					end
					if pose.face ~= nil then
						expect(FACES[pose.face]).to.equal(true)
					end
				end
			end)
		end
	end)

	describe("mirror", function()
		it("flips the Y and Z turns for the other side", function()
			local mirrored = EmployeePoseRegistry.mirror(Vector3.new(10, 20, -30))
			expect(mirrored).to.equal(Vector3.new(10, -20, 30))
		end)
	end)

	describe("STRIP", function()
		it("names the vacuum's backpack (equipment, not the look)", function()
			expect(table.find(EmployeePoseRegistry.STRIP, "VacuumBackpack")).to.be.ok()
		end)
	end)
end
