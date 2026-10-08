local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicationShared = ReplicatedStorage.Shared.Features.Replication
local ReplicationRunHarness = require(ReplicationShared.Testing.ReplicationRunHarness)
local ReplicationTraceHarness = require(ReplicationShared.Testing.ReplicationTraceHarness)
local ReplicationLinkHarness = require(ReplicationShared.Testing.ReplicationLinkHarness)
local ReplicationDesignHarness = require(ReplicationShared.Testing.ReplicationDesignHarness)

local SEEDS = { 1, 2, 3, 4 }
local MEAN_LIMIT = { studio = 0.07, good = 0.06, spec = 0.07, mobile = 0.16 }

local function runOnce(trace, profileName, seed, options, venture)
	local system, probe = ReplicationDesignHarness.new(venture or {
		groundBelow = function(position)
			return ReplicationTraceHarness.groundBelow(trace, position)
		end,
		uplinkOnChange = true,
	})
	return ReplicationRunHarness.run(system, trace, ReplicationLinkHarness.PROFILES[profileName], seed, 50, options),
		probe
end

return function()
	local parkour = ReplicationTraceHarness.parkour(Vector3.new(0, 100, 0))

	for _, profileName in { "studio", "good", "spec", "mobile" } do
		describe(`parkour over the {profileName} network`, function()
			local results = {}
			beforeAll(function()
				for _, seed in SEEDS do
					table.insert(results, (runOnce(parkour, profileName, seed)))
				end
			end)

			it("keeps the mean shape error under its limit", function()
				local sum = 0
				for _, r in results do
					sum += r.fidelity.mean
				end
				expect(sum / #results < MEAN_LIMIT[profileName]).to.equal(true)
			end)

			it("never draws a body more than 5 studs from its path", function()
				for _, r in results do
					expect(r.fidelity.max < 5).to.equal(true)
				end
			end)

			it("shows at most 2 pops and no freezes per run", function()
				for _, r in results do
					expect(r.pops <= 2).to.equal(true)
					expect(r.stalls).to.equal(0)
				end
			end)

			it("stays within the byte budget and never retransmits", function()
				for _, r in results do
					expect(r.upBytesPerSecond < 950).to.equal(true)
					expect(r.downBytesPerSecond < 1400).to.equal(true)
					expect(r.retransmits).to.equal(0)
				end
			end)
		end)
	end

	describe("a session with idle time", function()
		it("cuts the uplink when the player stands still", function()
			local trace = ReplicationTraceHarness.withIdle(parkour, { 5, "P", 10, "P", 6 })
			local r = runOnce(trace, "good", 1)
			expect(r.upBytesPerSecond < 650).to.equal(true)
			expect(r.fidelity.max < 5).to.equal(true)
		end)
	end)

	describe("a local stall (window in the background)", function()
		it("does not raise the render delay after the stall", function()
			local stallAtMs, stallForMs = 8000, 1600
			local _, probe = runOnce(parkour, "good", 1, { stallAtMs = stallAtMs, stallForMs = stallForMs })
			local before, after = nil, nil
			for _, entry in probe.delayLog do
				if entry.atMs < stallAtMs then
					before = entry.delayMs
				elseif entry.atMs >= stallAtMs + stallForMs + 1000 and after == nil then
					after = entry.delayMs
				end
			end
			expect(before).to.be.ok()
			expect(after).to.be.ok()
			expect(after <= before + 10).to.equal(true)
		end)
	end)
end
