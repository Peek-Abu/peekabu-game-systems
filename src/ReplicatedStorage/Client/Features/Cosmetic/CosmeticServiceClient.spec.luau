--[[
	Unit tests for CosmeticServiceClient: a read facade over StateSyncClientStore.loadout / .entitlements. Seeds the
	atoms directly (charm-sync's job in production). requestEquip / requestPick only SEND (no local effect); what
	they would send is gated by canEquip, specced here, and the payload shape by CosmeticRequestRules' spec.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateSyncClientStore = require(ReplicatedStorage.Client.Features.StateSync.State.StateSyncClientStore)
local CosmeticConstants = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticConstants)
local CosmeticServiceClient = require(ReplicatedStorage.Client.Features.Cosmetic.CosmeticServiceClient)

return function()
	local function reset()
		StateSyncClientStore.loadout(CosmeticConstants.defaultLoadout())
		StateSyncClientStore.entitlements({ owned = {} })
	end

	beforeEach(reset)
	afterEach(reset)

	it("reads the default loadout: Pippa in her defaults", function()
		expect(CosmeticServiceClient:getLoadout().current).to.equal("Pippa")
		expect(CosmeticServiceClient:currentEmployee()).to.equal("Pippa")
		expect(CosmeticServiceClient:lookOf().skin).to.equal("Pippa.Default")
		expect(CosmeticServiceClient:owns("Pippa")).to.equal(true)
		expect(CosmeticServiceClient:owns("Cappy")).to.equal(false)
	end)

	it("follows synced ownership and the saved look", function()
		StateSyncClientStore.entitlements({ owned = { employee = { Cappy = true }, skin = { ["Cappy.PJ"] = true } } })
		local loadout = CosmeticConstants.defaultLoadout()
		loadout.current = "Cappy"
		loadout.looks.Cappy = { skin = "Cappy.PJ", style = 2, idle = "Cappy.Classic", wheel = { "", "", "", "" } }
		StateSyncClientStore.loadout(loadout)
		expect(CosmeticServiceClient:currentEmployee()).to.equal("Cappy")
		expect(CosmeticServiceClient:lookOf().skin).to.equal("Cappy.PJ")
		expect(CosmeticServiceClient:lookOf("Pippa").skin).to.equal("Pippa.Default")
		expect(CosmeticServiceClient:lookOf("Nobody")).to.equal(nil)
	end)

	it("only allows changes the server would allow", function()
		expect(CosmeticServiceClient:canEquip({ kind = "skin", id = "Cappy.PJ", style = 1 })).to.equal(false)
		StateSyncClientStore.entitlements({ owned = { skin = { ["Cappy.PJ"] = true } } })
		expect(CosmeticServiceClient:canEquip({ kind = "skin", id = "Cappy.PJ", style = 1 })).to.equal(true)
		expect(CosmeticServiceClient:canEquip({ kind = "skin", id = "Cappy.PJ", style = 9 })).to.equal(false)
	end)
end
