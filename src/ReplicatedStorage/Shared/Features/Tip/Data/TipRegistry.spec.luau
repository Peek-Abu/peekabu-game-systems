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
