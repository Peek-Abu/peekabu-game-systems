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
			id = "Fixture.SharedIdle",
			kind = "idle",
			name = "Shared Idle",
			rarity = "epic",
			source = "gleamLocker",
			lore = "",
		},
	}

	describe("the event's Locker", function()
		local HARVEST = LockerConstants.LOCKERS.harvest

		it("lists it after the others only while its event is live", function()
			local function ids(list)
				local out = {}
				for _, locker in list do
					table.insert(out, locker.id)
				end
				return table.concat(out, ",")
			end
			expect(ids(VM.lockers(nil))).to.equal("gloom,gleam")
			expect(ids(VM.lockers("harvest"))).to.equal("gloom,gleam,harvest")
		end)

		it("opens with acorns from the acorn balance, and says so in words", function()
			local state = { keys = {}, pity = {}, opened = 0 }
			local card = VM.card(HARVEST, state, { gloom = 0, gleam = 0, acorns = HARVEST.keyPrice }, false)
			expect(card.button.kind).to.equal("buy")
			expect(card.currency).to.equal("acorns")
			local short = VM.card(HARVEST, state, { gloom = 9999, gleam = 9999, acorns = 0 }, false)
			expect(short.button.kind).to.equal("short")
			expect(short.button.enabled).to.equal(false)
			expect(VM.resultText("not on")).to.equal("This Locker is closed now.")
		end)
	end)

	describe("cards", function()
		it(
			"shows how much of its own money you have on the Gloom and event Lockers (owner 11-16 q2), not the Gleam one",
			function()
				local state = { keys = {}, pity = {}, opened = 0 }
				local gloom = VM.card(GLOOM, state, { gloom = 1240, gleam = 50, acorns = 7 }, false)
				expect(gloom.haveText).to.equal("You have 1,240")
				expect(gloom.haveCurrency).to.equal("gloom")
				local HARVEST = LockerConstants.LOCKERS.harvest
				local harvest = VM.card(HARVEST, state, { gloom = 1240, gleam = 50, acorns = 7 }, false)
				expect(harvest.haveText).to.equal("You have 7")
				expect(harvest.haveCurrency).to.equal("acorns")
				local none = VM.card(HARVEST, state, { gloom = 0, gleam = 0 }, false)
				expect(none.haveText).to.equal("You have 0")
				-- Gleam already sits in the menu bar.
				expect(VM.card(GLEAM, state, { gloom = 0, gleam = 50 }, false).haveText).to.equal(nil)
			end
		)

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

		it(
			"an empty paid Locker tells a restricted player what they can do there, not 'Buy items directly below'",
			function()
				local card = VM.card(GLEAM, { keys = {}, pity = {}, opened = 0 }, { gloom = 0, gleam = 500 }, true, {})
				expect(card.restricted).to.equal(false)
				expect(card.button.kind).to.equal("empty")
				expect(card.pityText).to.equal("Nothing here yet. Soon you can buy its items one by one.")
				-- Everyone else just sees it is empty.
				local open = VM.card(GLEAM, { keys = {}, pity = {}, opened = 0 }, { gloom = 0, gleam = 500 }, false, {})
				expect(open.pityText).to.equal("Nothing inside yet.")
			end
		)
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
			expect(directItems[2].id).to.equal("Fixture.SharedIdle")
			expect(directItems[2].directPrice).to.equal("750")
			expect(directItems[2].canBuyDirect).to.equal(true)
		end)
	end)

	describe("itemPage", function()
		it("says which Locker an item comes from and its chance each open, the same as the odds sheet", function()
			local items = VM.inside(GLOOM, owner(), { gloom = 0, gleam = 0 }, false)
			local item = items[1]
			local page = VM.itemPage(GLOOM, item)
			expect(page.from).to.equal("You can get it from the Gloom Locker.")
			local sheet = VM.oddsSheet(GLOOM, { keys = {}, pity = {}, opened = 0 })
			local each
			for _, row in sheet.rarities do
				for _, entry in row.items do
					if entry.id == item.id then
						each = entry.chanceText
					end
				end
			end
			expect(page.chance).to.equal(`{each} chance each time you open it`)
			expect(page.button).to.equal("back")
		end)

		it("offers the direct buy only where the card already does, and Get Gleam when it is too dear", function()
			local items = VM.inside(GLEAM, owner(), { gloom = 0, gleam = 1000 }, true, SAMPLE_POOL)
			expect(VM.itemPage(GLEAM, items[1], SAMPLE_POOL).button).to.equal("getGleam")
			expect(VM.itemPage(GLEAM, items[2], SAMPLE_POOL).button).to.equal("buy")
			local owned = VM.inside(GLEAM, owner({ "Pippa.BubbleBuddy" }), { gloom = 0, gleam = 0 }, true, SAMPLE_POOL)
			expect(VM.itemPage(GLEAM, owned[1], SAMPLE_POOL).button).to.equal("back")
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

	describe("revealOf", function()
		local function outcome(locker, duplicate)
			return {
				locker = locker,
				item = "Pippa.GloomTouched",
				rarity = "uncommon",
				duplicate = duplicate,
				refund = if duplicate then 8 else 0,
				guaranteed = false,
				pity = 2,
			}
		end

		it("hands the rolled item to the reveal with the Locker's own money for a refund", function()
			local gloom = VM.revealOf(outcome("gloom", true))
			expect(gloom.ids[1]).to.equal("Pippa.GloomTouched")
			expect(gloom.source).to.equal("locker")
			expect(gloom.duplicate).to.equal(true)
			expect(gloom.refund).to.equal(8)
			expect(gloom.currency).to.equal("gloom")
			expect(VM.revealOf(outcome("gleam", true)).currency).to.equal("gleam")
			-- The Harvest Locker refunds acorns (owner play-check 11-16 found "Gloom back").
			expect(VM.revealOf(outcome("harvest", true)).currency).to.equal("acorns")
			expect(VM.revealOf(outcome("gloom", false)).duplicate).to.equal(false)
		end)
	end)

	describe("cutscenePose (stage 2 3D cutscene)", function()
		it("walks through establishing, approach, key_turn and burst_open for both Lockers", function()
			local start = VM.cutscenePose("gloom", 0)
			expect(start.beat).to.equal("establishing")
			expect(start.doorDeg).to.equal(0)
			expect(start.glow).to.equal(false)

			local approach = VM.cutscenePose("gloom", 0.35)
			expect(approach.beat).to.equal("approach")
			expect(approach.employeeCFrame.Position.X > 0).to.equal(true)
			expect(VM.cutscenePose("gleam", 0.35).employeeCFrame.Position.X < 0).to.equal(true)

			local turn = VM.cutscenePose("gloom", 0.65)
			expect(turn.beat).to.equal("key_turn")
			expect(turn.keyRollDeg > 0).to.equal(true)
			expect(turn.doorDeg).to.equal(0)

			local burst = VM.cutscenePose("gloom", 0.92)
			expect(burst.beat).to.equal("burst_open")
			expect(burst.doorDeg > 80).to.equal(true)
			expect(burst.glow).to.equal(true)
			expect(burst.flashTransparency < 1).to.equal(true)
		end)

		-- Owner check 11-16: the camera sat behind (then inside) the employee's head, so the locker, the key and the
		-- door were never seen. The employee (about 3.5 studs wide) must stay clear of the camera's line to what it
		-- looks at, and the camera clear of the employee, in every beat after the establishing shot.
		it("never lets the employee block the camera's view of the locker", function()
			for _, id in { "gloom", "gleam", "harvest" } do
				for _, rarity in { "uncommon", "legendary" } do
					for step = 0, 50 do
						local alpha = 0.24 + 0.76 * step / 50
						local pose = VM.cutscenePose(id, alpha, rarity)
						local emp = pose.employeeCFrame.Position
						local a = Vector2.new(pose.camPos.X, pose.camPos.Z)
						local b = Vector2.new(pose.camLook.X, pose.camLook.Z)
						local p = Vector2.new(emp.X, emp.Z)
						local ab = b - a
						local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
						local gap = (a + ab * t - p).Magnitude
						expect(gap > 2.2).to.equal(true)
						expect((a - p).Magnitude > 3).to.equal(true)
					end
				end
			end
		end)
	end)

	-- Owner picks 11-16: about 4 seconds, a door rattle with the prize's colour leaking out before the burst, held
	-- longer, rattled harder, with more and brighter lights the rarer the prize.
	describe("rarity build-up", function()
		local LADDER = { "uncommon", "rare", "epic", "legendary" }

		it("runs about 4 seconds, longer the rarer the prize", function()
			expect(math.abs(VM.openingDuration("uncommon") - 4) < 0.25).to.equal(true)
			for index = 2, #LADDER do
				expect(VM.openingDuration(LADDER[index]) > VM.openingDuration(LADDER[index - 1])).to.equal(true)
			end
			expect(VM.openingDuration("odd") >= VM.openingDuration("legendary")).to.equal(true)
		end)

		it("rattles harder, with more and brighter lights and a bigger burst, the rarer the prize", function()
			for index = 2, #LADDER do
				local lower = VM.RARITY_FX[LADDER[index - 1]]
				local higher = VM.RARITY_FX[LADDER[index]]
				expect(higher.hold > lower.hold).to.equal(true)
				expect(higher.lights > lower.lights).to.equal(true)
				expect(higher.brightness > lower.brightness).to.equal(true)
				expect(higher.rattleDeg > lower.rattleDeg).to.equal(true)
				expect(higher.rays > lower.rays).to.equal(true)
				expect(higher.flash >= lower.flash).to.equal(true)
				expect(#higher.chime >= #lower.chime).to.equal(true)
			end
		end)

		it("rattles the shut door with the light leaking out between the key turn and the burst", function()
			for _, rarity in LADDER do
				local duration = VM.openingDuration(rarity)
				local fx = VM.RARITY_FX[rarity]
				-- The middle of the hold: the last fx.hold seconds before the burst.
				local burstAt = duration - VM.BURST_SECONDS
				local mid = VM.cutscenePose("gloom", (burstAt - fx.hold / 2) / duration, rarity)
				expect(mid.beat).to.equal("rattle")
				expect(mid.glow).to.equal(false)
				expect(mid.doorDeg <= fx.rattleDeg).to.equal(true)
				expect(mid.leak > 0).to.equal(true)
				expect(mid.keyRollDeg).to.equal(90)
				local late = VM.cutscenePose("gloom", (burstAt - 0.02) / duration, rarity)
				expect(late.leak > mid.leak).to.equal(true)
				expect(VM.cutscenePose("gloom", (burstAt + 0.05) / duration, rarity).beat).to.equal("burst_open")
			end
		end)

		-- Owner 11-16: the leak is plain white through the hold, then shows the prize's own colour about half a second
		-- before the door opens (a glimpse of the rarity).
		it("leaks plain white, then the prize's colour in the last half second before the burst", function()
			for _, rarity in LADDER do
				local duration = VM.openingDuration(rarity)
				local burstAt = duration - VM.BURST_SECONDS
				local late = VM.cutscenePose("gloom", (burstAt - 0.05) / duration, rarity)
				expect(late.leakTint > 0.9).to.equal(true)
				expect(VM.cutscenePose("gloom", (burstAt + 0.1) / duration, rarity).leakTint).to.equal(1)
			end
			local hold = VM.RARITY_FX.legendary.hold
			local duration = VM.openingDuration("legendary")
			local burstAt = duration - VM.BURST_SECONDS
			local early = VM.cutscenePose("gloom", (burstAt - hold + 0.1) / duration, "legendary")
			expect(early.beat).to.equal("rattle")
			expect(early.leakTint).to.equal(0)
			expect(VM.GLIMPSE_SECONDS).to.equal(0.5)
		end)

		-- Owner 11-16: the key floats in from screen right, never from the employee (who only idles).
		it("brings the key in from the side away from the employee", function()
			for _, id in { "gloom", "gleam" } do
				local start = VM.cutscenePose(id, 0, "uncommon")
				local emp = start.employeeCFrame.Position
				for step = 0, 60 do
					local pose = VM.cutscenePose(id, step / 60 * 0.7, "uncommon")
					local key = pose.keyCFrame.Position
					if key.Y > -50 then
						expect((key - emp).Magnitude > 2.5).to.equal(true)
						-- The employee stands at +X of the locker; the key comes from -X (screen right).
						expect(key.X < emp.X - 2).to.equal(true)
					end
				end
			end
		end)

		it("flashes brighter at the burst for a rarer prize", function()
			local function brightest(rarity)
				local least = 1
				for step = 0, 100 do
					least = math.min(least, VM.cutscenePose("gloom", step / 100, rarity).flashTransparency)
				end
				return least
			end
			expect(brightest("legendary") < brightest("uncommon")).to.equal(true)
		end)
	end)

	describe("skipAfter", function()
		it("waits a second on your first ever open, then lets you skip at once", function()
			expect(VM.skipAfter(0)).to.equal(VM.SKIP_AFTER)
			expect(VM.skipAfter(1)).to.equal(VM.SKIP_AFTER)
			expect(VM.skipAfter(2)).to.equal(0)
			expect(VM.skipAfter(40)).to.equal(0)
		end)
	end)

	-- Owner 11-16 ("Yes, fade it"): the hub music fades out while a Locker opens and comes back after its reveal.
	describe("musicDucked", function()
		local outcome = {
			locker = "gloom",
			item = "Pippa.GloomTouched",
			rarity = "uncommon",
			duplicate = false,
			refund = 0,
			guaranteed = false,
			pity = 1,
		}

		it("ducks the music while an opening plays and while its reveal is up, not otherwise", function()
			expect(VM.musicDucked(nil, nil)).to.equal(false)
			expect(VM.musicDucked(outcome, nil)).to.equal(true)
			expect(VM.musicDucked(nil, { ids = { "Pippa.GloomTouched" }, source = "locker" })).to.equal(true)
			-- Another reveal (a Shop buy, a grant) leaves the music alone.
			expect(VM.musicDucked(nil, { ids = { "Pippa.GloomTouched" }, source = "shop" })).to.equal(false)
			expect(VM.MUSIC_DUCK_DB < -20).to.equal(true)
		end)
	end)
end
