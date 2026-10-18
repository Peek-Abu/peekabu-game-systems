local VM = require(script.Parent.DepotHubViewModel)
local RankFormulas = require(game:GetService("ReplicatedStorage").Shared.Features.Rank.Utils.RankFormulas)
return function()
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

		it("gives each guide and locker section its render, one per section", function()
			for _, page in { "guide", "gear" } do
				expect(#VM.sectionIcons(page)).to.equal(#VM.copy(page).sections)
			end
			expect(VM.sectionIcons("guide")[1]).to.equal("truck")
			expect(VM.sectionIcons("gear")[1]).to.equal("vacuum")
		end)

		it("titles the hub pages for the V1 menus", function()
			expect(VM.pageTitle("guide")).to.equal("GUIDE")
			expect(VM.pageTitle("gear")).to.equal("LOCKER")
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
			for _, page in { "guide", "gear" } do
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
			expect(string.find(VM.copy("gear").sections[1].body, "press 1", 1, true)).to.equal(nil)
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
		it("lists only registered percentage settings, so each gets a slider", function()
			local SettingRegistry =
				require(game:GetService("ReplicatedStorage").Shared.Features.Setting.Data.SettingRegistry)
			for _, setting in VM.SETTINGS do
				local def = SettingRegistry.get(setting.id)
				expect(def).to.be.ok()
				expect(def.kind).to.equal("number")
			end
		end)
	end)
end
