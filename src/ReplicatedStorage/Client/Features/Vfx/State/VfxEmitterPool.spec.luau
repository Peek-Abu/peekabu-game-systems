local VfxEmitterPool = require(script.Parent.VfxEmitterPool)

return function()
	local function setup(capacity)
		local destroyed = {}
		local pool = VfxEmitterPool.new(capacity, function(item)
			table.insert(destroyed, item)
		end)
		local built = 0
		local function build()
			built += 1
			return { id = built }
		end
		return pool, build, destroyed, function()
			return built
		end
	end

	it("builds when nothing is idle", function()
		local pool, build, _, builds = setup(2)
		local a = pool:acquire("puff", build)
		local b = pool:acquire("puff", build)
		expect(a).never.to.equal(b)
		expect(builds()).to.equal(2)
	end)

	it("reuses a released item for the same key", function()
		local pool, build, _, builds = setup(2)
		local a = pool:acquire("puff", build)
		pool:release("puff", a)
		expect(pool:idle("puff")).to.equal(1)
		expect(pool:acquire("puff", build)).to.equal(a)
		expect(builds()).to.equal(1)
		expect(pool:idle("puff")).to.equal(0)
	end)

	it("never hands one key's item to another key", function()
		local pool, build = setup(2)
		local a = pool:acquire("puff", build)
		pool:release("puff", a)
		expect(pool:acquire("star", build)).never.to.equal(a)
	end)

	it("destroys what is released beyond the capacity", function()
		local pool, build, destroyed = setup(1)
		local a = pool:acquire("puff", build)
		local b = pool:acquire("puff", build)
		pool:release("puff", a)
		pool:release("puff", b)
		expect(pool:idle("puff")).to.equal(1)
		expect(#destroyed).to.equal(1)
		expect(destroyed[1]).to.equal(b)
	end)

	it("ignores a double release", function()
		local pool, build = setup(3)
		local a = pool:acquire("puff", build)
		pool:release("puff", a)
		pool:release("puff", a)
		expect(pool:idle("puff")).to.equal(1)
	end)

	it("clear destroys every idle item", function()
		local pool, build, destroyed = setup(3)
		local a = pool:acquire("puff", build)
		local b = pool:acquire("star", build)
		pool:release("puff", a)
		pool:release("star", b)
		pool:clear()
		expect(#destroyed).to.equal(2)
		expect(pool:idle()).to.equal(0)
	end)
end
