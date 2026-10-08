local AnimationGrantTracker = require(script.Parent.AnimationGrantTracker)

local PLAYER = { UserId = 42, Name = "TestPlayer" }
local OTHER = { UserId = 43, Name = "Other" }

return function()
	local now, bodies, started, stopped, tracker

	beforeEach(function()
		now = 1000
		bodies = { [PLAYER] = true, [OTHER] = true }
		started, stopped = {}, {}
		tracker = AnimationGrantTracker.new({
			started = function(player, key, data, durationMs)
				table.insert(started, { player = player, key = key, data = data, durationMs = durationMs })
			end,
			stopped = function(player, key)
				table.insert(stopped, { player = player, key = key })
			end,
		}, function()
			return now
		end, function(player)
			return bodies[player] == true
		end)
	end)

	it("records a grant and sends it to the owner", function()
		expect(tracker:set(PLAYER, "full", "leap", now, 500)).to.equal("created")
		expect(#started).to.equal(1)
		expect(started[1].player).to.equal(PLAYER)
		expect(started[1].data).to.equal("leap")
		expect(started[1].durationMs).to.equal(500)
		expect(tracker:get(PLAYER, "full").data).to.equal("leap")
	end)

	it("reports a replacement on a live layer", function()
		tracker:set(PLAYER, "full", "leap", now, 500)
		expect(tracker:set(PLAYER, "full", "guard", now, 500)).to.equal("replaced")
		expect(tracker:get(PLAYER, "full").data).to.equal("guard")
	end)

	it("refuses a player with no character and sends nothing", function()
		bodies[PLAYER] = nil
		expect(tracker:set(PLAYER, "full", "leap", now, 500)).to.equal("no-body")
		expect(#started).to.equal(0)
		expect(tracker:get(PLAYER, "full")).to.equal(nil)
	end)

	it("expires a timed grant on its own, and a later set is a create", function()
		tracker:set(PLAYER, "full", "leap", now, 500)
		now += 500
		expect(tracker:get(PLAYER, "full")).to.equal(nil)
		expect(tracker:set(PLAYER, "full", "leap", now, 500)).to.equal("created")
	end)

	it("keeps an open-ended (looped) grant until it is cleared", function()
		tracker:set(PLAYER, "upper", "pose", now, nil)
		now += 1e6
		expect(tracker:get(PLAYER, "upper").data).to.equal("pose")
		expect(tracker:clear(PLAYER, "upper")).to.equal(true)
		expect(#stopped).to.equal(1)
		expect(stopped[1].key).to.equal("upper")
		expect(tracker:get(PLAYER, "upper")).to.equal(nil)
	end)

	it("clear is false and silent for an empty or expired layer", function()
		expect(tracker:clear(PLAYER, "full")).to.equal(false)
		tracker:set(PLAYER, "full", "leap", now, 100)
		now += 100
		expect(tracker:clear(PLAYER, "full")).to.equal(false)
		expect(#stopped).to.equal(0)
	end)

	it("keeps players apart", function()
		tracker:set(PLAYER, "full", "leap", now, 500)
		expect(tracker:get(OTHER, "full")).to.equal(nil)
		expect(tracker:clear(OTHER, "full")).to.equal(false)
	end)

	it("forget drops a player's grants without sending a stop", function()
		tracker:set(PLAYER, "full", "leap", now, nil)
		tracker:forget(PLAYER)
		expect(tracker:get(PLAYER, "full")).to.equal(nil)
		expect(#stopped).to.equal(0)
	end)
end
