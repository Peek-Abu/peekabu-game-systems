local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeStatOverrideTracker = require(script.Parent.EmployeeStatOverrideTracker)
local EmployeeProfileRegistry = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeProfileRegistry)

return function()
	it("gives the employee's own bars when nothing is overridden", function()
		local tracker = EmployeeStatOverrideTracker.new()
		local bars = tracker:barsFor(1, "Pippa")
		for _, stat in EmployeeProfileRegistry.STATS do
			expect(bars[stat]).to.equal(EmployeeProfileRegistry.get("Pippa").stats[stat])
		end
	end)

	it("uses an override for that stat only, clamped to 1-5", function()
		local tracker = EmployeeStatOverrideTracker.new()
		tracker:set(1, "speed", 9)
		local bars = tracker:barsFor(1, "Pippa")
		expect(bars.speed).to.equal(5)
		expect(bars.quiet).to.equal(EmployeeProfileRegistry.get("Pippa").stats.quiet)
		expect(tracker:barsFor(2, "Pippa").speed).to.equal(EmployeeProfileRegistry.get("Pippa").stats.speed)
	end)

	it("keeps an override across employees until it is cleared", function()
		local tracker = EmployeeStatOverrideTracker.new()
		tracker:set(1, "quiet", 1)
		expect(tracker:barsFor(1, "Cappy").quiet).to.equal(1)
		tracker:clear(1, "quiet")
		expect(tracker:barsFor(1, "Cappy").quiet).to.equal(EmployeeProfileRegistry.get("Cappy").stats.quiet)
	end)

	it("clears every override with no stat named, and forgets a leaver", function()
		local tracker = EmployeeStatOverrideTracker.new()
		tracker:set(1, "speed", 5)
		tracker:set(1, "stamina", 5)
		tracker:clear(1, nil)
		expect(tracker:count()).to.equal(0)
		tracker:set(2, "speed", 5)
		tracker:forget(2)
		expect(tracker:count()).to.equal(0)
	end)

	it("gives the floor for an employee without a profile", function()
		local tracker = EmployeeStatOverrideTracker.new()
		expect(tracker:barsFor(1, "Nobody").speed).to.equal(1)
	end)
end
