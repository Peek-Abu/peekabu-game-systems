local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetic = ReplicatedStorage.Shared.Features.Cosmetic
local CosmeticOutfitRules = require(script.Parent.CosmeticOutfitRules)
local CosmeticRules = require(Cosmetic.Rules.CosmeticRules)
local CosmeticConstants = require(Cosmetic.Data.CosmeticConstants)

local function ownsOf(ids)
	local set = {}
	for _, id in ids do
		set[id] = true
	end
	return function(id)
		return set[id] == true or CosmeticRules.owns({ owned = {} }, id)
	end
end

return function()
	describe("current", function()
		it("is a new player's: Pippa in her defaults, Standard Issue, empty sticker slots", function()
			local outfit = CosmeticOutfitRules.current(CosmeticConstants.defaultLoadout(), ownsOf({}))
			expect(outfit.employee).to.equal("Pippa")
			expect(outfit.look.skin).to.equal("Pippa.Default")
			expect(outfit.look.idle).to.equal("Pippa.Classic")
			expect(outfit.vacuum).to.equal("Vacuum.StandardIssue")
			expect(#outfit.stickers).to.equal(CosmeticConstants.STICKER_SLOTS)
			expect(outfit.stickers[1]).to.equal("")
		end)

		it("reads everything the player wears, with every fallback applied", function()
			local loadout = CosmeticConstants.defaultLoadout()
			loadout.current = "Cappy"
			loadout.vacuum = "Vacuum.BrassBellows"
			loadout.looks.Cappy = { skin = "Cappy.PJ", style = 2, idle = "SleepySway", wheel = { "", "", "", "" } }
			loadout.stickers[2] = "CozyPack.CocoaBreak"
			local owns = ownsOf({ "Cappy", "Cappy.PJ", "SleepySway", "Vacuum.BrassBellows", "CozyPack" })
			local outfit = CosmeticOutfitRules.current(loadout, owns)
			expect(outfit.employee).to.equal("Cappy")
			expect(outfit.look.skin).to.equal("Cappy.PJ")
			expect(outfit.look.style).to.equal(2)
			expect(outfit.vacuum).to.equal("Vacuum.BrassBellows")
			expect(outfit.stickers[2]).to.equal("CozyPack.CocoaBreak")
			-- Not owned: back to the free ones.
			local poor = CosmeticOutfitRules.current(loadout, ownsOf({}))
			expect(poor.employee).to.equal("Pippa")
			expect(poor.vacuum).to.equal("Vacuum.StandardIssue")
		end)
	end)

	describe("tryOn", function()
		it("swaps in one vacuum, skin, idle or employee and leaves the rest", function()
			local base = CosmeticOutfitRules.current(CosmeticConstants.defaultLoadout(), ownsOf({}))
			local vac = CosmeticOutfitRules.tryOn(base, "Vacuum.BrassBellows")
			expect(vac.vacuum).to.equal("Vacuum.BrassBellows")
			expect(vac.look.skin).to.equal("Pippa.Default")
			expect(base.vacuum).to.equal("Vacuum.StandardIssue")
			local skin = CosmeticOutfitRules.tryOn(base, "Cappy.PJ")
			expect(skin.employee).to.equal("Cappy")
			expect(skin.look.skin).to.equal("Cappy.PJ")
			expect(skin.look.idle).to.equal("Cappy.Classic")
			expect(skin.vacuum).to.equal("Vacuum.StandardIssue")
			local idle = CosmeticOutfitRules.tryOn(base, "SleepySway")
			expect(idle.look.idle).to.equal("SleepySway")
			local hire = CosmeticOutfitRules.tryOn(base, "Prickles")
			expect(hire.employee).to.equal("Prickles")
			expect(hire.look.skin).to.equal("Prickles.Default")
		end)

		it("ignores what it can't wear (unknown ids, emotes, stickers)", function()
			local base = CosmeticOutfitRules.current(CosmeticConstants.defaultLoadout(), ownsOf({}))
			expect(CosmeticOutfitRules.tryOn(base, "Nope").vacuum).to.equal(base.vacuum)
			expect(CosmeticOutfitRules.tryOn(base, "CozyPack").look.skin).to.equal(base.look.skin)
		end)
	end)

	describe("keys", function()
		it("names the employee's skin key and the vacuum skin key the art registries use", function()
			local outfit = CosmeticOutfitRules.tryOn(
				CosmeticOutfitRules.current(CosmeticConstants.defaultLoadout(), ownsOf({})),
				"Vacuum.BrassBellows"
			)
			expect(CosmeticOutfitRules.skinKey(outfit)).to.equal("Default")
			expect(CosmeticOutfitRules.vacuumKey(outfit)).to.equal("BrassBellows")
		end)
	end)
end
