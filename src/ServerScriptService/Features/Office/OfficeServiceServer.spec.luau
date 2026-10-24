--[[
	Integration specs for the anomalies OfficeServiceServer publishes (stage 4 variation). They drive the live service
	(beginShift rebuilds the office; reset puts it back), so they only run where this server builds an office.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OfficeServer = ServerScriptService.Features.Office
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeVariationRules = require(OfficeServer.Rules.OfficeVariationRules)
local OfficeServiceServer = require(OfficeServer.OfficeServiceServer)
local QueueServiceServer = require(ServerScriptService.Features.Queue.QueueServiceServer)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local OfficeAnomalyConstants = require(ReplicatedStorage.Shared.Features.Office.Data.OfficeAnomalyConstants)

local ATTRIBUTE = OfficeAnomalyConstants.PUBLISHED_ATTRIBUTE

return function()
	describe("OfficeServiceServer anomalies", function()
		local runs = QueueServiceServer:runsRole(DepotConstants.ROLE_SHIFT)

		local function model()
			return workspace:FindFirstChild(OfficeConstants.MODEL_NAME)
		end

		local function begin(seed)
			OfficeServiceServer:beginShift({ seed = seed, variant = "A", quota = 100 })
		end

		afterEach(function()
			if runs then
				OfficeServiceServer:reset()
			end
		end)

		it("publishes anomalies(seed) on the rebuilt model", function()
			if not runs then
				return
			end
			for _, seed in { 3, 11, 42 } do
				begin(seed)
				local used = OfficeServiceServer:seed()
				local expected = OfficeVariationRules.anomalies(used)
				expect(#expected > 0).to.equal(true)
				expect(model():GetAttribute(ATTRIBUTE)).to.equal(table.concat(expected, ","))
				expect(table.concat(OfficeServiceServer:anomalies(), ",")).to.equal(table.concat(expected, ","))
			end
		end)

		it("forces exactly one anomaly, none, and restores the seed's pick", function()
			if not runs then
				return
			end
			begin(11)
			local picked = table.concat(OfficeVariationRules.anomalies(OfficeServiceServer:seed()), ",")
			expect(OfficeServiceServer:forceAnomalies({ "wetFloor" })).to.equal(true)
			expect(model():GetAttribute(ATTRIBUTE)).to.equal("wetFloor")
			expect(#OfficeServiceServer:anomalies()).to.equal(1)
			OfficeServiceServer:forceAnomalies({})
			expect(model():GetAttribute(ATTRIBUTE)).to.equal("")
			expect(#OfficeServiceServer:anomalies()).to.equal(0)
			OfficeServiceServer:forceAnomalies(nil)
			expect(model():GetAttribute(ATTRIBUTE)).to.equal(picked)
		end)

		it("drops a forced set when the office is rebuilt", function()
			if not runs then
				return
			end
			begin(11)
			OfficeServiceServer:forceAnomalies({ "banner" })
			begin(11)
			expect(model():GetAttribute(ATTRIBUTE)).to.equal(
				table.concat(OfficeVariationRules.anomalies(OfficeServiceServer:seed()), ",")
			)
		end)
	end)
end
