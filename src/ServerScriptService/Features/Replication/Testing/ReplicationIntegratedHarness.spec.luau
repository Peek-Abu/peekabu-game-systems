local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicationShared = ReplicatedStorage.Shared.Features.Replication
local ReplicationRunHarness = require(ReplicationShared.Testing.ReplicationRunHarness)
local ReplicationTraceHarness = require(ReplicationShared.Testing.ReplicationTraceHarness)
local ReplicationLinkHarness = require(ReplicationShared.Testing.ReplicationLinkHarness)
local ReplicationIntegratedHarness = require(script.Parent.ReplicationIntegratedHarness)

local SEEDS = { 1, 2, 3, 4 }
-- R1's fidelity limits (ReplicationDesignHarness.spec), held against the integrated modules. The byte limits below
-- differ from R1's: the uplink now carries up to three records, and the viewer gets one reliable Enter.
local MEAN_LIMIT = { studio = 0.07, good = 0.06, spec = 0.07, mobile = 0.16 }

local NEAR_STUDS = 50
local FAR_STUDS = 400 -- beyond ReplicationDownlinkSystem's 300-stud far cap

local function runOnce(trace, profileName, seed, options, viewerDistance)
	local system, probe = ReplicationIntegratedHarness.new({
		groundBelow = function(position)
			return ReplicationTraceHarness.groundBelow(trace, position)
		end,
	})
	local profile = ReplicationLinkHarness.PROFILES[profileName]
	return ReplicationRunHarness.run(system, trace, profile, seed, viewerDistance or NEAR_STUDS, options), probe
end

return function()
	local parkour = ReplicationTraceHarness.parkour(Vector3.new(0, 100, 0))

	for _, profileName in { "studio", "good", "spec", "mobile" } do
		describe(`integrated R2 modules, parkour over the {profileName} network`, function()
			local results = {}
			beforeAll(function()
				for _, seed in SEEDS do
					table.insert(results, (runOnce(parkour, profileName, seed)))
				end
				-- One line per profile for the developer to compare with the saved scorecard results.
				local mean, p95, maxError, pops, stalls, up, down, latency = 0, 0, 0, 0, 0, 0, 0, 0
				for _, r in results do
					mean += r.fidelity.mean / #results
					p95 += r.fidelity.p95 / #results
					maxError = math.max(maxError, r.fidelity.max)
					pops += r.pops
					stalls += r.stalls
					up += r.upBytesPerSecond / #results
					down += r.downBytesPerSecond / #results
					latency += r.latencyMs / #results
				end
				print(
					string.format(
						"[R2 harness] %s: mean %.3f p95 %.3f max %.2f studs · pops %d freezes %d (%d runs) · up %.0f B/s down %.0f B/s · latency %.0f ms",
						profileName,
						mean,
						p95,
						maxError,
						pops,
						stalls,
						#results,
						up,
						down,
						latency
					)
				)
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
					-- Uplink: up to 3 records of redundancy (53 B) at 60 Hz while moving.
					expect(r.upBytesPerSecond < 3300).to.equal(true)
					expect(r.downBytesPerSecond < 1500).to.equal(true)
					expect(r.retransmits).to.equal(0)
				end
			end)
		end)
	end

	describe("integrated R2 modules, a session with idle time", function()
		it("cuts the uplink when the player stands still", function()
			local idle = ReplicationTraceHarness.withIdle(parkour, { 5, "P", 10, "P", 6 })
			local moving = runOnce(parkour, "good", 1)
			local mixed = runOnce(idle, "good", 1)
			expect(mixed.upBytesPerSecond < 0.75 * moving.upBytesPerSecond).to.equal(true)
			expect(mixed.fidelity.max < 5).to.equal(true)
		end)
	end)

	-- The far cap: a moving body 400 studs away reaches the viewer at about 30 Hz instead of 60. The printed
	-- line is the saving and the stutter it costs; the developer compares it with the near line above.
	for _, profileName in { "good", "mobile" } do
		describe(`integrated R2 modules, a body beyond the far cap over the {profileName} network`, function()
			local near, far = {}, {}
			beforeAll(function()
				for _, seed in SEEDS do
					table.insert(near, (runOnce(parkour, profileName, seed, nil, NEAR_STUDS)))
					table.insert(far, (runOnce(parkour, profileName, seed, nil, FAR_STUDS)))
				end
				local nearDown, farDown, mean, p95, maxError, pops, stalls = 0, 0, 0, 0, 0, 0, 0
				for i, r in far do
					nearDown += near[i].downBytesPerSecond / #far
					farDown += r.downBytesPerSecond / #far
					mean += r.fidelity.mean / #far
					p95 += r.fidelity.p95 / #far
					maxError = math.max(maxError, r.fidelity.max)
					pops += r.pops
					stalls += r.stalls
				end
				print(
					string.format(
						"[R2 harness] far cap %s (%d studs): down %.0f -> %.0f B/s (%.0f %% saved) · mean %.3f p95 %.3f max %.2f studs · pops %d freezes %d (%d runs)",
						profileName,
						FAR_STUDS,
						nearDown,
						farDown,
						(1 - farDown / nearDown) * 100,
						mean,
						p95,
						maxError,
						pops,
						stalls,
						#far
					)
				)
			end)

			it("saves download for a moving far body (at least a quarter where the link runs above 30 Hz)", function()
				-- Mobile link delivers ~30/s already (16% saved); good link runs faster so > 30 Hz ceiling saves more (49%).
				for i, r in far do
					expect(r.downBytesPerSecond <= near[i].downBytesPerSecond).to.equal(true)
					if profileName == "good" then
						expect(r.downBytesPerSecond < 0.75 * near[i].downBytesPerSecond).to.equal(true)
					end
				end
			end)

			it("draws the far body without freezes, at most 2 pops, never more than 5 studs off", function()
				for _, r in far do
					expect(r.stalls).to.equal(0)
					expect(r.pops <= 2).to.equal(true)
					expect(r.fidelity.max < 5).to.equal(true)
				end
			end)
		end)
	end

	describe("integrated R2 modules, a local stall (window in the background)", function()
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
