local EventPropSystem = require(script.Parent.EventPropSystem)

local function fakeSignal()
	local handlers = {}
	return {
		Connect = function(_self, fn)
			handlers[fn] = true
			return {
				Disconnect = function()
					handlers[fn] = nil
				end,
			}
		end,
		Fire = function(_self, ...)
			for fn in handlers do
				fn(...)
			end
		end,
	}
end

return function()
	local world, store, props, liveId, added, tick, stop

	local function prop(name, event)
		local model = Instance.new("Model")
		model.Name = name
		if event ~= nil then
			model:SetAttribute("Event", event)
		end
		model.Parent = world
		table.insert(props, model)
		return model
	end

	beforeEach(function()
		world = Instance.new("Folder")
		store = Instance.new("Folder")
		props = {}
		liveId = nil
		added = fakeSignal()
		tick = nil
	end)

	afterEach(function()
		if stop then
			stop()
			stop = nil
		end
		world:Destroy()
		store:Destroy()
	end)

	local function start()
		stop = EventPropSystem.start({
			live = function()
				return liveId
			end,
			tagged = function()
				return props
			end,
			added = added,
			store = store,
			every = function(fn)
				tick = fn
				return function()
					tick = nil
				end
			end,
		})
	end

	it("hides an event's props while it is not live, and shows them when it is", function()
		local scarecrow = prop("Scarecrow", "harvest")
		start()
		expect(scarecrow.Parent).never.to.equal(world)
		expect(scarecrow:IsDescendantOf(store)).to.equal(true)

		liveId = "harvest"
		tick()
		expect(scarecrow.Parent).to.equal(world)

		liveId = nil
		tick()
		expect(scarecrow:IsDescendantOf(store)).to.equal(true)
	end)

	it("leaves another event's props hidden and an untagged-event prop alone", function()
		liveId = "harvest"
		local snowman = prop("Snowman", "winter")
		local plain = prop("Plain", nil)
		start()
		expect(snowman:IsDescendantOf(store)).to.equal(true)
		expect(plain.Parent).to.equal(world)
	end)

	it("handles a prop tagged after it started", function()
		start()
		local banner = prop("Banner", "harvest")
		added:Fire(banner)
		expect(banner:IsDescendantOf(store)).to.equal(true)
	end)

	it("puts every hidden prop back when stopped", function()
		local scarecrow = prop("Scarecrow", "harvest")
		start()
		stop()
		stop = nil
		expect(scarecrow.Parent).to.equal(world)
	end)
end
