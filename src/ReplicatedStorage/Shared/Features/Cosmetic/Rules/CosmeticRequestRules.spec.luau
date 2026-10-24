local CosmeticRequestRules = require(script.Parent.CosmeticRequestRules)
local CosmeticConstants = require(game:GetService("ReplicatedStorage").Shared.Features.Cosmetic.Data.CosmeticConstants)

return function()
	describe("equip", function()
		it("round-trips every kind of change", function()
			local changes = {
				{ kind = "employee", id = "Cappy" },
				{ kind = "skin", id = "Cappy.PJ", style = 2 },
				{ kind = "idle", employee = "Cappy", id = "SleepySway" },
				{ kind = "emote", employee = "Cappy", slot = 3, id = "Cappy.CocoaSip" },
				{ kind = "emote", employee = "Cappy", slot = 3, id = "" },
				{ kind = "sticker", slot = 1, id = "CozyPack.Cocoa" },
				{ kind = "sticker", slot = 1, id = "" },
			}
			for _, change in changes do
				local parsed, reason = CosmeticRequestRules.parseEquip(CosmeticRequestRules.buildEquip(change))
				expect(reason).never.to.be.ok()
				for key, value in change do
					expect(parsed[key]).to.equal(value)
				end
			end
		end)

		it("drops anything malformed", function()
			local bad = {
				"skin",
				42,
				{},
				{ kind = "hat", id = "Cappy.PJ" },
				{ kind = "skin", id = "Cappy.PJ" },
				{ kind = "skin", id = "Cappy.PJ", style = 1.5 },
				{ kind = "skin", id = "", style = 1 },
				{ kind = "employee", id = string.rep("x", 65) },
				{ kind = "idle", id = "SleepySway" },
				{ kind = "emote", employee = "Cappy", slot = "2", id = "Cappy.CocoaSip" },
				{ kind = "emote", slot = 2, id = "Cappy.CocoaSip" },
				{ kind = "sticker", slot = 1 },
				{ kind = "employee", id = 7 },
			}
			for _, payload in bad do
				local parsed, reason = CosmeticRequestRules.parseEquip(payload)
				expect(parsed).never.to.be.ok()
				expect(reason).to.be.a("string")
			end
		end)
	end)

	describe("seen", function()
		it("round-trips a short id list and drops anything else", function()
			local ids =
				CosmeticRequestRules.parseSeen(CosmeticRequestRules.buildSeen({ "Pippa.GloomTouched", "Cappy" }))
			expect(table.concat(ids, ",")).to.equal("Pippa.GloomTouched,Cappy")
			local tooMany = {}
			for index = 1, CosmeticConstants.MAX_SEEN + 1 do
				tooMany[index] = "Pippa"
			end
			for _, payload in
				{
					nil,
					"x",
					{},
					{ ids = {} },
					{ ids = { "" } },
					{ ids = { 3 } },
					{ ids = tooMany },
					{ ids = { a = "Pippa" } },
				}
			do
				local parsed, reason = CosmeticRequestRules.parseSeen(payload)
				expect(parsed).never.to.be.ok()
				expect(reason).to.be.a("string")
			end
		end)
	end)

	describe("pick", function()
		it("round-trips an employee and drops anything else", function()
			expect(CosmeticRequestRules.parsePick(CosmeticRequestRules.buildPick("Prickles"))).to.equal("Prickles")
			expect(CosmeticRequestRules.parsePick({ employee = "" })).never.to.be.ok()
			expect(CosmeticRequestRules.parsePick({ employee = 3 })).never.to.be.ok()
			expect(CosmeticRequestRules.parsePick("Cappy")).never.to.be.ok()
		end)
	end)
end
