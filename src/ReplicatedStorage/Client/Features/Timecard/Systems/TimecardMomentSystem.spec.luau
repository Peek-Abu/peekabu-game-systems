local System = require(script.Parent.TimecardMomentSystem)
local Store = require(script.Parent.Parent.State.TimecardMomentStore)

local MONDAY = 1792972800
local DAY = 86400

local function card(punched, weeks)
	return { week = MONDAY, punched = punched, weeks = weeks or 0 }
end

local function fakeDeps()
	local deps = { played = {}, timers = {}, opened = 0 }
	deps.play = function(id)
		table.insert(deps.played, id)
	end
	deps.delay = function(seconds, callback)
		table.insert(deps.timers, { seconds = seconds, callback = callback })
	end
	deps.open = function()
		deps.opened += 1
	end
	return deps
end

local function runTimers(deps)
	local timers = deps.timers
	deps.timers = {}
	for _, timer in timers do
		timer.callback()
	end
end

return function()
	afterEach(function()
		Store.reset()
	end)

	describe("punched", function()
		it("stamps an awaited punch, plays the clock and the stamp, and takes the stamp down later", function()
			local deps = fakeDeps()
			Store.expect(true)
			local moment = System.punched(card({ 1 }), card({ 1, 3 }), MONDAY + 2 * DAY, deps)
			expect(moment.count).to.equal(2)
			expect(Store.stamp()).to.equal(moment)
			expect(Store.expecting()).to.equal(false)
			expect(deps.played[1]).to.equal(System.SOUNDS.clock)
			runTimers(deps)
			expect(table.find(deps.played, System.SOUNDS.stamp)).to.be.ok()
			expect(table.find(deps.played, System.SOUNDS.reward)).never.to.be.ok()
			expect(Store.stamp()).never.to.be.ok()
		end)

		it("adds the reward fanfare on a punch that paid", function()
			local deps = fakeDeps()
			Store.expect(true)
			System.punched(card({ 1, 2 }), card({ 1, 2, 4 }), MONDAY + 3 * DAY, deps)
			runTimers(deps)
			expect(table.find(deps.played, System.SOUNDS.reward)).to.be.ok()
		end)

		it("never stamps a card that arrived without a request (the first sync)", function()
			local deps = fakeDeps()
			expect(System.punched(card({}), card({ 1 }), MONDAY + 60, deps)).never.to.be.ok()
			expect(Store.stamp()).never.to.be.ok()
			expect(#deps.played).to.equal(0)
		end)
	end)

	describe("greet", function()
		it("opens the Timecard once for the day", function()
			local deps = fakeDeps()
			local input = { synced = true, inHub = true, busy = false, canPunch = true, greeted = nil, day = 20754 }
			expect(System.greet(input, deps)).to.equal(true)
			expect(deps.opened).to.equal(1)
			expect(Store.greeted()).to.equal(20754)
			input.greeted = Store.greeted()
			expect(System.greet(input, deps)).to.equal(false)
			expect(deps.opened).to.equal(1)
		end)

		it("does not open while another screen is up", function()
			local deps = fakeDeps()
			local input = { synced = true, inHub = true, busy = true, canPunch = true, greeted = nil, day = 20754 }
			expect(System.greet(input, deps)).to.equal(false)
			expect(deps.opened).to.equal(0)
		end)
	end)
end
