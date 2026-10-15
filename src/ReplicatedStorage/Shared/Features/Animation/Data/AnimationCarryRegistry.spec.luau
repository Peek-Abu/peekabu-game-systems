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
	it("lets the soft bags and the small items go in one hand, and pushes the cart", function()
		for _, id in { "dustBag", "rubbishBag", "bottleBag", "plaque", "goldenStapler" } do
			expect(Registry.get(id)).to.equal("oneHandHang")
		end
		expect(Registry.get("filingCabinet")).to.equal("cart")
		expect(Registry.get("recyclingBox")).to.equal("twoHandSupport")
	end)
	it("lets only light kinds (the tiny and light size classes) be held in one hand", function()
		for _, id in Cargo.ids() do
			if Registry.get(id) == "oneHandHang" then
				local size = Cargo.get(id).size
				expect(size == "tiny" or size == "light").to.equal(true)
			end
		end
	end)
end
