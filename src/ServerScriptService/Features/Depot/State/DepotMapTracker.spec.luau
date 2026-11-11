local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DepotMapTracker = require(script.Parent.DepotMapTracker)
local DepotMapRules = require(ReplicatedStorage.Shared.Features.Depot.Rules.DepotMapRules)

return function()
	local tracker

	beforeEach(function()
		tracker = DepotMapTracker.new()
	end)

	it("plays the office on a truck nobody picked for", function()
		expect(tracker:mapOf("pad1")).to.equal("office")
	end)

	it("keeps a pick per truck and says when it changed", function()
		expect(tracker:pick("pad1", "school")).to.equal(true)
		expect(tracker:mapOf("pad1")).to.equal("school")
		expect(tracker:mapOf("pad2")).to.equal("office")
		expect(tracker:pick("pad1", "school")).to.equal(false)
		expect(tracker:pick("pad1", "office")).to.equal(true)
		expect(tracker:mapOf("pad1")).to.equal("office")
	end)

	it("forgets a truck's pick when it is cleared (the party left)", function()
		tracker:pick("pad1", "school")
		expect(tracker:clear("pad1")).to.equal(true)
		expect(tracker:mapOf("pad1")).to.equal("office")
		expect(tracker:clear("pad1")).to.equal(false)
	end)

	it("forgets the picks of trucks that emptied, keeping the rest", function()
		tracker:pick("pad1", "school")
		tracker:pick("pad2", "school")
		expect(tracker:retain({ pad2 = true })).to.equal(true)
		expect(tracker:mapOf("pad1")).to.equal("office")
		expect(tracker:mapOf("pad2")).to.equal("school")
		expect(tracker:retain({ pad2 = true })).to.equal(false)
	end)

	it("publishes the picks as plain data a client decodes", function()
		tracker:pick("pad1", "school")
		tracker:pick("pad2", "office")
		local picks = DepotMapRules.decode(tracker:snapshot())
		expect(picks.pad1).to.equal("school")
		expect(picks.pad2).to.equal("office")
		tracker:clear("pad1")
		expect(DepotMapRules.decode(tracker:snapshot()).pad1).to.equal(nil)
	end)

	it("forgets everything on reset", function()
		tracker:pick("pad1", "school")
		tracker:reset()
		expect(tracker:mapOf("pad1")).to.equal("office")
		expect(next(tracker:snapshot())).to.equal(nil)
	end)
end
