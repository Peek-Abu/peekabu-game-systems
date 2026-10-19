local ServerScriptService = game:GetService("ServerScriptService")

local ExperimentAssignUtils = require(script.Parent.ExperimentAssignUtils)
local ExperimentRegistry = require(ServerScriptService.Features.Experiment.Data.ExperimentRegistry)

return function()
	describe("hash", function()
		it("matches the FNV-1a reference values", function()
			expect(ExperimentAssignUtils.fnv1a("")).to.equal(2166136261)
			expect(ExperimentAssignUtils.fnv1a("a")).to.equal(3826002220)
		end)

		it("is pinned: changing it would reassign every player", function()
			expect(ExperimentAssignUtils.hash("exp-clean:1")).to.equal(2514140076)
			expect(ExperimentAssignUtils.hash("exp-clean:2")).to.equal(1450326417)
			expect(ExperimentAssignUtils.hash("exp-rehire:studio")).to.equal(2903978199)
			expect(ExperimentAssignUtils.hash("exp-stars:3000000001")).to.equal(3522039271)
		end)
	end)

	describe("bucket", function()
		it("is 1 for an even hash and 2 for an odd one", function()
			expect(ExperimentAssignUtils.bucket("exp-clean", "1")).to.equal(1)
			expect(ExperimentAssignUtils.bucket("exp-clean", "2")).to.equal(2)
		end)

		it("is stable for the same key", function()
			for _ = 1, 5 do
				expect(ExperimentAssignUtils.bucket("exp-tutorial", "156")).to.equal(2)
			end
		end)

		it("splits 10,000 sequential user ids close to 50/50", function()
			local ones = 0
			for userId = 1, 10000 do
				if ExperimentAssignUtils.bucket("exp-tutorial", tostring(userId)) == 1 then
					ones += 1
				end
			end
			expect(ones >= 4700 and ones <= 5300).to.equal(true)
		end)

		it("keeps two experiments independent for the same players", function()
			local combos = { 0, 0, 0, 0 }
			for userId = 1, 10000 do
				local key = tostring(userId)
				local index = (ExperimentAssignUtils.bucket("exp-tutorial", key) - 1) * 2
					+ ExperimentAssignUtils.bucket("exp-stars", key)
				combos[index] += 1
			end
			for _, count in combos do
				expect(count >= 2200 and count <= 2800).to.equal(true)
			end
		end)

		it("handles Studio's negative user ids", function()
			local bucket = ExperimentAssignUtils.bucket("exp-coffee", tostring(-1))
			expect(bucket == 1 or bucket == 2).to.equal(true)
		end)
	end)

	describe("variantFor", function()
		it("returns the definition's variant for the bucket", function()
			local def = ExperimentRegistry.get("exp-clean")
			expect(ExperimentAssignUtils.variantFor(def, "1")).to.equal("1.5s")
			expect(ExperimentAssignUtils.variantFor(def, "2")).to.equal("3s")
		end)
	end)
end
