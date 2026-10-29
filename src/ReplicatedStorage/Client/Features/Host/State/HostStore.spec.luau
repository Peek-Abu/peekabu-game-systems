local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HostStore = require(script.Parent.HostStore)
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)

return function()
	local previous

	beforeEach(function()
		previous = StateSyncClientStore.world()
	end)

	afterEach(function()
		StateSyncClientStore.world(previous)
	end)

	it("mirrors the host world entry", function()
		StateSyncClientStore.world({ host = { trucks = { pad1 = { host = 7 } } } })
		expect(HostStore.hostOf("pad1")).to.equal(7)
		expect(HostStore.hostOf("pad2")).to.equal(nil)
	end)

	it("reads a missing entry as no hosts", function()
		StateSyncClientStore.world({})
		expect(HostStore.hostOf("pad1")).to.equal(nil)
	end)
end
