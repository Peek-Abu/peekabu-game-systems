local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticConstants = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticConstants)
local VM = require(script.Parent.RevealViewModel)

local BUNDLE = { "Pippa.BubbleBuddy", "Pippa.Bubbles", "BubblePack", "Pippa.BubbleBuddyIdle" }

local function ownsAll()
	return true
end

-- A player who owns everything, with `edit` applied to a fresh loadout.
local function context(edit, focus)
	local loadout = CosmeticConstants.defaultLoadout()
	if edit ~= nil then
		edit(loadout)
	end
	return { loadout = loadout, owns = ownsAll, focus = focus }
end

local function pippaLook(skin, idle, wheel)
	return {
		skin = skin or "Pippa.Default",
		style = 1,
		idle = idle or "Pippa.Classic",
		wheel = wheel or { "", "", "", "" },
	}
end

return function()
	it("shouts the rarity, louder as it climbs", function()
		expect(VM.view({ ids = { "Pippa.GloomTouched" }, source = "shop" }).title).to.equal("NICE!")
		expect(VM.view({ ids = { "Pippa.OwnerSpecial" }, source = "grant" }).title).to.equal("RARE!")
		expect(VM.view({ ids = { "Pippa.Gloomkeeper" }, source = "grant" }).title).to.equal("EPIC!")
		expect(VM.view({ ids = { "Pippa.BubbleBuddy" }, source = "shop" }).title).to.equal("LEGENDARY!")
	end)

	it("adds effects up the ladder: rays from Rare, stripes and sparkles from Epic, confetti for Legendary", function()
		local uncommon = VM.view({ ids = { "Pippa.GloomTouched" }, source = "shop" }).effects
		expect(uncommon.rays).to.equal(false)
		local rare = VM.view({ ids = { "Pippa.OwnerSpecial" }, source = "grant" }).effects
		expect(rare.rays).to.equal(true)
		expect(rare.stripes).to.equal(false)
		local epic = VM.view({ ids = { "Pippa.Gloomkeeper" }, source = "grant" }).effects
		expect(epic.stripes).to.equal(true)
		expect(epic.sparkles).to.equal(true)
		expect(epic.confetti).to.equal(false)
		local legendary = VM.view({ ids = { "Pippa.BubbleBuddy" }, source = "shop" }).effects
		expect(legendary.confetti).to.equal(true)
		expect(legendary.foil).to.equal(true)
		expect(epic.foil).to.equal(false)
		expect(VM.view({ ids = { "Pippa" }, source = "pick" }).effects.foil).to.equal(true)
	end)

	it("says what it is and whose", function()
		local view = VM.view({ ids = { "Pippa.BubbleBuddy" }, source = "shop" })
		expect(view.ribbon).to.equal("New skin for Pippa")
		expect(view.name).to.equal("Bubble Buddy")
		expect(view.employee).to.equal("Pippa")
		expect(view.skinKey).to.equal("BubbleBuddy")
		-- A skin alone brings nothing else (owner, 2026-11-13): no tiles, one item.
		expect(#view.items).to.equal(0)
		expect(view.multi).to.equal(false)
	end)

	it("lets you pick which colour style to wear for a new skin that has styles", function()
		local bubble = VM.view({ ids = { "Pippa.BubbleBuddy" }, source = "shop" })
		expect(#bubble.styles).to.equal(3)
		expect(#bubble.styles[1].name > 0).to.equal(true)
		expect(#bubble.styles[1].swatch).to.equal(2)
		local wear = VM.wear(bubble, 2)
		expect(#wear).to.equal(1)
		expect(wear[1].kind).to.equal("skin")
		expect(wear[1].id).to.equal("Pippa.BubbleBuddy")
		expect(wear[1].style).to.equal(2)
		-- A skin without styles shows no chips and wears its only look.
		local gloom = VM.view({ ids = { "Pippa.GloomTouched" }, source = "shop" })
		expect(#gloom.styles).to.equal(0)
		expect(VM.wear(gloom, 3)[1].style).to.equal(1)
		-- Not a skin: the changes are untouched.
		expect(VM.wear(VM.view({ ids = { "Cappy.PJIdle" }, source = "shop" }), 2)[1].kind).to.equal("idle")
	end)

	describe("the button's words fit what you got", function()
		it("says Wear it! for a skin, Use it! for an idle or a vacuum, Add to wheel! for an emote", function()
			expect(VM.view({ ids = { "Pippa.GloomTouched" }, source = "shop" }, context()).primary).to.equal("Wear it!")
			expect(VM.view({ ids = { "Cappy.PJIdle" }, source = "shop" }, context()).primary).to.equal("Use it!")
			expect(VM.view({ ids = { "Vacuum.BrassBellows" }, source = "shop" }, context()).primary).to.equal("Use it!")
			expect(VM.view({ ids = { "Pippa.Bubbles" }, source = "shop" }, context()).primary).to.equal("Add to wheel!")
		end)

		it("opens a small sticker picker for a sticker pack, on the reveal (not the Inventory)", function()
			local view = VM.view({ ids = { "CozyPack" }, source = "shop" }, context())
			expect(view.primary).to.equal("Use stickers!")
			-- Nothing is put on by itself (owner 11-14: stickers are not on or off).
			expect(#VM.wear(view, 1)).to.equal(0)
			expect(view.picker).to.equal("stickers")
		end)

		it("opens a small emote wheel for an emote, on the reveal (not the Inventory)", function()
			local view = VM.view({ ids = { "Pippa.Bubbles" }, source = "shop" }, context())
			expect(view.primary).to.equal("Add to wheel!")
			expect(#view.changes).to.equal(0)
			expect(view.picker).to.equal("wheel")
		end)

		it("never greys out a wheel or sticker item: you can always move it", function()
			local wheel = VM.view(
				{ ids = { "Pippa.Bubbles" }, source = "shop" },
				context(function(loadout)
					loadout.looks.Pippa = pippaLook(nil, nil, { "Pippa.Wave", "Pippa.Bubbles", "", "" })
				end)
			)
			expect(wheel.primary).to.equal("Add to wheel!")
			expect(wheel.done).to.equal(false)
			expect(wheel.picker).to.equal("wheel")
			-- A skin, an idle or a vacuum never opens a picker.
			expect(VM.view({ ids = { "Pippa.GloomTouched" }, source = "shop" }, context()).picker).to.equal(nil)
			expect(VM.view({ ids = { "Cappy.PJIdle" }, source = "shop" }, context()).picker).to.equal(nil)
		end)

		it("says it is already on once it is (and sends nothing)", function()
			local worn = VM.view(
				{ ids = { "Pippa.GloomTouched" }, source = "shop" },
				context(function(loadout)
					loadout.looks.Pippa = pippaLook("Pippa.GloomTouched")
				end)
			)
			expect(worn.primary).to.equal("Wearing it!")
			expect(worn.done).to.equal(true)
			expect(#worn.changes).to.equal(0)
			local vacuum = VM.view(
				{ ids = { "Vacuum.BrassBellows" }, source = "shop" },
				context(function(loadout)
					loadout.vacuum = "Vacuum.BrassBellows"
				end)
			)
			expect(vacuum.primary).to.equal("Using it!")
		end)

		it("stays open while you pick a spot, then Done leaves", function()
			local view = VM.view({ ids = { "Pippa.Bubbles" }, source = "shop" }, context())
			expect(view.stays).to.equal(true)
			expect(view.later).to.equal(true)
			expect(view.leave).to.equal("Done")
		end)

		it("says Use it! for an idle whatever skin is on (every idle fits every skin of its employee)", function()
			local classic = VM.view({ ids = { "Pippa.BubbleBuddyIdle" }, source = "shop" }, context())
			expect(classic.primary).to.equal("Use it!")
			expect(classic.changes[1].kind).to.equal("idle")
			local other = VM.view(
				{ ids = { "Pippa.BubbleBuddyIdle" }, source = "shop" },
				context(function(loadout)
					loadout.looks.Pippa = pippaLook("Pippa.GloomTouched")
				end)
			)
			expect(other.primary).to.equal("Use it!")
		end)

		it("offers Later for something new to use, and just a thank-you when nothing can be used", function()
			local skin = VM.view({ ids = { "Pippa.GloomTouched" }, source = "shop" })
			expect(skin.later).to.equal(true)
			expect(skin.leave).to.equal("Later")
			local idle = VM.view({ ids = { "Cappy.PJIdle" }, source = "shop" })
			expect(idle.changes[1].kind).to.equal("idle")
			expect(idle.changes[1].employee).to.equal("Cappy")
			local unknown = VM.view({ ids = { "Nope" }, source = "grant" })
			expect(unknown.primary).to.equal("Nice!")
			expect(#unknown.changes).to.equal(0)
			expect(unknown.later).to.equal(false)
		end)
	end)

	describe("the small pickers", function()
		it("shows the emote's employee's wheel: each slot, what is in it, and the new emote's own slot", function()
			local ctx = context(function(loadout)
				loadout.looks.Pippa = pippaLook(nil, nil, { "Pippa.Wave", "Pippa.Bubbles", "", "" })
			end)
			local slots = VM.wheel("Pippa.Bubbles", ctx)
			expect(#slots).to.equal(CosmeticConstants.WHEEL_SLOTS)
			expect(slots[1].name).to.equal(VM.view({ ids = { "Pippa.Wave" }, source = "shop" }).name)
			expect(slots[2].mine).to.equal(true)
			expect(slots[3].empty).to.equal(true)
		end)

		it("asks before swapping out an emote, and never for an empty slot or its own", function()
			local slots = VM.wheel(
				"Pippa.Bubbles",
				context(function(loadout)
					loadout.looks.Pippa = pippaLook(nil, nil, { "Pippa.Wave", "", "", "" })
				end)
			)
			local wave = slots[1].name
			expect(VM.swapQuestion(slots[1], "Bubble Ride")).to.equal(`Swap {wave} for Bubble Ride?`)
			expect(VM.swapQuestion(slots[2], "Bubble Ride")).to.equal(nil)
		end)

		it("puts the emote in the slot you tap", function()
			local change = VM.wheelChange("Pippa.Bubbles", 3)
			expect(change.kind).to.equal("emote")
			expect(change.employee).to.equal("Pippa")
			expect(change.slot).to.equal(3)
			expect(change.id).to.equal("Pippa.Bubbles")
		end)

		it("shows the pack's own stickers and your sticker spots, and puts the one you tap where you tap", function()
			local pick = VM.stickers(
				"CozyPack",
				context(function(loadout)
					loadout.stickers = { "", "BubblePack.Yay", "", "" }
				end)
			)
			expect(#pick.stickers).to.equal(4)
			for _, sticker in pick.stickers do
				expect(string.sub(sticker.id, 1, #"CozyPack.")).to.equal("CozyPack.")
			end
			expect(#pick.slots).to.equal(CosmeticConstants.STICKER_SLOTS)
			expect(pick.slots[2].empty).to.equal(false)
			expect(pick.slots[1].empty).to.equal(true)
			local change = VM.stickerChange(pick.stickers[1].id, 4)
			expect(change.kind).to.equal("sticker")
			expect(change.slot).to.equal(4)
			expect(change.id).to.equal(pick.stickers[1].id)
		end)
	end)

	describe("the item in front plays as itself", function()
		it(
			"plays an idle on the skin you wear (Classic by default, never its Legendary skin), and loops an emote",
			function()
				local idle = VM.view({ ids = { "Pippa.BubbleBuddyIdle" }, source = "shop" }, context())
				expect(idle.idle).to.equal("BubbleBuddyIdle")
				expect(idle.skinKey).to.equal(nil)
				local wearing = VM.view(
					{ ids = { "Pippa.BubbleBuddyIdle" }, source = "shop" },
					context(function(loadout)
						loadout.looks.Pippa = pippaLook("Pippa.GloomTouched")
					end)
				)
				expect(wearing.skinKey).to.equal("GloomTouched")
				local shared = VM.view({ ids = { "Cappy.PJIdle" }, source = "shop" })
				expect(shared.idle).to.equal("PJIdle")
				expect(shared.skinKey).to.equal(nil)
				local emote = VM.view({ ids = { "Pippa.Bubbles" }, source = "shop" })
				expect(emote.emote).to.equal("Pippa.Bubbles")
				expect(emote.idle).to.equal(nil)
			end
		)

		it("shows a sticker pack as its stickers, not an employee", function()
			expect(VM.view({ ids = { "CozyPack" }, source = "shop" }).stickers).to.equal(true)
			expect(VM.view({ ids = { "Pippa.BubbleBuddy" }, source = "shop" }).stickers).to.equal(false)
		end)
	end)

	describe("a buy with more than one item", function()
		it("shows every item as a tile, the one in front picked", function()
			local view = VM.view({ ids = BUNDLE, source = "shop" }, context())
			expect(view.multi).to.equal(true)
			expect(#view.items).to.equal(4)
			expect(view.items[1].selected).to.equal(true)
			expect(view.items[2].kind).to.equal("Emote")
			expect(view.items[3].id).to.equal("BubblePack")
			expect(view.name).to.equal("Bubble Buddy")
		end)

		it("puts the tile you tap in front, with its own button", function()
			local emote = VM.view({ ids = BUNDLE, source = "shop" }, context(nil, 2))
			expect(emote.name).to.equal(VM.view({ ids = { "Pippa.Bubbles" }, source = "shop" }).name)
			expect(emote.items[2].selected).to.equal(true)
			expect(emote.items[1].selected).to.equal(false)
			expect(emote.primary).to.equal("Add to wheel!")
			local pack = VM.view({ ids = BUNDLE, source = "shop" }, context(nil, 3))
			expect(pack.primary).to.equal("Use stickers!")
			-- Out of range: the first.
			expect(VM.view({ ids = BUNDLE, source = "shop" }, context(nil, 9)).items[1].selected).to.equal(true)
		end)

		it("stays open after you use something, and leaves only on Done", function()
			local view = VM.view({ ids = BUNDLE, source = "shop" }, context())
			expect(view.stays).to.equal(true)
			expect(view.later).to.equal(true)
			expect(view.leave).to.equal("Done")
			-- Something already on still shows it, and Done is still there.
			local worn = VM.view(
				{ ids = BUNDLE, source = "shop" },
				context(function(loadout)
					loadout.looks.Pippa = pippaLook("Pippa.BubbleBuddy")
				end)
			)
			expect(worn.done).to.equal(true)
			expect(worn.items[1].done).to.equal(true)
			expect(worn.later).to.equal(true)
		end)

		it("marks a worn skin's tile as on, never an emote's or a sticker pack's", function()
			local view = VM.view(
				{ ids = BUNDLE, source = "shop" },
				context(function(loadout)
					loadout.looks.Pippa = pippaLook("Pippa.BubbleBuddy", nil, { "Pippa.Wave", "Pippa.Bubbles", "", "" })
				end)
			)
			expect(view.items[1].done).to.equal(true)
			expect(view.items[2].done).to.equal(false)
			expect(view.items[3].done).to.equal(false)
		end)

		it("a single item closes on its button, as before", function()
			expect(VM.view({ ids = { "Pippa.GloomTouched" }, source = "shop" }, context()).stays).to.equal(false)
		end)
	end)

	it("hires: the ID card and ability, Start! after the first pick, Equip! after a purchase", function()
		local pick = VM.view({ ids = { "Pippa" }, source = "pick" })
		expect(pick.kind).to.equal("hire")
		expect(pick.title).to.equal("YOU'RE HIRED!")
		expect(pick.primary).to.equal("Start!")
		expect(#pick.changes).to.equal(0)
		expect(pick.ability.name).to.equal("Let's Go!")
		local bought = VM.view({ ids = { "Prickles" }, source = "shop" })
		expect(bought.primary).to.equal("Equip!")
		expect(bought.changes[1].kind).to.equal("employee")
		expect(bought.changes[1].id).to.equal("Prickles")
		expect(bought.stays).to.equal(false)
	end)

	it("shows a new vacuum on your employee and offers it for the whole crew", function()
		local view = VM.view({ ids = { "Vacuum.BrassBellows" }, source = "shop" })
		expect(view.ribbon).to.equal("New vacuum for your crew")
		expect(view.vacuum).to.equal("Vacuum.BrassBellows")
		expect(view.changes[1].kind).to.equal("vacuum")
		expect(view.changes[1].id).to.equal("Vacuum.BrassBellows")
	end)

	it("copes with an id it does not know", function()
		local view = VM.view({ ids = { "Nope" }, source = "grant" })
		expect(view.title).to.equal("NEW!")
		expect(view.primary).to.equal("Nice!")
	end)

	it("tells you when a Locker roll was a duplicate and how much came back", function()
		local view = VM.view({
			ids = { "Pippa.GloomTouched" },
			source = "locker",
			duplicate = true,
			refund = 90,
			currency = "gloom",
		})
		expect(view.ribbon).to.equal("You already have this! +90 Gloom back")
		expect(view.primary).to.equal("Nice!")
		expect(view.later).to.equal(false)
	end)

	it("names acorns on an event Locker's duplicate (the refund is paid in acorns, not Gloom)", function()
		local view = VM.view({
			ids = { "Pippa.GloomTouched" },
			source = "locker",
			duplicate = true,
			refund = 8,
			currency = "acorns",
		})
		expect(view.ribbon).to.equal("You already have this! +8 acorns back")
	end)

	describe("a Robux purchase (owner 11-15: a You bought it! screen)", function()
		it("Gleam: shouts the amount and shows the bundle's art", function()
			local view =
				VM.view({ ids = {}, source = "robux", purchase = { kind = "gleam", key = "gleam880", amount = 880 } })
			expect(view.kind).to.equal("purchase")
			expect(view.title).to.equal("+880 GLEAM!")
			expect(view.ribbon).to.equal("Thank you!")
			expect(view.name).to.equal("880 Gleam")
			expect(view.art).to.be.ok()
			expect(view.art.image).to.be.a("string")
			expect(view.primary).to.equal("Nice!")
			expect(view.later).to.equal(false)
			expect(#view.changes).to.equal(0)
			expect(view.effects.confetti).to.equal(true)
			expect(view.effects.sparkles).to.equal(false)
		end)

		it("groups a big Gleam amount", function()
			local view =
				VM.view({ ids = {}, source = "robux", purchase = { kind = "gleam", key = "gleam1950", amount = 1950 } })
			expect(view.title).to.equal("+1,950 GLEAM!")
		end)

		it("a pass: its name and line, and the truck for Big Crew", function()
			local view =
				VM.view({ ids = {}, source = "robux", purchase = { kind = "pass", key = "bigCrew", amount = 1 } })
			expect(view.kind).to.equal("purchase")
			expect(view.title).to.equal("YOU GOT IT!")
			expect(view.name).to.equal("Big Crew")
			expect(view.line).to.equal("Your truck holds 6 friends! Only you need it.")
			expect(view.art.icon).to.equal("truck")
		end)

		it("coffee: the cup, and what it does", function()
			local view =
				VM.view({ ids = {}, source = "robux", purchase = { kind = "coffee", key = "coffeeCrew", amount = 30 } })
			expect(view.title).to.equal("COFFEE TIME!")
			expect(view.name).to.equal("Coffee for the crew")
			expect(view.line).to.equal("2x Credits and Gloom for your crew for 30 minutes of shifts!")
			expect(view.art.icon).to.equal("coffee")
		end)

		it("closes on its button", function()
			local view =
				VM.view({ ids = {}, source = "robux", purchase = { kind = "coffee", key = "coffeeCrew", amount = 30 } })
			expect(view.stays).to.equal(false)
			expect(view.picker).to.equal(nil)
			expect(#VM.wear(view, 1)).to.equal(0)
		end)
	end)
end
