local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QueueStore = require(script.Parent.QueueStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

return function()
	local previous

	beforeEach(function()
		previous = StateSyncClientStore.world()
	end)

	afterEach(function()
		StateSyncClientStore.world(previous)
		QueueStore.widgetEnabled(true)
	end)

	it("decodes the queue world entry and finds a player's pad", function()
		StateSyncClientStore.world({
			queue = {
				pads = {
					pad1 = { members = { 7 }, capacity = 4, destination = "away", endsAt = 120, departing = false },
				},
			},
		})
		local padId, pad = QueueStore.padFor(7)
		expect(padId).to.equal("pad1")
		expect(pad.endsAt).to.equal(120)
		expect(QueueStore.padFor(8)).to.equal(nil)
	end)

	it("has no snapshot before the first sync or for a malformed entry", function()
		StateSyncClientStore.world({})
		expect(QueueStore.snapshot()).to.equal(nil)
		StateSyncClientStore.world({ queue = "broken" })
		expect(QueueStore.snapshot()).to.equal(nil)
		expect(QueueStore.padFor(7)).to.equal(nil)
	end)

	it("shows the default widget unless a game turns it off", function()
		expect(QueueStore.widgetEnabled()).to.equal(true)
		QueueStore.widgetEnabled(false)
		expect(QueueStore.widgetEnabled()).to.equal(false)
	end)
end
