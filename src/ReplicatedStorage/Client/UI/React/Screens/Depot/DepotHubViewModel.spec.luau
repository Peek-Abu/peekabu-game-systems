local VM = require(script.Parent.DepotHubViewModel)
local RankFormulas = require(game:GetService("ReplicatedStorage").Shared.Features.Rank.Utils.RankFormulas)
local function monsterNeutral(text)
	for _, word in { "manager", "harlow", "bramble", "boss" } do
		expect(string.find(string.lower(text), word, 1, true)).to.equal(nil)
	end
end

return function()
	describe("guide words", function()
		it("talks about monsters, not one map's monster, in the field guide", function()
			for _, section in VM.copy("guide").sections do
				monsterNeutral(section.title)
				monsterNeutral(section.body)
			end
			local sections = VM.copy("guide").sections
			expect(string.find(sections[3].body, "Monsters hear vacuums and dropped cargo.", 1, true)).to.equal(1)
			expect(string.find(sections[4].body, "and faster monsters.", 1, true) ~= nil).to.equal(true)
		end)

		it("draws the noise section with the Quiet render, not Harlow's face", function()
			expect(VM.sectionIcons("guide")[3]).to.equal("statQuiet")
			for _, icon in VM.sectionIcons("guide") do
				expect(icon).never.to.equal("managerHunt")
				expect(icon).never.to.equal("managerCalm")
			end
		end)
	end)

	describe("hub HUD (V1)", function()
		it("names the profile card in caps with the level, the rank and the XP to the next level", function()
			local progress = RankFormulas.progress(45)
			local card = VM.profile("Pippa", { xp = 45, prevXp = 45 })
			expect(card.name).to.equal("PIPPA")
			expect(card.level).to.equal(tostring(progress.level.level))
			expect(card.rank).to.equal(progress.level.name)
			expect(card.fill).to.equal(progress.fill)
			if progress.next ~= nil then
				expect(card.xpText).to.equal(`45 / {progress.next.xp} XP`)
			end
		end)

		it("shows the first rung until the server publishes the rank", function()
			local card = VM.profile("Mo", nil)
			expect(card.level).to.equal(tostring(RankFormulas.progress(0).level.level))
			expect(card.fill).to.equal(RankFormulas.progress(0).fill)
		end)

		it("keeps a long name to one line's worth", function()
			expect(#VM.profile("Abcdefghijklmnopqrstuvwxyz", nil).name <= 14).to.equal(true)
		end)

		it("lights the daily gift when today's reward is claimable, else counts down to the next day", function()
			local day = 20000
			local now = day * 86400 + 3600
			local ready = VM.gift({ lastDay = day - 1, streak = 3 }, now)
			expect(ready.ready).to.equal(true)
			expect(ready.text).to.equal("OPEN!")
			local waiting = VM.gift({ lastDay = day, streak = 3 }, now)
			expect(waiting.ready).to.equal(false)
			expect(waiting.text).to.equal("23:00:00")
		end)

		it("gives each guide section its render, one per section", function()
			expect(#VM.sectionIcons("guide")).to.equal(#VM.copy("guide").sections)
			expect(VM.sectionIcons("guide")[1]).to.equal("truck")
		end)

		it("has no Company Equipment page any more (the Inventory's Vacuums tab replaced it)", function()
			expect(table.find(VM.PAGES, "gear")).never.to.be.ok()
		end)

		it("titles the hub pages for the V1 menus", function()
			expect(VM.pageTitle("guide")).to.equal("GUIDE")
			expect(VM.pageTitle("settings")).to.equal("SETTINGS")
		end)

		it("names tonight's building from the board's contract", function()
			local card = VM.tonight("harlow-finch-2")
			expect(card.title).to.equal("HARLOW & FINCH")
			expect(card.site).to.equal("4th floor offices")
			expect(VM.tonight(nil).title).to.equal("HARLOW & FINCH")
		end)
	end)

	describe("hub", function()
		it("fits the guide header and scroll body in portrait and short landscape", function()
			for _, viewport in { Vector2.new(390, 844), Vector2.new(844, 390), Vector2.new(1366, 768) } do
				local layout = VM.panelLayout(viewport, viewport.X < 900)
				expect(layout.width <= viewport.X - 32).to.equal(true)
				expect(layout.height <= viewport.Y - 32).to.equal(true)
				expect(layout.titleWidth >= 140).to.equal(true)
				expect(layout.bodyWidth > 250).to.equal(true)
				expect(layout.height - layout.headerHeight - 20 >= 120).to.equal(true)
			end
		end)
		it("stacks narrow settings while keeping wide headers compact", function()
			expect(VM.panelLayout(Vector2.new(390, 844), true).compact).to.equal(true)
			expect(VM.panelLayout(Vector2.new(844, 390), true).compact).to.equal(false)
		end)
		it("teaches that Gloom counts on the spot, with no dust bag to carry and no empty action", function()
			for _, page in { "guide" } do
				local copy = VM.copy(page)
				local text = ""
				for _, section in copy.sections do
					text ..= string.lower(section.title .. " " .. section.body) .. " "
				end
				expect(string.find(text, "gloom", 1, true) ~= nil).to.equal(true)
				expect(string.find(text, "bank dust bags", 1, true)).to.equal(nil)
				expect(string.find(text, "produce dust bags", 1, true)).to.equal(nil)
				expect(string.find(text, "empty your vacuum", 1, true)).to.equal(nil)
				expect(string.find(text, "stops collecting", 1, true)).to.equal(nil)
				expect(string.find(text, "empty at the truck", 1, true)).to.equal(nil)
			end
		end)
		it("includes a supplied live control legend without assuming a key", function()
			expect(
				string.find(VM.copy("guide", "Hold R2 to clean.").sections[2].body, "Hold R2 to clean.", 1, true) ~= nil
			).to.equal(true)
		end)
		it("does not put shortcuts over running or results crew", function()
			expect(VM.visible({ phase = "running", crew = { 1 } }, 1)).to.equal(false)
			expect(VM.visible({ phase = "results", crew = { 1 } }, 1)).to.equal(false)
			expect(VM.visible({ phase = "running", crew = { 2 } }, 1)).to.equal(true)
			expect(VM.visible(nil, 1)).to.equal(true)
		end)
		it("keeps touch targets usable on short landscape screens", function()
			local size = VM.cardSize(true)
			expect(size.X >= 48).to.equal(true)
			expect(size.Y >= 48).to.equal(true)
		end)
		it("lists the trimmed settings: music & ambience, sound effects, camera shake, brightness, tips", function()
			local labels = {}
			for _, setting in VM.SETTINGS do
				table.insert(labels, setting.label)
			end
			expect(#labels).to.equal(5)
			expect(labels[1]).to.equal("Music & ambience")
			expect(labels[2]).to.equal("Sound effects")
			expect(labels[3]).to.equal("Camera shake")
			expect(labels[4]).to.equal("Brightness")
			expect(labels[5]).to.equal("Tips")
			expect(VM.SETTINGS[5].id).to.equal("tips")
		end)
		it("words a switch ON or OFF", function()
			expect(VM.switchText(true)).to.equal("ON")
			expect(VM.switchText(false)).to.equal("OFF")
		end)
		it("stacks the restore button and the note under the last settings row", function()
			expect(VM.settingsFooterY(false)).to.equal(#VM.SETTINGS * 68 + 12)
			expect(VM.settingsFooterY(true)).to.equal(#VM.SETTINGS * 88 + 12)
		end)
		it("lists only registered percentage settings and switches, so each gets a slider or a toggle", function()
			local SettingRegistry =
				require(game:GetService("ReplicatedStorage").Shared.Features.Setting.Data.SettingRegistry)
			for _, setting in VM.SETTINGS do
				local def = SettingRegistry.get(setting.id)
				expect(def).to.be.ok()
				expect(def.kind == "number" or def.kind == "boolean").to.equal(true)
			end
		end)
	end)

	describe("clipboardShown", function()
		it("shows the CLIPBOARD tile only once training is done", function()
			expect(VM.clipboardShown(false)).to.equal(true)
			expect(VM.clipboardShown(true)).to.equal(false)
		end)
	end)
	describe("the Find a truck tab (owner 11-11)", function()
		it("shows only off a truck and never over a prompt", function()
			expect(VM.findTruck(false, false)).to.equal(true)
			expect(VM.findTruck(true, false)).to.equal(false)
			expect(VM.findTruck(false, true)).to.equal(false)
			expect(VM.findTruck(true, true)).to.equal(false)
		end)

		it("says it for young players", function()
			expect(VM.FIND_TRUCK_TEXT).to.equal("Find a truck!")
		end)
	end)
end
