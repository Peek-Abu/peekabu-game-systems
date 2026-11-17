local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConstants = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopConstants)
local VM = require(script.Parent.ShopBundleViewModel)

return function()
	describe("gleam", function()
		it("shows the six bundles, bought with Robux only once their products exist", function()
			local bundles = VM.bundles({})
			expect(#bundles).to.equal(6)
			expect(bundles[1].amount).to.equal("100")
			expect(bundles[1].bonus).to.equal(nil)
			-- Worked out from the numbers: Gleam per Robux over the first pack's.
			-- Owner 11-16: small bonuses, about Marvel Rivals' (its best pack is ~16% over its smallest).
			expect(bundles[2].amount).to.equal("420")
			expect(bundles[2].bonus).to.equal("+4%")
			expect(bundles[3].bonus).to.equal("+9%")
			expect(bundles[4].amount).to.equal("1,950")
			expect(bundles[4].bonus).to.equal("+14%")
			-- Owner 11-16, the two big packs: 5,400 for R$ 4,499 and 12,500 for R$ 9,999 (about 25% for the $99 size).
			expect(bundles[5].amount).to.equal("5,400")
			expect(bundles[5].bonus).to.equal("+19%")
			expect(bundles[6].amount).to.equal("12,500")
			expect(bundles[6].bonus).to.equal("+24%")
			-- Each bigger pack is a better deal.
			for index = 2, #ShopConstants.BUNDLES do
				local a, b = ShopConstants.BUNDLES[index - 1], ShopConstants.BUNDLES[index]
				expect(b.gleam / b.robux > a.gleam / a.robux).to.equal(true)
			end
			for _, bundle in bundles do
				expect(bundle.available).to.equal(ShopConstants.PRODUCT_IDS[bundle.key] ~= nil)
			end
		end)

		it("shows each bundle's product icon and price from Roblox, the known ones until Roblox answers", function()
			local known = VM.bundles({})[1]
			expect(known.robux).to.equal(`R$ {ShopConstants.BUNDLES[1].robux}`)
			expect(known.image).to.equal(ShopConstants.BUNDLES[1].image)
			expect(string.match(known.image, "^rbxassetid://%d+$")).to.be.ok()

			local live = VM.bundles({ gleam100 = { price = 1099, icon = "rbxassetid://7" } })[1]
			expect(live.robux).to.equal("R$ 1,099")
			expect(live.image).to.equal("rbxassetid://7")

			-- A product Roblox has no price or icon for keeps the known ones.
			local partial = VM.bundles({ gleam100 = {} })[1]
			expect(partial.robux).to.equal(known.robux)
			expect(partial.image).to.equal(known.image)
		end)

		it("lays the packs out like a ladder: colour climbs blue, purple, gold and the picture grows", function()
			-- Owner 11-16 ("more like marvel rivals: Dont make it stretched on top of each other", Gleam page round 5):
			-- one row of tall cards, each bigger pack's card richer than the last.
			local bundles = VM.bundles({})
			local hues = {}
			for index, bundle in bundles do
				hues[index] = bundle.hue
			end
			expect(table.concat(hues, " ")).to.equal("sky sky grape grape gold gold")
			expect(bundles[1].iconScale).to.equal(VM.BUNDLE_ICON_MIN)
			expect(bundles[6].iconScale).to.equal(1)
			for index = 2, #bundles do
				expect(bundles[index].iconScale > bundles[index - 1].iconScale).to.equal(true)
			end
		end)

		it("tags the popular pack and the best value", function()
			local bundles = VM.bundles({})
			expect(bundles[4].tag).to.equal("POPULAR")
			expect(bundles[6].tag).to.equal("BEST VALUE")
			for index = 1, 3 do
				expect(bundles[index].tag).to.equal(nil)
			end
			expect(bundles[5].tag).to.equal(nil)
		end)

		it(
			"keeps the Featured page's Gleam row to the first four packs, so each card has room for its amount",
			function()
				local featured = VM.featuredBundles(VM.bundles({}))
				expect(#featured).to.equal(4)
				expect(featured[1].amount).to.equal("100")
				expect(featured[4].amount).to.equal("1,950")
			end
		)
	end)

	describe("best bundle", function()
		it("points at the smallest bundle that covers what is missing, else the biggest", function()
			local smallest, biggest = nil, nil
			for _, bundle in ShopConstants.BUNDLES do
				if ShopConstants.PRODUCT_IDS[bundle.key] ~= nil then
					if smallest == nil or bundle.gleam < smallest.gleam then
						smallest = bundle
					end
					if biggest == nil or bundle.gleam > biggest.gleam then
						biggest = bundle
					end
				end
			end
			expect(VM.bestBundle(1)).to.equal(smallest.key)
			expect(VM.bestBundle(biggest.gleam + 1)).to.equal(biggest.key)
			for _, bundle in ShopConstants.BUNDLES do
				local best = VM.bestBundle(bundle.gleam)
				local picked
				for _, other in ShopConstants.BUNDLES do
					if other.key == best then
						picked = other
					end
				end
				expect(picked.gleam >= bundle.gleam).to.equal(true)
			end
			local marked = 0
			for _, card in VM.bundles({}, smallest.key) do
				if card.best then
					marked += 1
					expect(card.key).to.equal(smallest.key)
				end
			end
			expect(marked).to.equal(1)
		end)
	end)
end
