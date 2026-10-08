--!strict
--[=[
	Unit tests for VoiceWiringTracker (R5 spec §2.3): wire once a player's input AND puppet head both exist, rewire
	when either is replaced, unwire on a current head's despawn or on leave, ignore a stale despawn.
]=]

local VoiceWiringTracker = require(script.Parent.VoiceWiringTracker)

return function()
	local state, instances

	local function part()
		local p = Instance.new("Part")
		table.insert(instances, p)
		return p
	end

	local function input()
		local i = Instance.new("Folder") -- any Instance stands in for an AudioDeviceInput here
		table.insert(instances, i)
		return i
	end

	local function kinds(actions)
		local out = {}
		for _, action in actions do
			table.insert(out, action.kind)
		end
		return table.concat(out, ",")
	end

	beforeEach(function()
		state = VoiceWiringTracker.new()
		instances = {}
	end)

	afterEach(function()
		for _, i in instances do
			i:Destroy()
		end
	end)

	it("wires once both exist, in either order", function()
		local mic, head = input(), part()
		expect(kinds(VoiceWiringTracker.setInput(state, 2, mic))).to.equal("")
		local actions = VoiceWiringTracker.setHead(state, 2, head)
		expect(kinds(actions)).to.equal("wire")
		expect(actions[1].input).to.equal(mic)
		expect(actions[1].head).to.equal(head)

		expect(kinds(VoiceWiringTracker.setHead(state, 3, part()))).to.equal("")
		expect(kinds(VoiceWiringTracker.setInput(state, 3, input()))).to.equal("wire")
		expect(VoiceWiringTracker.wiredCount(state)).to.equal(2)
	end)

	it("setting the same input or head again does nothing", function()
		local mic, head = input(), part()
		VoiceWiringTracker.setInput(state, 2, mic)
		VoiceWiringTracker.setHead(state, 2, head)
		expect(kinds(VoiceWiringTracker.setInput(state, 2, mic))).to.equal("")
		expect(kinds(VoiceWiringTracker.setHead(state, 2, head))).to.equal("")
	end)

	it("a new head (puppet rebuilt or reused) rewires to it", function()
		VoiceWiringTracker.setInput(state, 2, input())
		VoiceWiringTracker.setHead(state, 2, part())
		local newHead = part()
		local actions = VoiceWiringTracker.setHead(state, 2, newHead)
		expect(kinds(actions)).to.equal("unwire,wire")
		expect(actions[2].head).to.equal(newHead)
	end)

	-- A replaced input rewires to the new one; a removed input unwires.
	it("a replaced input rewires to the new one; a removed input unwires", function()
		VoiceWiringTracker.setInput(state, 2, input())
		VoiceWiringTracker.setHead(state, 2, part())
		local newMic = input()
		local actions = VoiceWiringTracker.setInput(state, 2, newMic)
		expect(kinds(actions)).to.equal("unwire,wire")
		expect(actions[2].input).to.equal(newMic)
		expect(kinds(VoiceWiringTracker.setInput(state, 2, nil))).to.equal("unwire")
		expect(VoiceWiringTracker.wiredCount(state)).to.equal(0)
	end)

	it("clearHead unwires the current head", function()
		local head = part()
		VoiceWiringTracker.setInput(state, 2, input())
		VoiceWiringTracker.setHead(state, 2, head)
		expect(kinds(VoiceWiringTracker.clearHead(state, 2, head))).to.equal("unwire")
	end)

	-- A stale despawn of an older puppet must not cut the live wiring.
	it("clearHead ignores a head that is not current", function()
		local oldHead, newHead = part(), part()
		VoiceWiringTracker.setInput(state, 2, input())
		VoiceWiringTracker.setHead(state, 2, oldHead)
		VoiceWiringTracker.setHead(state, 2, newHead)
		expect(kinds(VoiceWiringTracker.clearHead(state, 2, oldHead))).to.equal("")
		expect(VoiceWiringTracker.wiredCount(state)).to.equal(1)
	end)

	it("remove unwires and forgets; the same id can rejoin cleanly", function()
		VoiceWiringTracker.setInput(state, 2, input())
		VoiceWiringTracker.setHead(state, 2, part())
		expect(kinds(VoiceWiringTracker.remove(state, 2))).to.equal("unwire")
		expect(kinds(VoiceWiringTracker.remove(state, 2))).to.equal("")
		expect(kinds(VoiceWiringTracker.setInput(state, 2, input()))).to.equal("")
		expect(kinds(VoiceWiringTracker.setHead(state, 2, part()))).to.equal("wire")
	end)

	it("a puppet with no head never wires", function()
		VoiceWiringTracker.setInput(state, 2, input())
		expect(kinds(VoiceWiringTracker.setHead(state, 2, nil))).to.equal("")
		expect(VoiceWiringTracker.wiredCount(state)).to.equal(0)
	end)

	it("the falloff is full to 10 studs and silent at 80", function()
		expect(VoiceWiringTracker.FALLOFF[0]).to.equal(1)
		expect(VoiceWiringTracker.FALLOFF[10]).to.equal(1)
		expect(VoiceWiringTracker.FALLOFF[80]).to.equal(0)
	end)
end
