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
			-- No idle is on sale right now: fixture offers for an employee's idle and a shared one (a sticker).
			local idle = table.clone(ShopRegistry.get("Pippa.Bubbles"))
			idle.items = { "Cappy.Classic" }
			expect(VM.card(idle, owner(), rich).line).to.equal("Idle · Cappy")
			local shared = table.clone(ShopRegistry.get("CozyPack"))
			shared.items = { "CozyPack.CocoaBreak" }
			expect(VM.card(shared, owner(), rich).line).to.equal("Sticker · any employee")
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
			-- Short on Gleam leads to the Gleam tab, which needs the whole price.
			expect(short.enabled).to.equal(true)
			expect(short.gleam).to.equal(1500)
		end)

		it("lets Gleam pay the rest of a Credits price", function()
			local rate = ShopConstants.TOP_UP.credits
			local prickles = ShopRegistry.get("Prickles")
			-- 300 Credits short, with Gleam to spare: one tap (and a yes) pays the rest.
			local topUp = VM.button(prickles, owner(), { gleam = 500, credits = 2200 })
			expect(topUp.kind).to.equal("topup")
			expect(topUp.enabled).to.equal(true)
			expect(topUp.gleam).to.equal(math.ceil(300 / rate))
			expect(topUp.text).to.equal(`Use {math.ceil(300 / rate)} Gleam`)
			-- Not enough Gleam for the rest either: the button leads to the Gleam tab for it.
			local short = VM.button(prickles, owner(), broke)
			expect(short.kind).to.equal("short")
			expect(short.enabled).to.equal(true)
			expect(short.text).to.equal("Need 2,500 more")
			expect(short.gleam).to.equal(math.ceil(2500 / rate))
			-- Enough Credits: Gleam is never touched.
			expect(VM.button(prickles, owner(), { gleam = 500, credits = 2500 }).kind).to.equal("buy")
		end)

		it("asks before spending, in plain words", function()
			expect(VM.confirm(ShopRegistry.get("Pippa.BubbleBuddy"))).to.equal("Buy Bubble Buddy for 1,500 Gleam?")
			expect(VM.confirm(ShopRegistry.get("Prickles"))).to.equal("Hire Prickles for 2,500 Credits?")
			local gleam = math.ceil(300 / ShopConstants.TOP_UP.credits)
			expect(VM.confirm(ShopRegistry.get("Prickles"), { gleam = 500, credits = 2200 })).to.equal(
				`You need 300 more Credits. Use {gleam} Gleam to hire Prickles?`
			)
			expect(VM.product(ShopRegistry.get("Prickles"), owner(), { gleam = 500, credits = 2200 }).confirm).to.equal(
				`You need 300 more Credits. Use {gleam} Gleam to hire Prickles?`
			)
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
			local view = VM.product(ShopRegistry.get("Bundle.BubbleBuddy"), owner(), rich)
			expect(view.line).to.equal("Bundle for Pippa · cosmetic only")
			expect(view.card.name).to.equal("Bubble Buddy Bundle")
			expect(view.card.line).to.equal("Bundle · Pippa")
			expect(view.card.rarity).to.equal("legendary")
			expect(#view.inside).to.equal(3)
			expect(view.inside[1].name).to.equal("Bubble Buddy")
			expect(view.inside[2].alone).to.equal("alone 400")
			-- The skin alone is just the skin (owner, 2026-11-13).
			local alone = VM.product(ShopRegistry.get("Pippa.BubbleBuddy"), owner(), rich)
			expect(alone.line).to.equal("Skin for Pippa · cosmetic only")
			expect(#alone.inside).to.equal(1)
			expect(alone.card.name).to.equal("Bubble Buddy")
			expect(view.styles.visible).to.equal(true)
			-- Every style is a chip that swaps the preview (the bundle's hero skin's styles).
			expect(#view.styles.chips).to.equal(3)
			expect(view.styles.chips[1].name).to.equal("Blue")
			expect(string.find(string.lower(view.styles.text), "coming", 1, true)).never.to.be.ok()
			-- A skin with no colour styles shows nothing, not even "coming soon" (a fixture offer for such a skin).
			local plain = table.clone(ShopRegistry.get("Cappy.PJ"))
			plain.items = { "Cappy.GloomTouched" }
			local none = VM.product(plain, owner(), rich)
			expect(none.styles.visible).to.equal(false)
			expect(#none.styles.chips).to.equal(0)
			-- PJ Cappy's styles have art: three chips.
			local pj = VM.product(ShopRegistry.get("Cappy.PJ"), owner(), rich)
			expect(pj.styles.visible).to.equal(true)
			expect(#pj.styles.chips).to.equal(3)
			expect(pj.styles.chips[1].name).to.equal("Blue")
			-- Quoted only where the item chose it (a spoken line), never by rarity.
			expect(view.quote).to.equal(false)
			expect(VM.product(ShopRegistry.get("Prickles.Lasso"), owner(), rich).quote).to.equal(true)
			local single = VM.product(ShopRegistry.get("CozyPack"), owner(), rich)
			expect(single.line).to.equal("Sticker pack · cosmetic only")
			expect(#single.inside).to.equal(1)
		end)

		it("shows an employee's ability and five stats on their hire page, and neither on a cosmetic's", function()
			local hire = VM.product(ShopRegistry.get("Prickles"), owner(), rich)
			expect(#hire.stats).to.equal(5)
			expect(hire.stats[1].label).to.equal("Speed")
			expect(hire.stats[1].icon).to.equal("statSpeed")
			expect(hire.stats[3].value).to.equal(3)
			expect(hire.ability.name).to.equal("Potted Plant")
			expect(hire.ability.line).to.equal("Pretend to be a plant!")
			-- The seconds, drawn as a number and its word by ToonCooldown.
			expect(type(hire.ability.cooldown)).to.equal("number")
			expect(hire.ability.cooldown > 0).to.equal(true)
			local skin = VM.product(ShopRegistry.get("Pippa.BubbleBuddy"), owner(), rich)
			expect(#skin.stats).to.equal(0)
			expect(skin.ability).to.equal(nil)
		end)
	end)

	describe("reacts", function()
		it("is true on a page that shows an employee", function()
			expect(VM.reacts(VM.card(ShopRegistry.get("Pippa.BubbleBuddy"), owner(), rich))).to.equal(true)
			expect(VM.reacts(VM.card(ShopRegistry.get("Cappy.PJ"), owner(), rich))).to.equal(true)
		end)

		it("is false on a vacuum's page (the hero is seen from behind) and an emote's (it loops the emote)", function()
			expect(VM.reacts(VM.card(ShopRegistry.get("Vacuum.BrassBellows"), owner(), rich))).to.equal(false)
			expect(VM.reacts(VM.card(ShopRegistry.get("Prickles.Lasso"), owner(), rich))).to.equal(false)
		end)
	end)

	describe("hire tab", function()
		it("comes right after Featured", function()
			local tabs = VM.tabs(false)
			expect(tabs[1].id).to.equal("featured")
			expect(tabs[2].id).to.equal("hires")
			expect(tabs[2].text).to.equal("Hire")
			expect(tabs[2].soon).to.equal(false)
		end)

		it("lists every employee for sale and nothing else, hired ones last", function()
			local employees = 0
			for _, offer in ShopRegistry.all() do
				if CosmeticRegistry.get(offer.items[1]).kind == "employee" then
					employees += 1
				end
			end
			expect(employees > 0).to.equal(true)
			local cards = VM.hires(owner(), rich)
			expect(#cards).to.equal(employees)
			for _, card in cards do
				expect(card.kind).to.equal("employee")
				expect(card.currency).to.equal("credits")
			end
			local hired = VM.hires(owner({ cards[1].id }), rich)
			expect(hired[#hired].id).to.equal(cards[1].id)
			expect(hired[#hired].state).to.equal("owned")
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
			local bundles = VM.bundles({})
			expect(#bundles).to.equal(4)
			expect(bundles[1].amount).to.equal("100")
			expect(bundles[1].bonus).to.equal(nil)
			expect(bundles[2].bonus).to.equal("+10%")
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

	describe("back to the item after buying Gleam", function()
		it("remembers the item and the Gleam it needs, and is ready once the Gleam is there", function()
			local back =
				VM.returnTo(ShopRegistry.get("Pippa.BubbleBuddy"), owner(), { gleam = 1200, credits = 0 }, "skins")
			expect(back.offer).to.equal("Pippa.BubbleBuddy")
			expect(back.tab).to.equal("skins")
			expect(back.gleam).to.equal(1500)
			expect(back.name).to.equal("Bubble Buddy")
			expect(VM.returnReady(back, 1499)).to.equal(false)
			expect(VM.returnReady(back, 1500)).to.equal(true)
			-- A hire needs only the Gleam for the rest.
			local hire = VM.returnTo(ShopRegistry.get("Prickles"), owner(), { gleam = 0, credits = 2200 }, "hires")
			expect(hire.gleam).to.equal(math.ceil(300 / ShopConstants.TOP_UP.credits))
		end)

		it("goes back to the Lockers once the player has a Gleam key's worth, or after any Gleam buy", function()
			local LockerConstants = require(ReplicatedStorage.Shared.Features.Locker.Data.LockerConstants)
			local key = LockerConstants.LOCKERS.gleam.keyPrice
			local back = VM.lockerReturn(key - 30)
			expect(back.offer).to.equal(nil)
			expect(back.tab).to.equal("lockers")
			expect(back.gleam).to.equal(key)
			expect(VM.returnNote(back, key - 30)).to.equal("Get 30 more Gleam for a Gleam key!")
			expect(VM.lockerReturn(key + 5).gleam).to.equal(key + 6)
		end)

		it("says how much more Gleam, for what", function()
			local back =
				VM.returnTo(ShopRegistry.get("Pippa.BubbleBuddy"), owner(), { gleam = 1200, credits = 0 }, "skins")
			expect(VM.returnNote(back, 1200)).to.equal("Get 300 more Gleam for Bubble Buddy!")
			expect(VM.returnNote(back, 1500)).to.equal("You have enough for Bubble Buddy!")
		end)

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
		expect(VM.resultText("top up changed")).to.equal("The Gleam price changed. Look again!")
		expect(VM.resultText("anything else")).to.equal("That didn't work. Try again!")
	end)
end
