--[[
	Unit tests for TitleServiceClient — a thin read-facade over StateSyncClientStore.titles /
	StateSyncClientStore.equippedTitle. Seeds the atoms directly (charm-sync's job in production) and
	asserts the facade reads. requestEquip only SENDS a packet (no locally observable effect);
	it is covered by TitleRequestRules' round-trip spec plus Studio verification.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local TitleServiceClient = require(ReplicatedStorage.Client.Features.Title.TitleServiceClient)

return function()
	beforeEach(function()
		StateSyncClientStore.titles({ earned = {} })
		StateSyncClientStore.equippedTitle({})
	end)

	afterEach(function()
		StateSyncClientStore.titles({ earned = {} }) -- restore defaults for other specs
		StateSyncClientStore.equippedTitle({})
	end)

	it("reads the earned set off StateSyncClientStore.titles", function()
		local earned = TitleServiceClient:getEarned()
		expect(earned).to.be.ok()
		local count = 0
		for _ in earned.earned do
			count += 1
		end
		expect(count).to.equal(0)

		StateSyncClientStore.titles({ earned = { veteran = true } })
		expect(TitleServiceClient:hasTitle("veteran")).to.equal(true)
		expect(TitleServiceClient:hasTitle("champion")).to.equal(false)
	end)

	it("reports hasTitle false for the default empty-earned state, before any award has synced", function()
		-- StateSyncClientStore.titles is a non-optional atom defaulted to `{ earned = {} }` (charm-sync never
		-- writes nil), so the only unsynced-equivalent state production can reach is an empty earned
		-- set -- not nil. Assert that real state, not one getEarned's caller could never observe.
		expect(TitleServiceClient:getEarned()).to.be.ok()
		expect(TitleServiceClient:hasTitle("veteran")).to.equal(false)
	end)

	it("reads the equipped title off StateSyncClientStore.equippedTitle", function()
		expect(TitleServiceClient:getEquippedTitle()).to.equal(nil)
		StateSyncClientStore.equippedTitle({ equipped = "veteran" })
		expect(TitleServiceClient:getEquippedTitle()).to.equal("veteran")
	end)

	it("throws on an empty titleId in hasTitle/requestEquip (developer contract)", function()
		expect(function()
			TitleServiceClient:hasTitle("")
		end).to.throw()
		expect(function()
			TitleServiceClient:requestEquip("")
		end).to.throw()
	end)
end
