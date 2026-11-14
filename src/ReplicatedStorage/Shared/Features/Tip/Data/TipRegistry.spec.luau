local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TipRegistry = require(ReplicatedStorage.Shared.Features.Tip.Data.TipRegistry)
local SettingRegistry = require(ReplicatedStorage.Shared.Features.Setting.Data.SettingRegistry)

return function()
	it("has a one-line tip for the first catch, the overtime offer and the first ability use", function()
		for _, id in { "firstCatch", "overtime", "firstAbility" } do
			local text = TipRegistry.text(id)
			expect(type(text)).to.equal("string")
			expect(#text > 0).to.equal(true)
			expect(#text <= TipRegistry.MAX_LENGTH).to.equal(true)
			expect(string.find(text, "\n", 1, true)).to.equal(nil)
		end
	end)

	it("has Bramble's own first-catch and overtime tips, which never name Mr. Harlow", function()
		expect(TipRegistry.text("firstCatchBramble")).to.equal(
			"Bramble got you! The old school owl wants everyone to stay after school."
		)
		for _, id in { "firstCatchBramble", "overtimeBramble" } do
			local text = TipRegistry.text(id)
			expect(type(text)).to.equal("string")
			expect(#text <= TipRegistry.MAX_LENGTH).to.equal(true)
			expect(string.find(text, "Harlow", 1, true)).to.equal(nil)
			expect(string.find(text, "Bramble", 1, true) ~= nil).to.equal(true)
		end
	end)

	it("tells a first catch only lore, never how a monster works or how to get away (owner Q1, 11-14)", function()
		expect(TipRegistry.text("firstCatch")).to.equal(
			"Mr. Harlow got you! He never went home, and he still thinks he's the boss."
		)
		for _, id in { "firstCatch", "firstCatchBramble" } do
			local text = string.lower(TipRegistry.text(id))
			for _, how in { "hide", "watch", "look at", "run", "quiet", "desk", "freeze", "keep" } do
				expect(string.find(text, how, 1, true)).to.equal(nil)
			end
		end
	end)

	it("keeps Mr. Harlow's overtime tip as it was", function()
		expect(TipRegistry.text("overtime")).to.equal(
			"Overtime! Sign the sheet in the truck: treasures pay more, but Mr. Harlow gets faster."
		)
	end)

	it("knows no other tip", function()
		expect(TipRegistry.text("nope")).to.equal(nil)
		expect(TipRegistry.has("nope")).to.equal(false)
		expect(TipRegistry.has("firstCatch")).to.equal(true)
	end)

	it("registers the Tips setting, a switch that starts on", function()
		local def = SettingRegistry.get(TipRegistry.SETTING)
		expect(def).to.be.ok()
		expect(def.kind).to.equal("boolean")
		expect(def.default).to.equal(true)
	end)

	it("shows each tip long enough to read", function()
		expect(TipRegistry.SECONDS >= 5).to.equal(true)
	end)
end
