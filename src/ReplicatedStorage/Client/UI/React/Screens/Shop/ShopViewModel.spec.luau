local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local ShopConstants = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopConstants)
local ShopRegistry = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopRegistry)
local VM = require(script.Parent.ShopViewModel)

return function()
	local function owner(ids)
		local set = {}
		for _, id in ids or {} do
			set[id] = true
		end
		return function(id)
			local item = CosmeticRegistry.get(id)
			return item ~= nil and (item.source == "default" or set[id] == true)
		end
	end
	local rich = { gleam = 99999, credits = 99999 }
	local broke = { gleam = 0, credits = 0 }

	describe("cards", function()
		it("names what an offer is and who it is for", function()
			local skin = VM.card(ShopRegistry.get("Pippa.BubbleBuddy"), owner(), rich)
			expect(skin.name).to.equal("Bubble Buddy")
			expect(skin.line).to.equal("Skin · Pippa")
			expect(skin.price).to.equal("1,500")
			expect(skin.currency).to.equal("gleam")
			expect(skin.skinKey).to.equal("BubbleBuddy")
			expect(skin.emote).never.to.be.ok()
			-- an emote's card loops the emote on its employee
			local emote = VM.card(ShopRegistry.get("Pippa.Bubbles"), owner(), rich)
			expect(emote.emote).to.equal("Pippa.Bubbles")
			expect(emote.employee).to.equal("Pippa")
			expect(VM.card(ShopRegistry.get("SleepySway"), owner(), rich).line).to.equal("Idle · any employee")
			expect(VM.card(ShopRegistry.get("CozyPack"), owner(), rich).line).to.equal("Sticker pack")
			expect(VM.card(ShopRegistry.get("Prickles"), owner(), rich).line).to.equal("Employee")
		end)

		it("marks owned, affordable and too-dear offers", function()
			local offer = ShopRegistry.get("Pippa.BubbleBuddy")
			expect(VM.card(offer, owner({ "Pippa.BubbleBuddy" }), rich).state).to.equal("owned")
			expect(VM.card(offer, owner(), rich).state).to.equal("afford")
			expect(VM.card(offer, owner(), broke).state).to.equal("short")
		end)
	end)

	describe("button", function()
		it("buys when you can, says Owned when you have it, and how much more you need", function()
			local offer = ShopRegistry.get("Pippa.BubbleBuddy")
			local buy = VM.button(offer, owner(), rich)
			expect(buy.kind).to.equal("buy")
			expect(buy.enabled).to.equal(true)
			local owned = VM.button(offer, owner({ "Pippa.BubbleBuddy" }), rich)
			expect(owned.kind).to.equal("owned")
			expect(owned.enabled).to.equal(false)
			local short = VM.button(offer, owner(), { gleam = 1200, credits = 0 })
			expect(short.kind).to.equal("short")
			expect(short.text).to.equal("Need 300 more")
			-- Short on Gleam leads to the Gleam tab; short on Credits has nowhere to go yet.
			expect(short.enabled).to.equal(true)
			expect(VM.button(ShopRegistry.get("Prickles"), owner(), broke).enabled).to.equal(false)
		end)

		it("asks before spending, in plain words", function()
			expect(VM.confirm(ShopRegistry.get("Pippa.BubbleBuddy"))).to.equal("Buy Bubble Buddy for 1,500 Gleam?")
			expect(VM.confirm(ShopRegistry.get("Prickles"))).to.equal("Hire Prickles for 2,500 Credits?")
		end)
	end)

	describe("vacuums", function()
		it("sells a vacuum for every employee, shown as the vacuum", function()
			local card = VM.card(ShopRegistry.get("Vacuum.BrassBellows"), owner(), rich)
			expect(card.line).to.equal("Vacuum · every employee")
			expect(card.vacuum).to.equal("Vacuum.BrassBellows")
			expect(card.kind).to.equal("vacuum")
			local page = VM.product(ShopRegistry.get("Vacuum.BrassBellows"), owner(), rich)
			expect(page.line).to.equal("Vacuum for every employee · cosmetic only")
		end)
	end)

	describe("product", function()
		it("lists what is inside with each extra's own price", function()
			local view = VM.product(ShopRegistry.get("Pippa.BubbleBuddy"), owner(), rich)
			expect(view.line).to.equal("Bundle for Pippa · cosmetic only")
			expect(#view.inside).to.equal(3)
			expect(view.inside[1].name).to.equal("Bubble Buddy")
			expect(view.inside[2].alone).to.equal("alone 400")
			expect(view.styles.visible).to.equal(true)
			-- Every style is a chip that swaps the preview; the line no longer says the art is coming.
			expect(#view.styles.chips).to.equal(3)
			expect(view.styles.chips[1].name).to.equal("Blue")
			expect(string.find(string.lower(view.styles.text), "coming", 1, true)).never.to.be.ok()
			-- A catalogue item with styles but no style art shows nothing.
			local pj = VM.product(ShopRegistry.get("Cappy.PJ"), owner(), rich)
			expect(pj.styles.visible).to.equal(false)
			expect(#pj.styles.chips).to.equal(0)
			-- Quoted only where the item chose it (a spoken line), never by rarity.
			expect(view.quote).to.equal(false)
			expect(VM.product(ShopRegistry.get("Prickles.Lasso"), owner(), rich).quote).to.equal(true)
			local single = VM.product(ShopRegistry.get("CozyPack"), owner(), rich)
			expect(single.line).to.equal("Sticker pack · cosmetic only")
			expect(#single.inside).to.equal(1)
		end)
	end)

	describe("skins tab", function()
		it("lists every offer but employees, filters by employee, puts what you own last", function()
			local all = VM.skins(owner({ "Pippa.BubbleBuddy" }), rich, nil)
			for _, card in all do
				expect(card.kind ~= "employee").to.equal(true)
			end
			expect(all[#all].state).to.equal("owned")
			for _, card in VM.skins(owner(), rich, "Cappy") do
				local item = CosmeticRegistry.get(card.id)
				expect(item.employee == nil or item.employee == "Cappy").to.equal(true)
			end
		end)
	end)

	describe("gleam", function()
		it("shows the four bundles, bought with Robux only once their products exist", function()
			local bundles = VM.bundles()
			expect(#bundles).to.equal(4)
			expect(bundles[1].amount).to.equal("100")
			expect(bundles[1].robux).to.equal("R$ 49")
			expect(bundles[1].bonus).to.equal(nil)
			expect(bundles[2].bonus).to.equal("+10%")
			for _, bundle in bundles do
				expect(bundle.available).to.equal(ShopConstants.PRODUCT_IDS[bundle.key] ~= nil)
			end
		end)
	end)

	describe("passes", function()
		local function info(price, forSale)
			return { price = price, icon = "rbxassetid://5", name = "Dashboard name", forSale = forSale ~= false }
		end
		local function none()
			return false
		end

		it("opens the Passes tab once a pass is registered, greyed Soon before", function()
			local function passes(tabs)
				for _, tab in tabs do
					if tab.id == "passes" then
						return tab
					end
				end
				return nil
			end
			expect(passes(VM.tabs(false)).soon).to.equal(true)
			expect(passes(VM.tabs(true)).soon).to.equal(false)
		end)

		it("shows a pass with its kid-level name and line and its Robux price", function()
			local cards = VM.passes({ "bigCrew" }, { bigCrew = info(149) }, none)
			expect(#cards).to.equal(1)
			local card = cards[1]
			expect(card.key).to.equal("bigCrew")
			expect(card.name).to.equal(ShopConstants.PASS_COPY.bigCrew.name)
			expect(card.line).to.equal(ShopConstants.PASS_COPY.bigCrew.line)
			expect(card.icon).to.equal("rbxassetid://5")
			expect(card.state).to.equal("buy")
			expect(card.button).to.equal("R$ 149")
		end)

		it("says Owned for a pass the player has", function()
			local card = VM.passes({ "bigCrew" }, { bigCrew = info(149) }, function(key)
				return key == "bigCrew"
			end)[1]
			expect(card.state).to.equal("owned")
			expect(card.button).to.equal("Owned")
		end)

		it("waits while the price loads, and says Soon for a pass not on sale", function()
			local loading = VM.passes({ "bigCrew" }, {}, none)[1]
			expect(loading.state).to.equal("loading")
			expect(loading.icon).to.equal(nil)
			local offSale = VM.passes({ "bigCrew" }, { bigCrew = info(nil, false) }, none)[1]
			expect(offSale.state).to.equal("unavailable")
			expect(offSale.button).to.equal("Soon")
		end)

		it("shows a pass with no copy by its Dashboard name, in the order given", function()
			local cards = VM.passes({ "bigCrew", "zNew" }, { bigCrew = info(149), zNew = info(99) }, none)
			expect(cards[2].key).to.equal("zNew")
			expect(cards[2].name).to.equal("Dashboard name")
			expect(cards[2].line).to.equal("")
		end)
	end)

	it("counts time down in plain units", function()
		expect(VM.timer(2 * 86400 + 14 * 3600 + 5)).to.equal("2d 14h")
		expect(VM.timer(6 * 3600 + 12 * 60)).to.equal("6h 12m")
		expect(VM.timer(90)).to.equal("1m")
		expect(VM.timer(-5)).to.equal("0m")
	end)

	it("turns a refused buy into words a kid can read", function()
		expect(VM.resultText("")).to.equal(nil)
		expect(VM.resultText("short")).to.equal("Not enough yet!")
		expect(VM.resultText("owned")).to.equal("You already have it!")
		expect(VM.resultText("locked during a shift")).to.equal("The Shop opens at the depot.")
		expect(VM.resultText("anything else")).to.equal("That didn't work. Try again!")
	end)
end
