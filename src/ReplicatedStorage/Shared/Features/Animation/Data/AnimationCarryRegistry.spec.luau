local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Registry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationCarryRegistry)
local Cargo = require(ReplicatedStorage.Shared.Features.Cargo.Data.CargoRegistry)
return function()
	local styles = { twoHandSupport = true, chest = true, oneHandHang = true, cart = true }
	it("names a hold style for every current cargo kind", function()
		for _, id in Cargo.ids() do
			expect(styles[Registry.get(id)]).to.equal(true)
		end
		expect(Registry.get("unknown")).to.equal("twoHandSupport")
	end)
	it("hangs the soft bags from one hand, holds the small items at the chest and pushes the cart", function()
		for _, id in { "dustBag", "rubbishBag", "bottleBag" } do
			expect(Registry.get(id)).to.equal("oneHandHang")
		end
		expect(Registry.get("plaque")).to.equal("chest")
		expect(Registry.get("goldenStapler")).to.equal("chest")
		expect(Registry.get("filingCabinet")).to.equal("cart")
		expect(Registry.get("recyclingBox")).to.equal("twoHandSupport")
	end)
end
