local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local LockerConstants = require(ReplicatedStorage.Shared.Features.Locker.Data.LockerConstants)
local LockerRules = require(ReplicatedStorage.Shared.Features.Locker.Rules.LockerRules)
local VM = require(script.Parent.LockerViewModel)

return function()
	local GLOOM = LockerConstants.LOCKERS.gloom
	local GLEAM = LockerConstants.LOCKERS.gleam

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

	local SAMPLE_POOL = {
		{
			id = "Pippa.BubbleBuddy",
			kind = "skin",
			name = "Bubble Buddy",
			rarity = "legendary",
			source = "gleamLocker",
			employee = "Pippa",
			lore = "",
		},
		{
			id = "SleepySway",
			kind = "idle",
			name = "Sleepy Sway",
			rarity = "epic",
			source = "gleamLocker",
			lore = "",
		},
	}

	describe("cards", function()
		it("shows live pity remaining and uses a held key before asking for currency", function()
			local pityAt = LockerRules.odds(GLOOM).pityAt
			local withKey = VM.card(
				GLOOM,
				{ keys = { gloom = 2 }, pity = { gloom = 5 }, opened = 5 },
				{ gloom = 0, gleam = 0 },
				false
			)
			expect(withKey.keysText).to.equal("2 keys")
			expect(withKey.button.kind).to.equal("key")
			expect(withKey.button.text).to.equal("Open (1 key)")
			expect(withKey.button.enabled).to.equal(true)
			expect(withKey.pityText).to.equal(`Epic or better in {pityAt - 5} opens or sooner.`)

			local withMoney = VM.card(GLOOM, { keys = {}, pity = {}, opened = 0 }, { gloom = 300, gleam = 0 }, false)
			expect(withMoney.button.kind).to.equal("buy")
			expect(withMoney.button.price).to.equal("300")
			expect(withMoney.button.enabled).to.equal(true)

			local short = VM.card(GLOOM, { keys = {}, pity = {}, opened = 0 }, { gloom = 120, gleam = 0 }, false)
			expect(short.button.kind).to.equal("short")
			expect(short.button.text).to.equal("Need 180 more")
			expect(short.button.enabled).to.equal(false)
		end)

		it("switches a paid Locker to direct purchase when restricted, and marks an empty Locker", function()
			local restrictedCard = VM.card(
				GLEAM,
				{ keys = { gleam = 1 }, pity = {}, opened = 0 },
				{ gloom = 0, gleam = 500 },
				true,
				SAMPLE_POOL
			)
			expect(restrictedCard.restricted).to.equal(true)
			expect(restrictedCard.button.kind).to.equal("restricted")
			expect(restrictedCard.button.text).to.equal("Buy directly")
			expect(restrictedCard.button.enabled).to.equal(false)

			local emptyCard = VM.card(
				GLEAM,
				{ keys = {}, pity = {}, opened = 0 },
				{ gloom = 0, gleam = 500 },
				false,
				{}
			)
			expect(emptyCard.button.kind).to.equal("empty")
			expect(emptyCard.button.text).to.equal("Coming soon")
		end)
	end)

	describe("inside", function()
		it("lists every item in the Locker with its Owned tick and restricted direct price", function()
			local gloomItems = VM.inside(GLOOM, owner({ "Pippa.GloomTouched" }), { gloom = 500, gleam = 500 }, false)
			expect(#gloomItems > 0).to.equal(true)
			local foundOwned = false
			for _, entry in gloomItems do
				if entry.id == "Pippa.GloomTouched" then
					foundOwned = entry.owned
				end
				expect(entry.directPrice).to.equal(nil)
			end
			expect(foundOwned).to.equal(true)

			local directItems = VM.inside(GLEAM, owner(), { gloom = 0, gleam = 1000 }, true, SAMPLE_POOL)
			expect(#directItems).to.equal(2)
			-- Sorted highest rarity first: Legendary (1,500) then Epic (750)
			expect(directItems[1].id).to.equal("Pippa.BubbleBuddy")
			expect(directItems[1].directPrice).to.equal("1,500")
			expect(directItems[1].canBuyDirect).to.equal(false)
			expect(directItems[2].id).to.equal("SleepySway")
			expect(directItems[2].directPrice).to.equal("750")
			expect(directItems[2].canBuyDirect).to.equal(true)
		end)
	end)

	describe("oddsSheet", function()
		it("shows real scaled percentages, per-item chances, the pity sentence and duplicate refunds", function()
			local sheet = VM.oddsSheet(GLOOM, { keys = {}, pity = { gloom = 2 }, opened = 2 })
			expect(#sheet.rarities).to.equal(2)
			expect(string.find(sheet.pityRule, "Epic or better is guaranteed") ~= nil).to.equal(true)
			expect(sheet.rarities[1].rarity).to.equal("uncommon")
			expect(sheet.rarities[1].refundText).to.equal("+45 Gloom back")
			expect(sheet.rarities[2].rarity).to.equal("epic")
			expect(sheet.rarities[2].refundText).to.equal("+180 Gloom back")
		end)
	end)

	describe("openingView & resultText", function()
		it("formats duplicate refund text and refusal messages in kid words", function()
			local view = VM.openingView({
				locker = "gloom",
				item = "Pippa.GloomTouched",
				rarity = "epic",
				duplicate = true,
				refund = 180,
				guaranteed = true,
				pity = 0,
			})
			expect(view.duplicateLine).to.equal("You already have this! +180 Gloom back")
			expect(VM.resultText("short")).to.equal("Not enough yet!")
			expect(VM.resultText("empty")).to.equal("Nothing in this Locker yet!")
			expect(VM.resultText("")).to.equal(nil)
		end)
	end)
end
