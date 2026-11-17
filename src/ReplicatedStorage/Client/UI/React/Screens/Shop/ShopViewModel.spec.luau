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

	describe("button", function()
		it("buys when you can, says Owned when you have it, and shows the price even when you are short", function()
			local offer = ShopRegistry.get("Pippa.BubbleBuddy")
			local buy = VM.button(offer, owner(), rich)
			expect(buy.kind).to.equal("buy")
			expect(buy.enabled).to.equal(true)
			local owned = VM.button(offer, owner({ "Pippa.BubbleBuddy" }), rich)
			expect(owned.kind).to.equal("owned")
			expect(owned.enabled).to.equal(false)
			local short = VM.button(offer, owner(), { gleam = 1300, credits = 0 })
			expect(short.kind).to.equal("short")
			-- No "Need 300 more" (owner 11-14): the button shows the price, the same as when you can buy it.
			expect(short.text).to.equal("1,600")
			expect(short.price).to.equal("1,600")
			-- Short on Gleam: the button opens the smallest Gleam pack that covers the 300 missing.
			expect(short.enabled).to.equal(true)
			expect(short.gleam).to.equal(1600)
			expect(short.pack).to.equal(VM.bestBundle(300))
		end)

		it("lets Gleam pay the rest of a Credits price", function()
			local rate = ShopConstants.TOP_UP.credits
			local prickles = ShopRegistry.get("Prickles")
			-- 300 Credits short, with Gleam to spare: one tap (and a yes) pays the rest.
			local topUp = VM.button(prickles, owner(), { gleam = 500, credits = 4700 })
			expect(topUp.kind).to.equal("topup")
			expect(topUp.enabled).to.equal(true)
			expect(topUp.gleam).to.equal(math.ceil(300 / rate))
			expect(topUp.text).to.equal(`Use {math.ceil(300 / rate)} Gleam`)
			-- Not enough Gleam for the rest either: the button leads to the Gleam tab for it.
			local short = VM.button(prickles, owner(), broke)
			expect(short.kind).to.equal("short")
			expect(short.enabled).to.equal(true)
			expect(short.text).to.equal("5,000")
			expect(short.gleam).to.equal(math.ceil(5000 / rate))
			expect(short.pack).to.equal(VM.bestBundle(math.ceil(5000 / rate) - broke.gleam))
			-- Enough Credits: Gleam is never touched.
			expect(VM.button(prickles, owner(), { gleam = 500, credits = 5000 }).kind).to.equal("buy")
		end)

		it("shows the crossed-out price on the button, short or not (a bundle's items alone)", function()
			local bundle = ShopRegistry.get("Bundle.BubbleBuddy")
			local short = VM.button(bundle, owner(), { gleam = 10, credits = 0 })
			expect(short.kind).to.equal("short")
			expect(short.was).to.equal("2,720")
			expect(short.was).to.equal(VM.button(bundle, owner(), rich).was)
		end)

		it("asks before spending, in plain words", function()
			expect(VM.confirm(ShopRegistry.get("Pippa.BubbleBuddy"))).to.equal("Buy Bubble Buddy for 1,600 Gleam?")
			expect(VM.confirm(ShopRegistry.get("Prickles"))).to.equal("Hire Prickles for 5,000 Credits?")
			local gleam = math.ceil(300 / ShopConstants.TOP_UP.credits)
			expect(VM.confirm(ShopRegistry.get("Prickles"), { gleam = 500, credits = 4700 })).to.equal(
				`You need 300 more Credits. Use {gleam} Gleam to hire Prickles?`
			)
			expect(VM.product(ShopRegistry.get("Prickles"), owner(), { gleam = 500, credits = 4700 }).confirm).to.equal(
				`You need 300 more Credits. Use {gleam} Gleam to hire Prickles?`
			)
		end)
	end)

	describe("an event's offers", function()
		local HARVEST = require(ReplicatedStorage.Shared.Features.Event.Data.EventRegistry).get("harvest")

		it("puts the live event's tab first, and no event tab without one", function()
			local tabs = VM.tabs(false, HARVEST)
			expect(tabs[1].id).to.equal("event")
			expect(tabs[1].text).to.equal(HARVEST.short)
			expect(tabs[1].icon).to.equal("acorns")
			for _, entry in VM.tabs(false, nil) do
				expect(entry.id).never.to.equal("event")
			end
		end)

		it("prices an event item in acorns, from the acorn balance, and never offers Gleam for the rest", function()
			local pack = ShopRegistry.get("HarvestPack")
			local card = VM.card(pack, owner(), { gleam = 0, credits = 0, acorns = pack.price })
			expect(card.currency).to.equal("acorns")
			expect(card.state).to.equal("afford")
			local short = VM.button(pack, owner(), { gleam = 99999, credits = 99999, acorns = 1 })
			expect(short.kind).to.equal("short")
			expect(short.enabled).to.equal(false)
			expect(short.pack).to.equal(nil)
			expect(VM.button(pack, owner(), { gleam = 0, credits = 0, acorns = pack.price }).kind).to.equal("buy")
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
		it("describes an item that is not on sale (a Locker item) with the same page parts as the shop", function()
			local view = VM.itemProduct("Pippa.BellJester", owner(), rich)
			local item = CosmeticRegistry.get("Pippa.BellJester")
			expect(view.card.name).to.equal("Bell Jester")
			expect(view.card.rarity).to.equal("epic")
			expect(view.rarityText).to.equal("EPIC")
			expect(view.line).to.equal("Skin for Pippa · cosmetic only")
			expect(view.lore).to.equal(item.lore)
			expect(#view.inside).to.equal(1)
			expect(view.card.was).to.equal(nil)
			expect(view.card.off).to.equal(nil)
			expect(VM.itemProduct("Nobody.Nothing", owner(), rich)).to.equal(nil)
		end)

		it("lists what is inside with each extra's own price", function()
			local view = VM.product(ShopRegistry.get("Bundle.BubbleBuddy"), owner(), rich)
			expect(view.line).to.equal("Bundle for Pippa · cosmetic only")
			expect(view.card.name).to.equal("Bubble Buddy Bundle")
			expect(view.card.line).to.equal("Bundle · Pippa")
			expect(view.card.rarity).to.equal("legendary")
			expect(#view.inside).to.equal(4)
			expect(view.inside[1].name).to.equal("Bubble Buddy")
			expect(view.inside[2].alone).to.equal("alone 500")
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
	end)

	describe("idles", function()
		it("plays an idle on its employee in the Classic skin, never the skin it came from", function()
			for _, id in { "Pippa.BubbleBuddyIdle", "Cappy.PJIdle", "Prickles.SheriffIdle" } do
				local card = VM.card(ShopRegistry.get(id), owner(), rich)
				expect(card.idle).to.equal(CosmeticRegistry.keyOf(id))
				expect(card.skinKey).to.equal(nil)
				expect(card.employee).to.equal(CosmeticRegistry.get(id).employee)
			end
			expect(VM.card(ShopRegistry.get("Pippa.BubbleBuddy"), owner(), rich).idle).to.equal(nil)
		end)

		it("says plainly that an idle comes without the skin", function()
			local view = VM.product(ShopRegistry.get("Prickles.SheriffIdle"), owner(), rich)
			expect(view.line).to.equal("Idle only (no skin) for Prickles · cosmetic only")
			expect(#view.inside).to.equal(1)
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
				VM.returnTo(ShopRegistry.get("Pippa.BubbleBuddy"), owner(), { gleam = 1300, credits = 0 }, "skins")
			expect(back.offer).to.equal("Pippa.BubbleBuddy")
			expect(back.tab).to.equal("skins")
			expect(back.gleam).to.equal(1600)
			expect(back.name).to.equal("Bubble Buddy")
			expect(VM.returnReady(back, 1599)).to.equal(false)
			expect(VM.returnReady(back, 1600)).to.equal(true)
			-- A hire needs only the Gleam for the rest.
			local hire = VM.returnTo(ShopRegistry.get("Prickles"), owner(), { gleam = 0, credits = 4700 }, "hires")
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
				VM.returnTo(ShopRegistry.get("Pippa.BubbleBuddy"), owner(), { gleam = 1300, credits = 0 }, "skins")
			expect(VM.returnNote(back, 1300)).to.equal("Get 300 more Gleam for Bubble Buddy!")
			expect(VM.returnNote(back, 1600)).to.equal("You have enough for Bubble Buddy!")
		end)
	end)

	describe("crossed-out prices", function()
		it("says the percent off and when a sale ends", function()
			expect(VM.off(960, 1200)).to.equal("-20%")
			expect(VM.off(1220, 1750)).to.equal("-30%")
			expect(VM.off(1200, nil)).to.equal(nil)
			expect(VM.off(1200, 1200)).to.equal(nil)
			expect(VM.saleText(1000 + 6 * 3600 + 12 * 60, 1000)).to.equal("Sale ends in 6h 12m")
			expect(VM.saleText(1000, 1000)).to.equal(nil)
			expect(VM.saleText(nil, 1000)).to.equal(nil)
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
		expect(VM.resultText("top up changed")).to.equal("The price changed. Look again!")
		expect(VM.resultText("price changed")).to.equal("The price changed. Look again!")
		expect(VM.resultText("anything else")).to.equal("That didn't work. Try again!")
	end)
end
