local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local LockerConstants = require(ReplicatedStorage.Shared.Features.Locker.Data.LockerConstants)
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

	describe("the cutscene, re-exported from LockerCutsceneViewModel", function()
		it("keeps the same functions and tuning under LockerViewModel", function()
			local Cutscene = require(script.Parent.LockerCutsceneViewModel)
			expect(VM.cutscenePose).to.equal(Cutscene.cutscenePose)
			expect(VM.openingDuration).to.equal(Cutscene.openingDuration)
			expect(VM.RARITY_FX).to.equal(Cutscene.RARITY_FX)
			expect(VM.BURST_SECONDS).to.equal(Cutscene.BURST_SECONDS)
			expect(VM.GLIMPSE_SECONDS).to.equal(Cutscene.GLIMPSE_SECONDS)
		end)
	end)
end
