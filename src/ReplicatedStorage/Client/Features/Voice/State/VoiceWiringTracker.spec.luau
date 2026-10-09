local VoiceWiringTracker = require(script.Parent.VoiceWiringTracker)

local input = {}
local head = {}
local otherHead = {}

local function kinds(actions)
	local list = {}
	for _, action in actions do
		table.insert(list, if action.kind == "wire" then `wire:{action.route}` else "unwire")
	end
	return table.concat(list, ",")
end

return function()
	it("wires a spatial speaker only once both input and head exist", function()
		local tracker = VoiceWiringTracker.new()
		expect(kinds(tracker:setRoute(1, "spatial"))).to.equal("")
		expect(kinds(tracker:setInput(1, input))).to.equal("")
		expect(kinds(tracker:setHead(1, head))).to.equal("wire:spatial")
		expect(tracker:wiredCount()).to.equal(1)
	end)

	it("wires radio and direct routes without a head", function()
		local tracker = VoiceWiringTracker.new()
		tracker:setInput(1, input)
		expect(kinds(tracker:setRoute(1, "radio"))).to.equal("wire:radio")
		expect(kinds(tracker:setRoute(1, "direct"))).to.equal("unwire,wire:direct")
	end)

	it("rewires when the head changes and unwires when the route becomes none", function()
		local tracker = VoiceWiringTracker.new()
		tracker:setInput(1, input)
		tracker:setRoute(1, "spatial")
		tracker:setHead(1, head)
		expect(kinds(tracker:setHead(1, otherHead))).to.equal("unwire,wire:spatial")
		expect(kinds(tracker:setRoute(1, "none"))).to.equal("unwire")
		expect(tracker:wiredCount()).to.equal(0)
	end)

	it("keeps a radio route wired when the head goes away", function()
		local tracker = VoiceWiringTracker.new()
		tracker:setInput(1, input)
		tracker:setRoute(1, "radio")
		expect(kinds(tracker:setHead(1, nil))).to.equal("")
	end)

	it("does nothing when nothing changed", function()
		local tracker = VoiceWiringTracker.new()
		tracker:setInput(1, input)
		tracker:setRoute(1, "direct")
		expect(kinds(tracker:setRoute(1, "direct"))).to.equal("")
	end)

	it("unwires and forgets a player who leaves", function()
		local tracker = VoiceWiringTracker.new()
		tracker:setInput(1, input)
		tracker:setRoute(1, "direct")
		expect(kinds(tracker:remove(1))).to.equal("unwire")
		expect(kinds(tracker:remove(1))).to.equal("")
		expect(tracker:wiredCount()).to.equal(0)
	end)
end
