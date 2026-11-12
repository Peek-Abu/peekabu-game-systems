--[[
	Unit tests for the trainingreset Cmdr command. Mock strategy (the CurrencyAddServer.spec convention): patch
	TrainingServiceServer.reset and TipServiceServer.reset inside beforeAll/afterAll.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local TipService = require(ServerScriptService.Features.Tip.TipServiceServer)
local TrainingService = require(ServerScriptService.Features.Training.TrainingServiceServer)
local resetCommand = require(ServerScriptService.Commands.TrainingResetServer)

local me = { UserId = 41, Name = "Me" }
local other = { UserId = 42, Name = "Other" }

return function()
	describe("TrainingResetServer", function()
		local originalTraining
		local originalTips
		local trainingResult = true
		local trainingUser = nil
		local tipsUser = nil

		beforeAll(function()
			originalTraining = TrainingService.reset
			originalTips = TipService.reset
			TrainingService.reset = function(_self, userId)
				trainingUser = userId
				return trainingResult
			end
			TipService.reset = function(_self, userId)
				tipsUser = userId
				return true
			end
		end)

		afterAll(function()
			TrainingService.reset = originalTraining
			TipService.reset = originalTips
		end)

		beforeEach(function()
			trainingUser = nil
			tipsUser = nil
		end)

		it("resets the admin's own training and tips with no player named", function()
			trainingResult = true
			expect(resetCommand({ Executor = me }, nil):find("Me")).to.be.ok()
			expect(trainingUser).to.equal(41)
			expect(tipsUser).to.equal(41)
		end)

		it("resets the named player's training and tips", function()
			trainingResult = true
			expect(resetCommand({ Executor = me }, other):find("Other")).to.be.ok()
			expect(trainingUser).to.equal(42)
			expect(tipsUser).to.equal(42)
		end)

		it("says so when the save is not loaded", function()
			trainingResult = false
			expect(resetCommand({ Executor = me }, nil):find("not loaded")).to.be.ok()
			expect(tipsUser).to.equal(nil)
		end)
	end)
end
