local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local ShopConstants = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopConstants)
local ShopRegistry = require(ReplicatedStorage.Shared.Features.Shop.Data.ShopRegistry)
local VM = require(script.Parent.ShopCardViewModel)

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
			expect(skin.price).to.equal("1,600")
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

	describe("crossed-out prices", function()
		it("crosses out a bundle's items-alone price with its percent off", function()
			local card = VM.card(ShopRegistry.get("Bundle.BubbleBuddy"), owner(), rich)
			local alone = 0
			for _, id in ShopRegistry.get("Bundle.BubbleBuddy").items do
				alone += CosmeticRegistry.get(id).price
			end
			expect(card.was).to.equal(
				require(ReplicatedStorage.Client.UI.React.Screens.Toon.ToonStyleViewModel).grouped(alone)
			)
			expect(card.off).to.be.a("string")
			expect(VM.card(ShopRegistry.get("Pippa.Bubbles"), owner(), rich).was).to.equal(nil)
		end)

		it("shows today's sale on a card when given the time", function()
			local ShopPriceRules = require(ReplicatedStorage.Shared.Features.Shop.Rules.ShopPriceRules)
			local NOON = 1792929600
			local id = next(ShopPriceRules.daily(NOON))
			local card = VM.card(ShopRegistry.get(id), owner(), { gleam = 0, credits = 0, now = NOON })
			expect(card.off).to.equal(`-{ShopConstants.DAILY_SALE.percent}%`)
			expect(card.saleEnds).to.be.a("number")
		end)
	end)
end
