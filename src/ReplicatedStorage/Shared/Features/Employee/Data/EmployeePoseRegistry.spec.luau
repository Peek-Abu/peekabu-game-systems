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
					-- The idle pose is each employee's own (their idle's first frame); every other pose is shared.
					if poseName ~= "idle" then
						expect(set.poses[poseName].joints).to.equal(pose.joints)
					end
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
	describe("idle previews (owner 11-15: still previews show each employee's own idle)", function()
		local KIT = { "Pippa", "Cappy", "Prickles" }

		it("shows the idle pose wherever a preview has no context of its own", function()
			for _, name in EmployeePoseRegistry.names() do
				local set = EmployeePoseRegistry.get(name)
				expect(set.contexts.idle.pose).to.equal("idle")
				expect(set.contexts.idle.byLevel).never.to.be.ok()
			end
		end)

		it("holds Pippa, Cappy and Prickles each in their own idle, never the shared stand", function()
			local seen = {}
			for _, name in KIT do
				local idle = EmployeePoseRegistry.get(name).poses.idle
				expect(idle.name).to.equal("idle")
				expect(idle.joints).never.to.equal(EmployeePoseRegistry.get(name).poses.stand.joints)
				expect(next(idle.joints)).to.be.ok()
				expect(seen[idle.joints]).never.to.be.ok()
				seen[idle.joints] = true
			end
		end)

		it("keeps an employee without an idle pose of its own in the shared stand", function()
			for _, name in EmployeePoseRegistry.names() do
				local set = EmployeePoseRegistry.get(name)
				if EmployeePoseRegistry.IDLE_POSES[name] == nil then
					expect(set.poses.idle.joints).to.equal(set.poses.stand.joints)
				else
					expect(set.poses.idle.joints).to.equal(EmployeePoseRegistry.IDLE_POSES[name])
				end
			end
		end)

		it("leaves the rank places alone (profile, crew roster, ladder pose by rank)", function()
			local set = EmployeePoseRegistry.get("Cappy")
			for _, context in { "profile", "crew", "ladder" } do
				expect(set.contexts[context].byLevel).to.equal(EmployeePoseRegistry.RANK_POSES)
			end
		end)
	end)

	describe("rank poses (p075: a new pose at every rank)", function()
		local ORDER = { "shy", "wave", "proud", "point", "coachCheer", "cheer", "victory" }

		it("gives each of the seven ranks its own pose on the profile card, crew pictures and the ladder", function()
			local set = EmployeePoseRegistry.get("Pippa")
			for _, context in { "profile", "crew", "ladder" } do
				local levels = set.contexts[context].byLevel
				expect(levels).to.be.ok()
				for level, pose in ORDER do
					expect(levels[level]).to.equal(pose)
				end
			end
		end)

		it("shares one rank table, so the three places never disagree", function()
			local set = EmployeePoseRegistry.get("Cappy")
			expect(set.contexts.crew.byLevel).to.equal(set.contexts.profile.byLevel)
			expect(set.contexts.ladder.byLevel).to.equal(set.contexts.profile.byLevel)
			expect(EmployeePoseRegistry.RANK_POSES).to.equal(set.contexts.profile.byLevel)
		end)
	end)

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
