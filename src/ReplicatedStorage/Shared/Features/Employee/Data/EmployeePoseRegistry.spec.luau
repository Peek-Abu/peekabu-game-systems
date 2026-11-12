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

		it("gives every employee on the kit rig the same poses, so none shows the rig's T-pose", function()
			local pippa = EmployeePoseRegistry.get("Pippa")
			for _, name in { "Prickles", "Cappy" } do
				local set = EmployeePoseRegistry.get(name)
				expect(set.contexts).to.equal(pippa.contexts)
				for poseName, pose in pippa.poses do
					expect(set.poses[poseName].joints).to.equal(pose.joints)
				end
			end
		end)

		it(
			"wears an employee's own face for a pose where its personality says so (owner 11-12: gruff Prickles)",
			function()
				local EmployeeRegistry =
					require(game:GetService("ReplicatedStorage").Shared.Features.Employee.Data.EmployeeRegistry)
				local prickles = EmployeePoseRegistry.get("Prickles")
				local own = EmployeeRegistry.get("Prickles").poseFaces
				expect(own).to.be.ok()
				for poseName, face in own do
					expect(prickles.poses[poseName].look).to.equal(face)
				end
				-- Not happy when he points the way.
				expect(prickles.poses.point.look).never.to.equal("Happy")
				expect(prickles.poses.point.look).to.be.ok()
				-- Never the gritted-teeth face (owner 11-12: "I dont like the teeth"), in any pose.
				for _, pose in prickles.poses do
					expect(pose.look).never.to.equal("Grit")
				end
				-- An employee without its own faces keeps the kit's.
				local pippa = EmployeePoseRegistry.get("Pippa")
				expect(pippa.poses.point.look).to.equal(nil)
				expect(pippa.poses.shh.look).to.equal("Shh")
				-- The same set object each time (portraits key on it).
				expect(EmployeePoseRegistry.get("Prickles")).to.equal(prickles)
			end
		)

		it("returns nil for an employee with no portrait set", function()
			expect(EmployeePoseRegistry.get("Nobody")).never.to.be.ok()
		end)
	end)

	-- Owner 11-10: the coach's hide (ears folded forward over her eyes) read wrong. It must work for any employee,
	-- so it is a cower that does not lean on ear shape: ears pinned back flat (as in the sneak), never over the face.
	describe("the coach's hide", function()
		local hide = EmployeePoseRegistry.get("Pippa").poses.hide
		local shh = EmployeePoseRegistry.get("Pippa").poses.shh

		it("pins the ears back flat, like the sneak, never folded forward over the face", function()
			expect(hide.joints.RightEarBase.X > 0).to.equal(true)
			expect(hide.joints.LeftEarBase.X > 0).to.equal(true)
			expect(hide.joints.RightEarBase.X >= shh.joints.RightEarBase.X).to.equal(true)
		end)

		it("cowers: the head ducks and both arms hug in", function()
			expect(hide.joints.Neck.X > 0).to.equal(true)
			expect(hide.joints.RightElbow ~= nil and hide.joints.LeftElbow ~= nil).to.equal(true)
		end)

		it("wears the scared look, worried where an employee has none", function()
			expect(hide.look).to.equal("Scared")
			expect(hide.face).to.equal("Worried")
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
					-- A portrait-only look names a face in the model's Faces folder; the face is its fallback.
					if pose.look ~= nil then
						expect(type(pose.look)).to.equal("string")
						expect(#pose.look > 0).to.equal(true)
						expect(pose.face ~= nil).to.equal(true)
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
