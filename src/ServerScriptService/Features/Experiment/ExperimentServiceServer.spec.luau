local Workspace = game:GetService("Workspace")

local ExperimentServiceServer = require(script.Parent.ExperimentServiceServer)
local ExperimentRegistry = require(script.Parent.Data.ExperimentRegistry)

return function()
	local saved
	beforeAll(function()
		saved = Workspace:GetAttribute(ExperimentServiceServer.OVERRIDE_ATTRIBUTE)
		Workspace:SetAttribute(ExperimentServiceServer.OVERRIDE_ATTRIBUTE, nil)
	end)
	afterAll(function()
		Workspace:SetAttribute(ExperimentServiceServer.OVERRIDE_ATTRIBUTE, saved)
	end)

	describe("playerVariant", function()
		it("is the hash variant for the player's user id", function()
			-- exp-friendskip is per crew; use a per-player one with a pinned key
			expect(ExperimentServiceServer:playerVariant({ UserId = 156 }, "exp-tutorial")).to.equal("5beats")
		end)

		it("gives a fake player with a negative user id a registry variant", function()
			local variant = ExperimentServiceServer:playerVariant({ UserId = -1 }, "exp-tutorial")
			expect(table.find(ExperimentRegistry.get("exp-tutorial").variants, variant) ~= nil).to.equal(true)
		end)

		it("errors on an unknown id", function()
			expect(function()
				ExperimentServiceServer:playerVariant({ UserId = 1 }, "exp-nope")
			end).to.throw()
		end)

		it("errors when asked per player for a per-crew experiment", function()
			expect(function()
				ExperimentServiceServer:playerVariant({ UserId = 1 }, "exp-friendskip")
			end).to.throw()
		end)
	end)

	describe("crewVariant", function()
		it("is the same for every member of one crew", function()
			expect(ExperimentServiceServer:crewVariant("studio", "exp-friendskip")).to.equal("forced")
			expect(ExperimentServiceServer:crewVariant("studio", "exp-friendskip")).to.equal("forced")
		end)

		it("errors loudly on an empty crew id", function()
			expect(function()
				ExperimentServiceServer:crewVariant("", "exp-friendskip")
			end).to.throw()
		end)

		it("errors when asked per crew for a per-player experiment", function()
			expect(function()
				ExperimentServiceServer:crewVariant("studio", "exp-stars")
			end).to.throw()
		end)
	end)

	describe("crewId", function()
		it("is studio when there is no JobId", function()
			if game.JobId == "" then
				expect(ExperimentServiceServer:crewId()).to.equal("studio")
			end
		end)
	end)

	describe("variantOf", function()
		it("uses the crew id for a crew experiment and the user id for a player one", function()
			local player = { UserId = 156 }
			expect(ExperimentServiceServer:variantOf(player, "exp-friendskip")).to.equal(
				ExperimentServiceServer:crewVariant(ExperimentServiceServer:crewId(), "exp-friendskip")
			)
			expect(ExperimentServiceServer:variantOf(player, "exp-tutorial")).to.equal("5beats")
		end)

		it("errors on an unknown id", function()
			expect(function()
				ExperimentServiceServer:variantOf({ UserId = 1 }, "exp-nope")
			end).to.throw()
		end)
	end)

	describe("overrides", function()
		it("win over the hash, for both units", function()
			Workspace:SetAttribute(
				ExperimentServiceServer.OVERRIDE_ATTRIBUTE,
				"exp-friendskip=skip,exp-tutorial=3beats"
			)
			expect(ExperimentServiceServer:crewVariant("studio", "exp-friendskip")).to.equal("skip")
			expect(ExperimentServiceServer:playerVariant({ UserId = 156 }, "exp-tutorial")).to.equal("3beats")
			Workspace:SetAttribute(ExperimentServiceServer.OVERRIDE_ATTRIBUTE, nil)
		end)
	end)

	describe("assignments", function()
		it("lists per-player experiments, plus crew ones only when asked, with their source", function()
			Workspace:SetAttribute(ExperimentServiceServer.OVERRIDE_ATTRIBUTE, "exp-stars=flat")
			local player = { UserId = 7 }
			local personal = ExperimentServiceServer:assignments(player, false)
			-- The registry holds 9 experiments: 8 per player, 1 per crew.
			expect(#personal).to.equal(8)
			local all = ExperimentServiceServer:assignments(player, true)
			expect(#all).to.equal(9)
			for _, assignment in all do
				if assignment.experimentId == "exp-stars" then
					expect(assignment.variant).to.equal("flat")
					expect(assignment.source).to.equal("override")
				else
					expect(assignment.source).to.equal("hash")
				end
			end
			Workspace:SetAttribute(ExperimentServiceServer.OVERRIDE_ATTRIBUTE, nil)
		end)
	end)
end
