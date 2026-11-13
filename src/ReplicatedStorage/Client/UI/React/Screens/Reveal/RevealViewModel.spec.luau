local VM = require(script.Parent.RevealViewModel)

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

	it("says what it is and whose, and lists what came with it", function()
		local view = VM.view({ ids = { "Pippa.BubbleBuddy" }, source = "shop" })
		expect(view.ribbon).to.equal("New skin for Pippa")
		expect(view.name).to.equal("Bubble Buddy")
		expect(view.employee).to.equal("Pippa")
		expect(view.skinKey).to.equal("BubbleBuddy")
		-- A skin alone brings nothing else (owner, 2026-11-13).
		expect(#view.alsoGot).to.equal(0)
		-- A bundle's grant lists every item: the hero first, the rest came with it.
		local bundle = VM.view({ ids = { "Pippa.BubbleBuddy", "Pippa.Bubbles", "BubblePack" }, source = "shop" })
		expect(bundle.name).to.equal("Bubble Buddy")
		expect(#bundle.alsoGot).to.equal(2)
		expect(bundle.alsoGot[1].kind).to.equal("Emote")
		expect(bundle.alsoGot[2].id).to.equal("BubblePack")
	end)

	it("lets you pick which colour style to wear for a new skin that has styles", function()
		local bubble = VM.view({ ids = { "Pippa.BubbleBuddy" }, source = "shop" })
		expect(#bubble.styles).to.equal(3)
		expect(#bubble.styles[1].name > 0).to.equal(true)
		expect(#bubble.styles[1].swatch).to.equal(2)
		local wear = VM.wear(bubble, 2)
		expect(wear.kind).to.equal("skin")
		expect(wear.id).to.equal("Pippa.BubbleBuddy")
		expect(wear.style).to.equal(2)
		-- A skin without styles shows no chips and wears its only look.
		local gloom = VM.view({ ids = { "Pippa.GloomTouched" }, source = "shop" })
		expect(#gloom.styles).to.equal(0)
		expect(VM.wear(gloom, 3).style).to.equal(1)
		-- Not a skin: the change is untouched; nothing to wear: nil.
		expect(VM.wear(VM.view({ ids = { "Cappy.Classic" }, source = "shop" }), 2).kind).to.equal("idle")
		expect(VM.wear(VM.view({ ids = { "CozyPack" }, source = "shop" }), 1)).to.equal(nil)
	end)

	it("offers Wear it! for something you can wear, and just a thank-you otherwise", function()
		local skin = VM.view({ ids = { "Pippa.GloomTouched" }, source = "shop" })
		expect(skin.primary).to.equal("Wear it!")
		expect(skin.change.kind).to.equal("skin")
		expect(skin.later).to.equal(true)
		local idle = VM.view({ ids = { "Cappy.Classic" }, source = "shop" })
		expect(idle.change.kind).to.equal("idle")
		expect(idle.change.employee).to.equal("Cappy")
		local pack = VM.view({ ids = { "CozyPack" }, source = "shop" })
		expect(pack.primary).to.equal("Nice!")
		expect(pack.change).to.equal(nil)
		expect(pack.later).to.equal(false)
	end)

	it("hires: the ID card and ability, Start! after the first pick, Equip! after a purchase", function()
		local pick = VM.view({ ids = { "Pippa" }, source = "pick" })
		expect(pick.kind).to.equal("hire")
		expect(pick.title).to.equal("YOU'RE HIRED!")
		expect(pick.primary).to.equal("Start!")
		expect(pick.change).to.equal(nil)
		expect(pick.ability.name).to.equal("Let's Go!")
		local bought = VM.view({ ids = { "Prickles" }, source = "shop" })
		expect(bought.primary).to.equal("Equip!")
		expect(bought.change.kind).to.equal("employee")
		expect(bought.change.id).to.equal("Prickles")
	end)

	it("shows a new vacuum on your employee and offers to wear it for the whole crew", function()
		local view = VM.view({ ids = { "Vacuum.BrassBellows" }, source = "shop" })
		expect(view.ribbon).to.equal("New vacuum for your crew")
		expect(view.vacuum).to.equal("Vacuum.BrassBellows")
		expect(view.primary).to.equal("Wear it!")
		expect(view.change.kind).to.equal("vacuum")
		expect(view.change.id).to.equal("Vacuum.BrassBellows")
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
end
