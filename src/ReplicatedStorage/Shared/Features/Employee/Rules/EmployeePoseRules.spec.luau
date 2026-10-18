local EmployeePoseRules = require(script.Parent.EmployeePoseRules)

return function()
	local function pose(name)
		return { name = name, joints = {} }
	end

	local set = {
		poses = { a = pose("a"), b = pose("b"), c = pose("c"), d = pose("d") },
		contexts = {
			profile = { pose = "a", byLevel = { [1] = "b", [3] = "c" } },
			crew = { pose = "a" },
			caught = { pose = "missing" },
			award = { pose = "a", byGrade = { A = "d", C = "b" } },
		},
	}

	describe("select", function()
		it("returns nil for an employee with no portrait set (shown at rest)", function()
			expect(EmployeePoseRules.select(nil, "profile", {})).never.to.be.ok()
		end)

		it("uses the context's pose when nothing else applies", function()
			expect(EmployeePoseRules.select(set, "crew", { level = 3 }).name).to.equal("a")
		end)

		it("uses the pose of the player's level", function()
			expect(EmployeePoseRules.select(set, "profile", { level = 1 }).name).to.equal("b")
			expect(EmployeePoseRules.select(set, "profile", { level = 3 }).name).to.equal("c")
		end)

		it("lets a level with no entry inherit the highest level under it", function()
			expect(EmployeePoseRules.select(set, "profile", { level = 2 }).name).to.equal("b")
			expect(EmployeePoseRules.select(set, "profile", { level = 7 }).name).to.equal("c")
		end)

		it("falls back to the context's pose under the lowest listed level or with no level", function()
			expect(EmployeePoseRules.select(set, "profile", { level = 0 }).name).to.equal("a")
			expect(EmployeePoseRules.select(set, "profile", {}).name).to.equal("a")
		end)

		it("uses the grade's pose, else the context's", function()
			expect(EmployeePoseRules.select(set, "award", { grade = "A" }).name).to.equal("d")
			expect(EmployeePoseRules.select(set, "award", { grade = "C" }).name).to.equal("b")
			expect(EmployeePoseRules.select(set, "award", { grade = "B" }).name).to.equal("a")
		end)

		it("prefers the grade over the level", function()
			local both = {
				poses = set.poses,
				contexts = { award = { pose = "a", byLevel = { [1] = "c" }, byGrade = { A = "d" } } },
			}
			expect(EmployeePoseRules.select(both, "award", { level = 2, grade = "A" }).name).to.equal("d")
			expect(EmployeePoseRules.select(both, "award", { level = 2, grade = "B" }).name).to.equal("c")
		end)

		it("returns nil when the named pose is missing", function()
			expect(EmployeePoseRules.select(set, "caught", {})).never.to.be.ok()
		end)

		it("returns nil for a context the set does not cover", function()
			local partial = { poses = set.poses, contexts = {} }
			expect(EmployeePoseRules.select(partial, "crew", {})).never.to.be.ok()
		end)
	end)
end
