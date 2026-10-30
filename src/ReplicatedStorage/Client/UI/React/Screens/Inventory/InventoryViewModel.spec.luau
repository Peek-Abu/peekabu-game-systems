local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticConstants = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticConstants)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local VM = require(script.Parent.InventoryViewModel)

return function()
	-- Owns every free item plus the ids given.
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

	local function loadout(patch)
		local value = CosmeticConstants.defaultLoadout()
		for key, v in patch or {} do
			value[key] = v
		end
		return value
	end

	local function find(list, id)
		for _, entry in list do
			if entry.id == id then
				return entry
			end
		end
		return nil
	end

	describe("crew", function()
		it("has one card per employee in the catalogue, the free one first", function()
			local cards = VM.crew(loadout(), owner())
			expect(#cards).to.equal(#CosmeticRegistry.employees())
			for _, name in CosmeticRegistry.employees() do
				expect(find(cards, name)).to.be.ok()
			end
			expect(cards[1].id).to.equal("Pippa")
		end)

		it("marks the current employee wearing, owned ones equippable and the rest locked with a price", function()
			local cards = VM.crew(loadout({ current = "Pippa" }), owner({ "Prickles" }))
			expect(find(cards, "Pippa").state).to.equal("wearing")
			expect(find(cards, "Prickles").state).to.equal("owned")
			local cappy = find(cards, "Cappy")
			expect(cappy.state).to.equal("locked")
			expect(cappy.price).to.equal(2500)
			expect(cappy.priceText).to.equal("2,500")
			expect(find(cards, "Pippa").priceText).to.equal(nil)
		end)

		it("shows each employee in the skin they wear, with its name and the art key", function()
			local value = loadout({
				looks = {
					Pippa = {
						skin = "Pippa.OwnerSpecial",
						style = 1,
						idle = "Pippa.Classic",
						wheel = { "", "", "", "" },
					},
				},
			})
			local pippa = find(VM.crew(value, owner({ "Pippa.OwnerSpecial" })), "Pippa")
			expect(pippa.skinName).to.equal("Lavender Specs")
			expect(pippa.skinKey).to.equal("OwnerSpecial")
			expect(find(VM.crew(value, owner()), "Pippa").skinKey).to.equal("Default")
		end)

		it("carries the profile's line, ability (with its render) and colour", function()
			for _, card in VM.crew(loadout(), owner()) do
				expect(card.abilityImage).to.be.ok()
			end
			local pippa = find(VM.crew(loadout(), owner()), "Pippa")
			expect(pippa.line).to.equal("Crew speedster")
			expect(pippa.ability).to.equal("Let's Go!")
			expect(typeof(pippa.color.body)).to.equal("Color3")
		end)
	end)

	describe("band", function()
		it("gives owned items no band and the worn one a Wearing band", function()
			expect(VM.band(CosmeticRegistry.get("Pippa.GloomTouched"), true, false)).to.equal(nil)
			local worn = VM.band(CosmeticRegistry.get("Pippa.Default"), true, true)
			expect(worn.kind).to.equal("wearing")
			expect(worn.text).to.equal("Wearing")
		end)

		it("names where a locked item comes from", function()
			local gleam = VM.band(CosmeticRegistry.get("Pippa.BubbleBuddy"), false, false)
			expect(gleam.kind).to.equal("gleam")
			expect(gleam.text).to.equal("1,500")
			expect(VM.band(CosmeticRegistry.get("Pippa.Gloomkeeper"), false, false).kind).to.equal("locker")
			expect(VM.band(CosmeticRegistry.get("Pippa.OwnerSpecial"), false, false).kind).to.equal("missed")
		end)

		it("covers every source a locked item can have", function()
			for _, source in { "credits", "gleam", "gloomLocker", "gleamLocker", "goal", "event", "gift", "later" } do
				local band = VM.band({
					id = "X",
					kind = "skin",
					name = "X",
					rarity = "rare",
					source = source,
					price = 10,
					lore = "",
				}, false, false)
				expect(band).to.be.ok()
				expect(band.text ~= "").to.equal(true)
			end
		end)
	end)

	describe("action", function()
		it("says Wear for an owned item and Wearing for the worn one", function()
			local wear = VM.action(CosmeticRegistry.get("Pippa.GloomTouched"), true, false)
			expect(wear.text).to.equal("Wear")
			expect(wear.enabled).to.equal(true)
			local wearing = VM.action(CosmeticRegistry.get("Pippa.Default"), true, true)
			expect(wearing.text).to.equal("Wearing")
			expect(wearing.enabled).to.equal(false)
		end)

		it("sends a buyable item to its Shop page, with its price", function()
			local action = VM.action(CosmeticRegistry.get("Pippa.BubbleBuddy"), false, false)
			expect(action.text).to.equal("See in Shop")
			expect(action.kind).to.equal("shop")
			expect(action.enabled).to.equal(true)
			expect(action.price.currency).to.equal("gleam")
			expect(action.price.amount).to.equal("1,500")
		end)

		it("points other locked items at where to get them, never as a working button", function()
			local cases = {
				["Pippa.Gloomkeeper"] = "Gloom Locker",
				["Pippa.OwnerSpecial"] = "Missed it",
			}
			for id, text in cases do
				local action = VM.action(CosmeticRegistry.get(id), false, false)
				expect(action.text).to.equal(text)
				expect(action.enabled).to.equal(false)
				expect(action.kind).to.equal("none")
			end
		end)
	end)

	describe("items", function()
		it("lists the employee's skins with the free one first and the worn one marked", function()
			local list = VM.items("skin", "Pippa", loadout(), owner())
			expect(list[1].id).to.equal("Pippa.Default")
			expect(list[1].worn).to.equal(true)
			expect(list[1].band.kind).to.equal("wearing")
			for _, entry in list do
				expect(CosmeticRegistry.get(entry.id).employee).to.equal("Pippa")
			end
			local legendary = find(list, "Pippa.BubbleBuddy")
			expect(legendary.owned).to.equal(false)
			expect(legendary.dim).to.equal(true)
		end)

		it("orders by rarity after the free item", function()
			local list = VM.items("skin", "Pippa", loadout(), owner())
			local rank = { default = 0, uncommon = 1, rare = 2, epic = 3, legendary = 4, odd = 5 }
			for index = 3, #list do
				expect(rank[list[index - 1].rarity] <= rank[list[index].rarity]).to.equal(true)
			end
		end)

		it("lists shared idles beside the employee's own", function()
			local list = VM.items("idle", "Pippa", loadout(), owner())
			expect(find(list, "Pippa.Classic")).to.be.ok()
			expect(find(list, "SleepySway")).to.be.ok()
			expect(find(list, "Cappy.Classic")).never.to.be.ok()
		end)

		it("flags owned items the player has not seen as New", function()
			local list = VM.items("skin", "Pippa", loadout(), owner({ "Pippa.GloomTouched" }))
			expect(find(list, "Pippa.GloomTouched").new).to.equal(true)
			expect(find(list, "Pippa.Default").new).to.equal(false)
			local seen = VM.items(
				"skin",
				"Pippa",
				loadout({ seen = { ["Pippa.GloomTouched"] = true } }),
				owner({ "Pippa.GloomTouched" })
			)
			expect(find(seen, "Pippa.GloomTouched").new).to.equal(false)
		end)
	end)

	describe("emotes", function()
		local function wheel(a, b, c, d)
			return { a or "", b or "", c or "", d or "" }
		end

		it("lists the employee's emotes, those on the wheel marked with their slot", function()
			local cards = VM.items("emote", "Pippa", loadout(), owner())
			expect(cards[1].id).to.equal("Pippa.Wave")
			expect(cards[1].worn).to.equal(true)
			expect(cards[1].band.text).to.equal("Slot 1")
			local bubbles = find(cards, "Pippa.Bubbles")
			expect(bubbles.worn).to.equal(false)
			expect(bubbles.dim).to.equal(true)
			expect(find(cards, "Cappy.CocoaSip")).never.to.be.ok()
		end)

		it("adds an owned emote to the first free slot, says which slot a worn one is on", function()
			local owns = owner({ "Pippa.Bubbles" })
			local item = CosmeticRegistry.get("Pippa.Bubbles")
			local view = VM.detail(item, loadout(), owns, "Pippa")
			expect(view.action.text).to.equal("Add to wheel")
			expect(view.wheelSlot).to.equal(2)
			local change = VM.change(item, "Pippa", view.wheelSlot)
			expect(change.kind).to.equal("emote")
			expect(change.slot).to.equal(2)
			expect(change.employee).to.equal("Pippa")
			local on = loadout({
				looks = {
					Pippa = {
						skin = "Pippa.Default",
						style = 1,
						idle = "Pippa.Classic",
						wheel = wheel("Pippa.Wave", "", "Pippa.Bubbles"),
					},
				},
			})
			local worn = VM.detail(item, on, owns, "Pippa")
			expect(worn.action.text).to.equal("On slot 3")
			expect(worn.action.kind).to.equal("none")
			expect(#worn.wheel).to.equal(4)
			expect(worn.wheel[1].name).to.equal("Big Wave")
			expect(worn.wheel[3].mine).to.equal(true)
			expect(worn.wheel[2].empty).to.equal(true)
		end)

		it("asks for a slot when the wheel is full, and flags a clip not made yet", function()
			local owns = owner({ "Pippa.Bubbles" })
			local full = loadout({
				looks = {
					Pippa = {
						skin = "Pippa.Default",
						style = 1,
						idle = "Pippa.Classic",
						wheel = wheel("Pippa.Wave", "Pippa.Wave", "Pippa.Wave", "Pippa.Wave"),
					},
				},
			})
			local view = VM.detail(CosmeticRegistry.get("Pippa.Bubbles"), full, owns, "Pippa")
			expect(view.action.text).to.equal("Pick a slot below")
			expect(view.wheelSlot).never.to.be.ok()
			-- Bubble Ride has its clip (AnimationEmoteRegistry); the Big Wave's is not made yet.
			expect(view.comingSoon).to.equal(false)
			expect(VM.detail(CosmeticRegistry.get("Pippa.Wave"), full, owns, "Pippa").comingSoon).to.equal(true)
		end)

		it("has an Emotes page tab", function()
			expect(VM.pageTab("emotes")).to.equal("emotes")
			expect(table.find(VM.PAGE_TABS, "emotes")).to.equal(2)
		end)
	end)

	describe("chat wheel", function()
		it("shows the 4 sticker slots and every pack, owned ones with their stickers to pick", function()
			local owns = owner({ "CozyPack" })
			local view = VM.chat(loadout({ stickers = { "CozyPack.Cocoa", "", "", "" } }), owns)
			expect(#view.slots).to.equal(4)
			expect(view.slots[1].name).to.equal("Cocoa")
			expect(view.slots[2].empty).to.equal(true)
			local cozy = find(view.packs, "CozyPack")
			expect(cozy.owned).to.equal(true)
			expect(#cozy.stickers).to.equal(3)
			expect(cozy.stickers[1].image ~= "").to.equal(true)
			local bubble = find(view.packs, "BubblePack")
			expect(bubble.owned).to.equal(false)
			expect(bubble.price).to.be.ok()
		end)

		it("puts a sticker in the chosen slot, else the first empty one, else slot 1", function()
			local slots = VM.chat(loadout({ stickers = { "CozyPack.Cocoa", "", "", "" } }), owner({ "CozyPack" })).slots
			expect(VM.stickerSlotFor(slots, 4)).to.equal(4)
			expect(VM.stickerSlotFor(slots, nil)).to.equal(2)
			local full = VM.chat(
				loadout({ stickers = { "CozyPack.Cocoa", "CozyPack.Cocoa", "CozyPack.Cocoa", "CozyPack.Cocoa" } }),
				owner({ "CozyPack" })
			).slots
			expect(VM.stickerSlotFor(full, nil)).to.equal(1)
		end)
	end)

	describe("vacuums", function()
		it("lists every vacuum for whoever you are, Standard Issue first and worn, the rest locked", function()
			local cards = VM.items("vacuum", "Cappy", loadout(), owner())
			expect(cards[1].id).to.equal("Vacuum.StandardIssue")
			expect(cards[1].worn).to.equal(true)
			local brass = find(cards, "Vacuum.BrassBellows")
			expect(brass.dim).to.equal(true)
			expect(brass.band.kind).to.equal("gleam")
		end)

		it("wears an owned vacuum for the whole crew", function()
			local owns = owner({ "Vacuum.BrassBellows" })
			local item = CosmeticRegistry.get("Vacuum.BrassBellows")
			local view = VM.detail(item, loadout(), owns)
			expect(view.line).to.equal("Vacuum for every employee")
			expect(view.action.kind).to.equal("wear")
			local change = VM.change(item, "Pippa")
			expect(change.kind).to.equal("vacuum")
			expect(change.id).to.equal("Vacuum.BrassBellows")
			local worn = VM.detail(item, loadout({ vacuum = "Vacuum.BrassBellows" }), owns)
			expect(worn.action.kind).to.equal("none")
			expect(VM.items("vacuum", "Pippa", loadout({ vacuum = "Vacuum.BrassBellows" }), owns)[1].worn).to.equal(
				false
			)
		end)

		it("reads the Vacuums page tab", function()
			expect(VM.pageTab("vacuums")).to.equal("vacuums")
		end)
	end)

	describe("detail", function()
		it(
			"shows the Styles row only for skins with real styles: one chip per style with its name and colours",
			function()
				local bubble = VM.detail(CosmeticRegistry.get("Pippa.BubbleBuddy"), loadout(), owner())
				expect(bubble.styles.visible).to.equal(true)
				expect(bubble.styles.count).to.equal(3)
				expect(#bubble.styles.chips).to.equal(3)
				for _, chip in bubble.styles.chips do
					expect(#chip.name > 0).to.equal(true)
					expect(#chip.swatch).to.equal(2)
				end
				expect(VM.detail(CosmeticRegistry.get("Pippa.Default"), loadout(), owner()).styles.visible).to.equal(
					false
				)
			end
		)

		it(
			"treats each colour style like its own skin: Wear for another style, Wearing only for the worn one",
			function()
				-- Picking a chip only previews; the player presses Wear to change style (owner, 2026-10-29).
				local owns = owner({ "Pippa.BubbleBuddy" })
				local worn = loadout({
					looks = {
						Pippa = {
							skin = "Pippa.BubbleBuddy",
							style = 2,
							idle = CosmeticRegistry.defaultOf("Pippa", "idle").id,
							wheel = { "", "", "", "" },
						},
					},
				})
				local item = CosmeticRegistry.get("Pippa.BubbleBuddy")
				local same = VM.detail(item, worn, owns, "Pippa", 2)
				expect(same.action.text).to.equal("Wearing")
				expect(same.action.enabled).to.equal(false)
				local other = VM.detail(item, worn, owns, "Pippa", 3)
				expect(other.action.text).to.equal("Wear")
				expect(other.action.enabled).to.equal(true)
				expect(other.action.kind).to.equal("wear")
				expect(other.styles.selected).to.equal(3)
				-- No preview picked: the worn style.
				expect(VM.detail(item, worn, owns, "Pippa").action.text).to.equal("Wearing")
			end
		)

		it("shows nothing for a catalogue item with styles but no style art (no row, no note)", function()
			-- A fixture item: the catalogue says 3 styles, but no skin by that name has style art.
			local fake = table.clone(CosmeticRegistry.get("Cappy.PJ"))
			fake.id = "Cappy.NoArtYet"
			local view = VM.detail(fake, loadout(), owner())
			expect(view.styles.visible).to.equal(false)
			expect(view.styles.count).to.equal(0)
			expect(#view.styles.chips).to.equal(0)
		end)

		it("shows PJ Cappy's three styles as chips now its style art exists", function()
			local pj = VM.detail(CosmeticRegistry.get("Cappy.PJ"), loadout(), owner())
			expect(pj.styles.visible).to.equal(true)
			expect(#pj.styles.chips).to.equal(3)
			expect(pj.styles.chips[1].name).to.equal("Blue")
		end)

		it("enables the chips on an owned skin and marks the worn style; a skin you lack still previews", function()
			local owns = owner({ "Pippa.BubbleBuddy" })
			local worn = loadout({
				looks = {
					Pippa = {
						skin = "Pippa.BubbleBuddy",
						style = 2,
						idle = CosmeticRegistry.defaultOf("Pippa", "idle").id,
						wheel = { "", "", "", "" },
					},
				},
			})
			local mine = VM.detail(CosmeticRegistry.get("Pippa.BubbleBuddy"), worn, owns)
			expect(mine.styles.enabled).to.equal(true)
			expect(mine.styles.selected).to.equal(2)
			local theirs = VM.detail(CosmeticRegistry.get("Pippa.BubbleBuddy"), loadout(), owner())
			expect(theirs.styles.enabled).to.equal(false)
			expect(theirs.styles.selected).to.equal(1)
		end)

		it("names the bundle's items under Comes with", function()
			local bubble = VM.detail(CosmeticRegistry.get("Pippa.BubbleBuddy"), loadout(), owner())
			expect(#bubble.comesWith).to.equal(2)
			expect(bubble.comesWith[1].name).to.equal("Bubble Ride")
			expect(bubble.comesWith[1].kind).to.equal("emote")
			expect(bubble.comesWith[2].kind).to.equal("stickerPack")
			expect(#VM.detail(CosmeticRegistry.get("Pippa.Default"), loadout(), owner()).comesWith).to.equal(0)
		end)

		it("quotes the lore only where the item chose it, whatever its rarity", function()
			expect(VM.detail(CosmeticRegistry.get("Pippa.Default"), loadout(), owner()).quote).to.equal(false)
			expect(VM.detail(CosmeticRegistry.get("Pippa.BubbleBuddy"), loadout(), owner()).quote).to.equal(false)
			expect(VM.detail(CosmeticRegistry.get("Pippa.Wave"), loadout(), owner()).quote).to.equal(true)
			expect(VM.detail(CosmeticRegistry.get("Cappy.GhostDebunker"), loadout(), owner()).quote).to.equal(true)
		end)

		it("carries the lore, the rarity word and the action", function()
			local view = VM.detail(CosmeticRegistry.get("Pippa.Gloomkeeper"), loadout(), owner())
			expect(view.name).to.equal("Gloomkeeper")
			expect(view.rarityText).to.equal("EPIC")
			expect(view.lore ~= "").to.equal(true)
			expect(view.action.text).to.equal("Gloom Locker")
		end)

		it("builds the change Wear sends", function()
			local skin = VM.change(CosmeticRegistry.get("Pippa.GloomTouched"), "Pippa")
			expect(skin.kind).to.equal("skin")
			expect(skin.id).to.equal("Pippa.GloomTouched")
			expect(skin.style).to.equal(1)
			-- The chosen colour style rides along.
			expect(VM.change(CosmeticRegistry.get("Pippa.BubbleBuddy"), "Pippa", nil, 3).style).to.equal(3)
			local idle = VM.change(CosmeticRegistry.get("SleepySway"), "Cappy")
			expect(idle.kind).to.equal("idle")
			expect(idle.employee).to.equal("Cappy")
		end)
	end)

	describe("about", function()
		it("lists the five stats in order with an icon and a 1-5 value", function()
			local stats = VM.stats("Pippa")
			expect(#stats).to.equal(5)
			expect(stats[1].label).to.equal("Speed")
			expect(stats[1].icon).to.equal("statSpeed")
			expect(stats[1].value).to.equal(4)
		end)
	end)

	describe("layout", function()
		for _, case in
			{ { size = Vector2.new(1920, 1080), phone = false }, { size = Vector2.new(844, 390), phone = true } }
		do
			it(`fits the screen under the bar ({case.size.X}x{case.size.Y})`, function()
				local layout = VM.layout(case.size, case.phone)
				local content = layout.content
				expect(content.y >= layout.barY + layout.barHeight).to.equal(true)
				expect(content.x + content.width <= case.size.X).to.equal(true)
				expect(content.y + content.height <= case.size.Y).to.equal(true)
				expect(layout.crewCard.Y <= content.height).to.equal(true)
				expect(layout.gridWidth + layout.heroWidth + layout.detailWidth + 2 * layout.gap).to.equal(
					content.width
				)
				expect(layout.detailWidth > 0).to.equal(true)
				-- Two cards side by side in the grid.
				expect(2 * layout.cell.X + layout.gap <= layout.gridWidth).to.equal(true)
				expect(layout.titleX >= 100).to.equal(true)
				expect(layout.textSize >= (if case.phone then 12 else 16)).to.equal(true)
			end)
		end
	end)

	describe("tabs", function()
		it("has Crew, Vacuums and the Chat wheel", function()
			local tabs = VM.tabs()
			expect(#tabs).to.equal(3)
			expect(tabs[1].id).to.equal("crew")
			expect(tabs[2].id).to.equal("vacuums")
			expect(tabs[3].id).to.equal("wheel")
			expect(tabs[3].soon).to.equal(false)
		end)

		it("reads a page tab back from a string, Skins for anything unknown", function()
			expect(VM.pageTab("idles")).to.equal("idles")
			expect(VM.pageTab("about")).to.equal("about")
			expect(VM.pageTab("nope")).to.equal("skins")
		end)

		it("titles the character page tabs Skins, Emotes, Idles and About", function()
			expect(table.concat(VM.PAGE_TABS, ",")).to.equal("skins,emotes,idles,about")
		end)
	end)
end
