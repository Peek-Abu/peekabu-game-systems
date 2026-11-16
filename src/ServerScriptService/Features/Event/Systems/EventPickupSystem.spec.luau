local EventPickupSystem = require(script.Parent.EventPickupSystem)

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
	local EVENT = { id = "harvest", currency = "acorns", pickup = { amount = 5, firstPile = 3, lastPile = 9 } }
	local changed, cleared, live, training, rolled, spawned, granted, grantOk, stop

	local function pile(x)
		return { Position = Vector3.new(x, 0, 0) }
	end

	local function clearPiles(count)
		for index = 1, count do
			cleared:Fire(pile(index), {})
		end
	end

	beforeEach(function()
		changed = fakeSignal()
		cleared = fakeSignal()
		live = EVENT
		training = false
		rolled = nil
		spawned = {}
		granted = {}
		grantOk = true
		stop = EventPickupSystem.start({
			changed = changed,
			cleared = cleared,
			live = function()
				return live
			end,
			training = function()
				return training
			end,
			roll = function(min, max)
				rolled = { min, max }
				return 4
			end,
			spawn = function(at, onTouch)
				local entry = { at = at, onTouch = onTouch, removed = false }
				table.insert(spawned, entry)
				return function()
					entry.removed = true
				end
			end,
			grant = function(userId, event, amount)
				table.insert(granted, { userId = userId, event = event, amount = amount })
				return grantOk
			end,
		})
	end)

	afterEach(function()
		stop()
	end)

	it("drops one acorn from the rolled pile of a shift while an event is live", function()
		changed:Fire({ phase = "running", shift = 1 })
		expect(rolled[1]).to.equal(3)
		expect(rolled[2]).to.equal(9)
		clearPiles(3)
		expect(#spawned).to.equal(0)
		clearPiles(1)
		expect(#spawned).to.equal(1)
		expect(spawned[1].at.X).to.equal(1)
		clearPiles(20)
		expect(#spawned).to.equal(1)
	end)

	it("gives the first toucher the event's amount, once, then removes the acorn", function()
		changed:Fire({ phase = "running", shift = 1 })
		clearPiles(4)
		spawned[1].onTouch(7)
		spawned[1].onTouch(8)
		expect(#granted).to.equal(1)
		expect(granted[1].userId).to.equal(7)
		expect(granted[1].event).to.equal(EVENT)
		expect(granted[1].amount).to.equal(5)
		expect(spawned[1].removed).to.equal(true)
	end)

	it("leaves the acorn for someone else when the grant fails", function()
		changed:Fire({ phase = "running", shift = 1 })
		clearPiles(4)
		grantOk = false
		spawned[1].onTouch(7)
		expect(spawned[1].removed).to.equal(false)
		grantOk = true
		spawned[1].onTouch(8)
		expect(spawned[1].removed).to.equal(true)
	end)

	it("drops nothing with no live event or in training", function()
		live = nil
		changed:Fire({ phase = "running", shift = 1 })
		clearPiles(20)
		live = EVENT
		training = true
		changed:Fire({ phase = "running", shift = 2 })
		clearPiles(20)
		expect(#spawned).to.equal(0)
	end)

	it("clears an untaken acorn when the shift goes back to the lobby, and rolls again next shift", function()
		changed:Fire({ phase = "running", shift = 1 })
		clearPiles(4)
		changed:Fire({ phase = "lobby", shift = 1 })
		expect(spawned[1].removed).to.equal(true)
		changed:Fire({ phase = "running", shift = 2 })
		clearPiles(4)
		expect(#spawned).to.equal(2)
	end)
end
