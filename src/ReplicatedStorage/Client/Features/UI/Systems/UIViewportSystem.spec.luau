local System = require(script.Parent.UIViewportSystem)
local function signal()
	local listeners = {}
	return {
		subscribe = function(fn)
			listeners[fn] = true
			return function()
				listeners[fn] = nil
			end
		end,
		fire = function()
			for fn in listeners do
				fn()
			end
		end,
		snapshot = function()
			local result = {}
			for fn in listeners do
				table.insert(result, fn)
			end
			return result
		end,
		count = function()
			local n = 0
			for _ in listeners do
				n += 1
			end
			return n
		end,
	}
end
local function camera(size)
	local event = signal()
	local object = { size = size, event = event }
	object.source = {
		read = function()
			return object.size
		end,
		subscribe = event.subscribe,
	}
	return object
end
local function world(initial)
	local event = signal()
	local object = { camera = initial, event = event }
	object.source = {
		current = function()
			return if object.camera then object.camera.source else nil
		end,
		subscribeCamera = event.subscribe,
	}
	return object
end
return function()
	describe("UIViewportSystem", function()
		it("resamples after subscribing, covering the render-to-effect gap", function()
			local c = camera(Vector2.new(1, 1))
			local w = world(c)
			expect(System.read(w.source)).to.equal(Vector2.new(1920, 1080))
			c.size = Vector2.new(1497, 634) -- event happened before the effect attached
			local seen = {}
			local stop = System.observe(function(v)
				table.insert(seen, v)
			end, w.source)
			expect(seen[#seen]).to.equal(Vector2.new(1497, 634))
			stop()
		end)
		it("waits for a camera and its first usable viewport without sticking at the floor", function()
			local w = world(nil)
			local seen = {}
			local stop = System.observe(function(v)
				table.insert(seen, v)
			end, w.source)
			expect(seen[#seen]).to.equal(Vector2.new(1920, 1080))
			local c = camera(Vector2.new(1, 1))
			w.camera = c
			w.event.fire()
			expect(seen[#seen]).to.equal(Vector2.new(1920, 1080))
			c.size = Vector2.new(1497, 634)
			c.event.fire()
			expect(seen[#seen]).to.equal(Vector2.new(1497, 634))
			stop()
		end)
		it("follows replacement cameras, ignores stale events and preserves the last valid size", function()
			local old = camera(Vector2.new(1920, 1080))
			local w = world(old)
			local seen = {}
			local stop = System.observe(function(v)
				table.insert(seen, v)
			end, w.source)
			local new = camera(Vector2.new(1, 1))
			w.camera = new
			w.event.fire()
			expect(old.event.count()).to.equal(0)
			expect(seen[#seen]).to.equal(Vector2.new(1920, 1080))
			old.size = Vector2.new(400, 200)
			old.event.fire()
			expect(seen[#seen]).to.equal(Vector2.new(1920, 1080))
			new.size = Vector2.new(844, 390)
			new.event.fire()
			expect(seen[#seen]).to.equal(Vector2.new(844, 390))
			new.size = Vector2.new(0, 0)
			new.event.fire()
			expect(seen[#seen]).to.equal(Vector2.new(844, 390))
			new.size = Vector2.new(2560, 1440)
			new.event.fire()
			expect(seen[#seen]).to.equal(Vector2.new(2560, 1440))
			local staleCamera = w.event.snapshot()[1]
			local staleViewport = new.event.snapshot()[1]
			stop()
			staleCamera()
			staleViewport()
			expect(w.event.count()).to.equal(0)
			expect(new.event.count()).to.equal(0)
			local n = #seen
			new.event.fire()
			w.event.fire()
			expect(#seen).to.equal(n)
		end)
		it("catches a viewport change while its listener is being attached and deduplicates snapshots", function()
			local c = camera(Vector2.new(1, 1))
			local w = world(c)
			local base = c.source.subscribe
			c.source.subscribe = function(fn)
				local stop = base(fn)
				c.size = Vector2.new(1280, 720)
				return stop
			end
			local seen = {}
			local stop = System.observe(function(v)
				table.insert(seen, v)
			end, w.source)
			expect(seen[#seen]).to.equal(Vector2.new(1280, 720))
			c.event.fire()
			c.event.fire()
			expect(#seen).to.equal(1)
			stop()
			stop()
		end)
	end)
end
