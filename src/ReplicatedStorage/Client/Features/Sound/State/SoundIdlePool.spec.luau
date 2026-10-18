local SoundIdlePool = require(script.Parent.SoundIdlePool)

return function()
	local footA = {}
	local footB = {}

	it("hands back nothing for a place with no idle voice", function()
		local pool = SoundIdlePool.new()
		expect(pool:take(footA)).to.equal(nil)
		expect(pool:count()).to.equal(0)
	end)

	it("keeps a released voice for its own place only", function()
		local pool = SoundIdlePool.new()
		local voice = { name = "v1" }
		expect(pool:put(footA, voice, 3)).to.equal(true)
		expect(pool:take(footB)).to.equal(nil)
		expect(pool:take(footA)).to.equal(voice)
		expect(pool:take(footA)).to.equal(nil)
	end)

	it("hands back the most recently released voice first", function()
		local pool = SoundIdlePool.new()
		local older, newer = { name = "older" }, { name = "newer" }
		pool:put(footA, older, 3)
		pool:put(footA, newer, 3)
		expect(pool:take(footA)).to.equal(newer)
		expect(pool:take(footA)).to.equal(older)
	end)

	it("refuses a voice once its place holds the cap, so the caller destroys it", function()
		local pool = SoundIdlePool.new()
		expect(pool:put(footA, { 1 }, 2)).to.equal(true)
		expect(pool:put(footA, { 2 }, 2)).to.equal(true)
		expect(pool:put(footA, { 3 }, 2)).to.equal(false)
		expect(pool:count(footA)).to.equal(2)
		-- Another place has its own room.
		expect(pool:put(footB, { 4 }, 2)).to.equal(true)
		expect(pool:count()).to.equal(3)
	end)

	it("never keeps the same voice twice", function()
		local pool = SoundIdlePool.new()
		local voice = {}
		pool:put(footA, voice, 3)
		expect(pool:put(footA, voice, 3)).to.equal(true)
		expect(pool:count(footA)).to.equal(1)
	end)

	it("removes a voice that was destroyed while idle", function()
		local pool = SoundIdlePool.new()
		local kept, gone = {}, {}
		pool:put(footA, kept, 3)
		pool:put(footA, gone, 3)
		pool:remove(footA, gone)
		pool:remove(footB, gone)
		expect(pool:take(footA)).to.equal(kept)
		expect(pool:take(footA)).to.equal(nil)
	end)

	it("forgets a whole place and hands back its voices to destroy", function()
		local pool = SoundIdlePool.new()
		local a, b = {}, {}
		pool:put(footA, a, 3)
		pool:put(footA, b, 3)
		pool:put(footB, {}, 3)
		local dropped = pool:forget(footA)
		expect(#dropped).to.equal(2)
		expect(table.find(dropped, a) ~= nil).to.equal(true)
		expect(table.find(dropped, b) ~= nil).to.equal(true)
		expect(pool:take(footA)).to.equal(nil)
		expect(pool:count()).to.equal(1)
		expect(#pool:forget(footA)).to.equal(0)
	end)

	it("lists the places that hold idle voices", function()
		local pool = SoundIdlePool.new()
		pool:put(footA, {}, 3)
		pool:put(footB, {}, 3)
		expect(#pool:places()).to.equal(2)
		pool:take(footA)
		local places = pool:places()
		expect(#places).to.equal(1)
		expect(places[1]).to.equal(footB)
	end)
	it("pre-warms a place up to a count of idle voices, made only for the shortfall", function()
		local pool = SoundIdlePool.new()
		local made = 0
		local function make()
			made += 1
			return { n = made }
		end
		expect(pool:prewarm(footA, 2, make)).to.equal(2)
		expect(pool:count(footA)).to.equal(2)
		expect(made).to.equal(2)
		-- Already warm: nothing new.
		expect(pool:prewarm(footA, 2, make)).to.equal(0)
		expect(made).to.equal(2)
		-- One taken (playing): only the gap is refilled.
		pool:take(footA)
		expect(pool:prewarm(footA, 2, make)).to.equal(1)
		expect(pool:count(footA)).to.equal(2)
		expect(made).to.equal(3)
		-- Another place warms on its own.
		expect(pool:prewarm(footB, 1, make)).to.equal(1)
		expect(pool:count()).to.equal(3)
	end)

	it("hands back a pre-warmed voice like a released one", function()
		local pool = SoundIdlePool.new()
		local voice = { name = "warm" }
		pool:prewarm(footA, 1, function()
			return voice
		end)
		expect(pool:take(footA)).to.equal(voice)
		expect(pool:take(footA)).to.equal(nil)
	end)

	it("pre-warms nothing for a count of zero or less", function()
		local pool = SoundIdlePool.new()
		local function make()
			return {}
		end
		expect(pool:prewarm(footA, 0, make)).to.equal(0)
		expect(pool:prewarm(footA, -1, make)).to.equal(0)
		expect(pool:count()).to.equal(0)
		expect(#pool:places()).to.equal(0)
	end)
end
