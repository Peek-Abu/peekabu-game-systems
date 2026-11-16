local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local EventRegistry = require(ReplicatedStorage.Shared.Features.Event.Data.EventRegistry)
local VM = require(script.Parent.ShopEventViewModel)

return function()
	local HARVEST = EventRegistry.get("harvest")
	local DAY = 86400

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

	describe("header", function()
		it("names the event, its days left in plain words, and the acorns you have", function()
			local head = VM.header(HARVEST, HARVEST.ends - 10 * DAY, false, 1250)
			expect(head.title).to.equal(HARVEST.name)
			expect(head.days).to.equal("10 days left")
			expect(head.acorns).to.equal("1,250")
			expect(VM.header(HARVEST, HARVEST.ends - 3600, false, 0).days).to.equal("Last day!")
			-- A preview after the dates still says it is on (the last day), never "0 days left".
			expect(VM.header(HARVEST, HARVEST.ends + 5 * DAY, true, 0).days).to.equal("Last day!")
		end)
	end)

	describe("offers", function()
		it("lists only this event's offers, priciest first, priced in acorns", function()
			local cards = VM.offers(HARVEST, owner(), { gleam = 0, credits = 0, acorns = 0 })
			local last = math.huge
			for _, card in cards do
				expect(card.currency).to.equal("acorns")
				expect(CosmeticRegistry.get(card.id).event).to.equal("harvest")
				local price = tonumber((string.gsub(card.price, ",", "")))
				expect(price <= last).to.equal(true)
				last = price
			end
		end)
	end)

	describe("keys", function()
		it("sells the event's Locker keys for acorns, greyed when short", function()
			local keys = VM.keys(HARVEST, 60)
			expect(#keys).to.equal(1)
			expect(keys[1].locker).to.equal("gloom")
			expect(keys[1].name).to.equal("Gloom Locker key")
			expect(keys[1].price).to.equal("60")
			expect(keys[1].enabled).to.equal(true)
			expect(VM.keys(HARVEST, 59)[1].enabled).to.equal(false)
		end)
	end)

	describe("locker", function()
		it("finds the event's own Locker", function()
			expect(VM.locker(HARVEST).id).to.equal("harvest")
			expect(VM.locker({ id = "none" })).to.equal(nil)
		end)
	end)

	describe("resultText", function()
		it("says a refused key buy in kid words", function()
			expect(VM.resultText("")).to.equal(nil)
			expect(VM.resultText("short")).to.equal("Not enough acorns yet!")
			expect(VM.resultText("not on sale")).to.equal("The event is over.")
			expect(VM.resultText("weird")).to.equal("That didn't work. Try again!")
		end)
	end)
end
