local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShiftGloomSystem = require(script.Parent.ShiftGloomSystem)
local SignalTyped = require(ReplicatedStorage.Shared.Core.SignalTyped)
local ShiftConstants = require(ReplicatedStorage.Shared.Features.Shift.Data.ShiftConstants)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)

return function()
	local counters, open, credited, system

	beforeEach(function()
		counters = {}
		open = true
		credited = 0
		system = ShiftGloomSystem.new({
			isOpen = function()
				return open
			end,
			addTeam = function(counter, amount)
				counters[counter] = (counters[counter] or 0) + amount
			end,
			afterCredit = function()
				credited += 1
			end,
		})
	end)

	it("credits a cleared pile's Gloom to the contract and to the dust, the instant it is cleared", function()
		expect(system:pile()).to.equal(true)
		expect(counters[ShiftConstants.CLEARANCE]).to.equal(VacuumConstants.PILE_GLOOM)
		expect(counters[ShiftConstants.DUST]).to.equal(VacuumConstants.PILE_GLOOM)
		expect(credited).to.equal(1)
	end)

	it("credits an item's cleaned Gloom to the contract only", function()
		expect(system:grime(6)).to.equal(true)
		expect(counters[ShiftConstants.CLEARANCE]).to.equal(6)
		expect(counters[ShiftConstants.DUST]).to.equal(nil)
		expect(credited).to.equal(1)
	end)

	it("credits nothing outside a running shift", function()
		open = false
		expect(system:pile()).to.equal(false)
		expect(system:grime(6)).to.equal(false)
		expect(next(counters)).to.equal(nil)
		expect(credited).to.equal(0)
	end)

	it("ignores an empty or invalid amount", function()
		expect(system:grime(0)).to.equal(false)
		expect(system:grime(-3)).to.equal(false)
		expect(system:grime(0 / 0)).to.equal(false)
		expect(next(counters)).to.equal(nil)
	end)

	it("follows the vacuum's and the cargo's signals until stopped", function()
		local piles = SignalTyped.new()
		local grime = SignalTyped.new()
		local stop = system:start(piles, grime)
		piles:Fire(Instance.new("Part"), {})
		grime:Fire(Instance.new("Part"), 5)
		task.wait()
		expect(counters[ShiftConstants.CLEARANCE]).to.equal(VacuumConstants.PILE_GLOOM + 5)
		stop()
		piles:Fire(Instance.new("Part"), {})
		task.wait()
		expect(counters[ShiftConstants.CLEARANCE]).to.equal(VacuumConstants.PILE_GLOOM + 5)
	end)
end
