--[[
	Integration specs for the anomalies OfficeServiceServer publishes (stage 4 variation) and the map a shift is built
	on (office or school, the truck host's pick). They drive the live service
	(beginShift rebuilds the office; reset puts it back), so they only run where this server builds an office.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local OfficeServer = ServerScriptService.Features.Office
local OfficeConstants = require(OfficeServer.Data.OfficeConstants)
local OfficeVariationRules = require(OfficeServer.Rules.OfficeVariationRules)
local OfficeServiceServer = require(OfficeServer.OfficeServiceServer)
local OfficeBuildPaceTracker = require(OfficeServer.State.OfficeBuildPaceTracker)
local QueueServiceServer = require(ServerScriptService.Features.Queue.QueueServiceServer)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)
local OfficeAnomalyConstants = require(ReplicatedStorage.Shared.Features.Office.Data.OfficeAnomalyConstants)

local ATTRIBUTE = OfficeAnomalyConstants.PUBLISHED_ATTRIBUTE
local MAP_ATTRIBUTE = OfficeConstants.MAP_ATTRIBUTE

return function()
	describe("OfficeServiceServer anomalies", function()
		local runs = QueueServiceServer:runsRole(DepotConstants.ROLE_SHIFT)

		local function model()
			return workspace:FindFirstChild(OfficeConstants.MODEL_NAME)
		end

		local function begin(seed)
			OfficeServiceServer:beginShift({ seed = seed, variant = "A", quota = 100, map = "office" })
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
			OfficeServiceServer:forceAnomalies({ "leaningLamp" })
			begin(11)
			expect(model():GetAttribute(ATTRIBUTE)).to.equal(
				table.concat(OfficeVariationRules.anomalies(OfficeServiceServer:seed()), ",")
			)
		end)
	end)

	describe("OfficeServiceServer map", function()
		local runs = QueueServiceServer:runsRole(DepotConstants.ROLE_SHIFT)

		local function model()
			return workspace:FindFirstChild(OfficeConstants.MODEL_NAME)
		end

		local function begin(seed, map)
			OfficeServiceServer:beginShift({ seed = seed, variant = "A", quota = 100, map = map })
		end

		afterEach(function()
			if runs then
				OfficeServiceServer:reset()
			end
		end)

		it("builds the School for a school shift and says so", function()
			if not runs then
				return
			end
			begin(7, "school")
			expect(OfficeServiceServer:map()).to.equal("school")
			expect(model():GetAttribute(MAP_ATTRIBUTE)).to.equal("school")
			expect(#OfficeServiceServer:route() > 0).to.equal(true)
		end)

		it("builds the Office for an office shift, after a school one", function()
			if not runs then
				return
			end
			begin(7, "school")
			begin(7, "office")
			expect(OfficeServiceServer:map()).to.equal("office")
			expect(model():GetAttribute(MAP_ATTRIBUTE)).to.equal("office")
		end)

		-- A whole map build is seconds of work: it yields a frame between pieces so no resumption holds the server
		-- (or trips Play's 10 s script timeout). One piece's work may run past the slice, never a whole pass.
		for _, map in { "school", "office" } do
			it(`builds the {map} in slices, never holding the server for long`, function()
				if not runs then
					return
				end
				begin(13, map)
				local stats = OfficeBuildPaceTracker.shared:stats()
				expect(stats.yields > 0).to.equal(true)
				expect(stats.longest < OfficeConstants.BUILD_SLICE_SECONDS + 0.5).to.equal(true)
			end)
		end

		it("walks the same School route for the same seed", function()
			if not runs then
				return
			end
			begin(21, "school")
			local first = OfficeServiceServer:route()
			local seed = OfficeServiceServer:seed()
			begin(21, "school")
			expect(OfficeServiceServer:seed()).to.equal(seed)
			local again = OfficeServiceServer:route()
			expect(#again).to.equal(#first)
			for index, point in first do
				expect((again[index] - point).Magnitude < 1e-3).to.equal(true)
			end
		end)
	end)
end
