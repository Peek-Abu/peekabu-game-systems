local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LockerConstants = require(ReplicatedStorage.Shared.Features.Locker.Data.LockerConstants)
local LockerRules = require(ReplicatedStorage.Shared.Features.Locker.Rules.LockerRules)
local Card = require(script.Parent.LockerCardViewModel)

return function()
	local GLOOM = LockerConstants.LOCKERS.gloom
	local GLEAM = LockerConstants.LOCKERS.gleam

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
			id = "Fixture.SharedIdle",
			kind = "idle",
			name = "Shared Idle",
			rarity = "epic",
			source = "gleamLocker",
			lore = "",
		},
	}

	describe("cards", function()
		it(
			"shows the pity meter on the card: opens since the last Epic+ out of the pity number (owner 11-16 pick A)",
			function()
				local pityAt = LockerRules.odds(GLOOM).pityAt
				local card = Card.card(
					GLOOM,
					{ keys = {}, pity = { gloom = pityAt - 5 }, opened = 9 },
					{ gloom = 0, gleam = 0 },
					false
				)
				expect(card.meter).to.be.ok()
				expect(card.meter.fill).to.be.near((pityAt - 5) / pityAt)
				expect(card.meter.label).to.equal(`{pityAt - 5} / {pityAt}`)
				expect(card.meter.text).to.equal("Epic or better in 5 opens!")
				expect(card.meter.kind).to.equal("gloom")

				local next = Card.card(
					GLOOM,
					{ keys = {}, pity = { gloom = pityAt - 1 }, opened = 9 },
					{ gloom = 0, gleam = 0 },
					false
				)
				expect(next.meter.text).to.equal("Next open is Epic or better!")

				local fresh = Card.card(GLOOM, { keys = {}, pity = {}, opened = 0 }, { gloom = 0, gleam = 0 }, false)
				expect(fresh.meter.fill).to.equal(0)
				expect(fresh.meter.label).to.equal(`0 / {pityAt}`)
				expect(fresh.meter.text).to.equal(`Epic or better in {pityAt} opens!`)
			end
		)

		it(
			"has no meter where there is nothing to count: an empty Locker, or a paid one for a restricted player",
			function()
				local state = { keys = {}, pity = {}, opened = 0 }
				expect(Card.card(GLEAM, state, { gloom = 0, gleam = 0 }, false, {}).meter).to.equal(nil)
				expect(Card.card(GLEAM, state, { gloom = 0, gleam = 0 }, true, SAMPLE_POOL).meter).to.equal(nil)
				expect(Card.card(GLEAM, state, { gloom = 0, gleam = 0 }, false, SAMPLE_POOL).meter.kind).to.equal(
					"stamina"
				)
			end
		)

		it(
			"shows how much of its own money you have on the Gloom and event Lockers (owner 11-16 q2), not the Gleam one",
			function()
				local state = { keys = {}, pity = {}, opened = 0 }
				local gloom = Card.card(GLOOM, state, { gloom = 1240, gleam = 50, acorns = 7 }, false)
				expect(gloom.haveText).to.equal("You have 1,240")
				expect(gloom.haveCurrency).to.equal("gloom")
				local HARVEST = LockerConstants.LOCKERS.harvest
				local harvest = Card.card(HARVEST, state, { gloom = 1240, gleam = 50, acorns = 7 }, false)
				expect(harvest.haveText).to.equal("You have 7")
				expect(harvest.haveCurrency).to.equal("acorns")
				local none = Card.card(HARVEST, state, { gloom = 0, gleam = 0 }, false)
				expect(none.haveText).to.equal("You have 0")
				-- Gleam already sits in the menu bar.
				expect(Card.card(GLEAM, state, { gloom = 0, gleam = 50 }, false).haveText).to.equal(nil)
			end
		)

		it("shows live pity remaining and uses a held key before asking for currency", function()
			local pityAt = LockerRules.odds(GLOOM).pityAt
			local withKey = Card.card(
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

			local withMoney = Card.card(GLOOM, { keys = {}, pity = {}, opened = 0 }, { gloom = 300, gleam = 0 }, false)
			expect(withMoney.button.kind).to.equal("buy")
			expect(withMoney.button.price).to.equal("300")
			expect(withMoney.button.enabled).to.equal(true)

			local short = Card.card(GLOOM, { keys = {}, pity = {}, opened = 0 }, { gloom = 120, gleam = 0 }, false)
			expect(short.button.kind).to.equal("short")
			expect(short.button.text).to.equal("Need 180 more")
			expect(short.button.enabled).to.equal(false)
		end)

		it("switches a paid Locker to direct purchase when restricted, and marks an empty Locker", function()
			local restrictedCard = Card.card(
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

			local emptyCard = Card.card(
				GLEAM,
				{ keys = {}, pity = {}, opened = 0 },
				{ gloom = 0, gleam = 500 },
				false,
				{}
			)
			expect(emptyCard.button.kind).to.equal("empty")
			expect(emptyCard.button.text).to.equal("Coming soon")
		end)

		it(
			"an empty paid Locker tells a restricted player what they can do there, not 'Buy items directly below'",
			function()
				local card = Card.card(
					GLEAM,
					{ keys = {}, pity = {}, opened = 0 },
					{ gloom = 0, gleam = 500 },
					true,
					{}
				)
				expect(card.restricted).to.equal(false)
				expect(card.button.kind).to.equal("empty")
				expect(card.pityText).to.equal("Nothing here yet. Soon you can buy its items one by one.")
				-- Everyone else just sees it is empty.
				local open = Card.card(
					GLEAM,
					{ keys = {}, pity = {}, opened = 0 },
					{ gloom = 0, gleam = 500 },
					false,
					{}
				)
				expect(open.pityText).to.equal("Nothing inside yet.")
			end
		)
	end)
end
