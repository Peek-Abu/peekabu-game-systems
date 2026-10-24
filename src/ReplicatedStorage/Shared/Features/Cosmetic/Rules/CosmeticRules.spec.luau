local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetic = ReplicatedStorage.Shared.Features.Cosmetic
local CosmeticRules = require(script.Parent.CosmeticRules)
local CosmeticConstants = require(Cosmetic.Data.CosmeticConstants)

-- An `owns` that answers from a set (plus the free defaults, as the real one does).
local function ownsOf(ids)
	local set = {}
	for _, id in ids do
		set[id] = true
	end
	return function(id)
		return set[id] == true or CosmeticRules.owns({ owned = {} }, id)
	end
end

local function wheel(a, b, c, d)
	return { a or "", b or "", c or "", d or "" }
end

return function()
	describe("owns", function()
		it("owns free defaults, owned items and stickers through their pack; never unknown ids", function()
			local none = { owned = {} }
			expect(CosmeticRules.owns(none, "Pippa")).to.equal(true)
			expect(CosmeticRules.owns(none, "Cappy.Default")).to.equal(true)
			expect(CosmeticRules.owns(none, "Cappy")).to.equal(false)
			expect(CosmeticRules.owns(none, "Nope")).to.equal(false)
			local some = { owned = { employee = { Cappy = true }, stickerPack = { CozyPack = true } } }
			expect(CosmeticRules.owns(some, "Cappy")).to.equal(true)
			expect(CosmeticRules.owns(some, "CozyPack.Cocoa")).to.equal(true)
			expect(CosmeticRules.owns(some, "BubblePack.Ducky")).to.equal(false)
		end)
	end)

	describe("lookFor", function()
		it("gives the employee's defaults when there is no saved look", function()
			local look = CosmeticRules.lookFor(CosmeticConstants.defaultLoadout(), "Cappy", ownsOf({}))
			expect(look.skin).to.equal("Cappy.Default")
			expect(look.style).to.equal(1)
			expect(look.idle).to.equal("Cappy.Classic")
			expect(look.wheel[1]).to.equal("Cappy.FistBump")
			expect(#look.wheel).to.equal(CosmeticConstants.WHEEL_SLOTS)
		end)

		it("keeps an owned look and clamps nothing that is in range", function()
			local loadout = CosmeticConstants.defaultLoadout()
			loadout.looks.Cappy = { skin = "Cappy.PJ", style = 3, idle = "SleepySway", wheel = wheel("Cappy.CocoaSip") }
			local look = CosmeticRules.lookFor(loadout, "Cappy", ownsOf({ "Cappy.PJ", "SleepySway", "Cappy.CocoaSip" }))
			expect(look.skin).to.equal("Cappy.PJ")
			expect(look.style).to.equal(3)
			expect(look.idle).to.equal("SleepySway")
			expect(look.wheel[1]).to.equal("Cappy.CocoaSip")
		end)

		it("falls back on a retired, unowned or other employee's item, and a style out of range", function()
			local loadout = CosmeticConstants.defaultLoadout()
			loadout.looks.Cappy = {
				skin = "Cappy.Retired",
				style = 2,
				idle = "Pippa.Classic",
				wheel = wheel("Pippa.Wave", "Cappy.CocoaSip"),
			}
			local look = CosmeticRules.lookFor(loadout, "Cappy", ownsOf({}))
			expect(look.skin).to.equal("Cappy.Default")
			expect(look.style).to.equal(1)
			expect(look.idle).to.equal("Cappy.Classic")
			expect(look.wheel[1]).to.equal("")
			expect(look.wheel[2]).to.equal("")
			loadout.looks.Pippa = { skin = "Cappy.PJ", style = 1, idle = "Pippa.Classic", wheel = wheel() }
			expect(CosmeticRules.lookFor(loadout, "Pippa", ownsOf({ "Cappy.PJ" })).skin).to.equal("Pippa.Default")
			loadout.looks.Prickles =
				{ skin = "Prickles.Sheriff", style = 7, idle = "Prickles.Classic", wheel = wheel() }
			expect(CosmeticRules.lookFor(loadout, "Prickles", ownsOf({ "Prickles.Sheriff" })).style).to.equal(1)
			loadout.looks.Prickles.style = 0
			expect(CosmeticRules.lookFor(loadout, "Prickles", ownsOf({ "Prickles.Sheriff" })).style).to.equal(1)
		end)

		it("returns a fresh table each call", function()
			local loadout = CosmeticConstants.defaultLoadout()
			local a = CosmeticRules.lookFor(loadout, "Pippa", ownsOf({}))
			local b = CosmeticRules.lookFor(loadout, "Pippa", ownsOf({}))
			expect(a).never.to.equal(b)
			expect(a.wheel).never.to.equal(b.wheel)
		end)
	end)

	describe("currentEmployee", function()
		it("falls back to Pippa when the saved employee is not owned", function()
			local loadout = CosmeticConstants.defaultLoadout()
			loadout.current = "Cappy"
			expect(CosmeticRules.currentEmployee(loadout, ownsOf({}))).to.equal("Pippa")
			expect(CosmeticRules.currentEmployee(loadout, ownsOf({ "Cappy" }))).to.equal("Cappy")
			loadout.current = "Retired"
			expect(CosmeticRules.currentEmployee(loadout, ownsOf({ "Retired" }))).to.equal("Pippa")
		end)
	end)

	describe("checkEquip / applyEquip", function()
		local owns = ownsOf({ "Cappy", "Cappy.PJ", "Cappy.CocoaSip", "SleepySway", "CozyPack" })

		it("switches to an owned employee only", function()
			local loadout = CosmeticConstants.defaultLoadout()
			expect(CosmeticRules.checkEquip(loadout, { kind = "employee", id = "Prickles" }, owns)).to.equal(false)
			expect(CosmeticRules.checkEquip(loadout, { kind = "employee", id = "Pippa" }, owns)).to.equal(false)
			expect(CosmeticRules.checkEquip(loadout, { kind = "employee", id = "Cappy.PJ" }, owns)).to.equal(false)
			expect(CosmeticRules.checkEquip(loadout, { kind = "employee", id = "Cappy" }, owns)).to.equal(true)
			expect(CosmeticRules.applyEquip(loadout, { kind = "employee", id = "Cappy" }, owns)).to.equal(true)
			expect(loadout.current).to.equal("Cappy")
		end)

		it("wears an owned skin with a style in range, creating the employee's look", function()
			local loadout = CosmeticConstants.defaultLoadout()
			local _, reason = CosmeticRules.checkEquip(loadout, { kind = "skin", id = "Cappy.PJ", style = 4 }, owns)
			expect(reason).to.equal("bad style")
			expect(CosmeticRules.checkEquip(loadout, { kind = "skin", id = "Cappy.PJ", style = 0 }, owns)).to.equal(
				false
			)
			expect(CosmeticRules.checkEquip(loadout, { kind = "skin", id = "Cappy.PJ", style = 1.5 }, owns)).to.equal(
				false
			)
			local _, notOwned =
				CosmeticRules.checkEquip(loadout, { kind = "skin", id = "Cappy.GhostDebunker", style = 1 }, owns)
			expect(notOwned).to.equal("not owned")
			expect(CosmeticRules.checkEquip(loadout, { kind = "skin", id = "SleepySway", style = 1 }, owns)).to.equal(
				false
			)
			expect(CosmeticRules.checkEquip(loadout, { kind = "skin", id = "Cappy.PJ", style = 2 }, owns)).to.equal(
				true
			)
			CosmeticRules.applyEquip(loadout, { kind = "skin", id = "Cappy.PJ", style = 2 }, owns)
			expect(loadout.looks.Cappy.skin).to.equal("Cappy.PJ")
			expect(loadout.looks.Cappy.style).to.equal(2)
			expect(loadout.looks.Cappy.idle).to.equal("Cappy.Classic")
			local _, same = CosmeticRules.checkEquip(loadout, { kind = "skin", id = "Cappy.PJ", style = 2 }, owns)
			expect(same).to.equal("no change")
		end)

		it("puts an idle on its own employee or a shared one, never another employee's", function()
			local loadout = CosmeticConstants.defaultLoadout()
			local _, wrong =
				CosmeticRules.checkEquip(loadout, { kind = "idle", employee = "Cappy", id = "Pippa.Classic" }, owns)
			expect(wrong).to.equal("wrong employee")
			expect(CosmeticRules.checkEquip(loadout, { kind = "idle", employee = "Pippa", id = "SleepySway" }, owns)).to.equal(
				true
			)
			expect(CosmeticRules.checkEquip(loadout, { kind = "idle", employee = "Nobody", id = "SleepySway" }, owns)).to.equal(
				false
			)
		end)

		it("fills, moves and clears emote-wheel slots", function()
			local loadout = CosmeticConstants.defaultLoadout()
			for _, slot in { 0, 5, 1.5, -1 } do
				local _, reason = CosmeticRules.checkEquip(
					loadout,
					{ kind = "emote", employee = "Cappy", slot = slot, id = "Cappy.CocoaSip" },
					owns
				)
				expect(reason).to.equal("bad slot")
			end
			local _, notOwned = CosmeticRules.checkEquip(
				loadout,
				{ kind = "emote", employee = "Pippa", slot = 2, id = "Pippa.Bubbles" },
				owns
			)
			expect(notOwned).to.equal("not owned")
			local _, wrong = CosmeticRules.checkEquip(
				loadout,
				{ kind = "emote", employee = "Pippa", slot = 2, id = "Cappy.CocoaSip" },
				owns
			)
			expect(wrong).to.equal("wrong employee")
			CosmeticRules.applyEquip(
				loadout,
				{ kind = "emote", employee = "Cappy", slot = 2, id = "Cappy.CocoaSip" },
				owns
			)
			expect(loadout.looks.Cappy.wheel[1]).to.equal("Cappy.FistBump")
			expect(loadout.looks.Cappy.wheel[2]).to.equal("Cappy.CocoaSip")
			CosmeticRules.applyEquip(
				loadout,
				{ kind = "emote", employee = "Cappy", slot = 3, id = "Cappy.CocoaSip" },
				owns
			)
			expect(loadout.looks.Cappy.wheel[2]).to.equal("")
			expect(loadout.looks.Cappy.wheel[3]).to.equal("Cappy.CocoaSip")
			expect(CosmeticRules.checkEquip(loadout, { kind = "emote", employee = "Cappy", slot = 3, id = "" }, owns)).to.equal(
				true
			)
			local _, empty =
				CosmeticRules.checkEquip(loadout, { kind = "emote", employee = "Cappy", slot = 4, id = "" }, owns)
			expect(empty).to.equal("no change")
		end)

		it("puts stickers from owned packs in the 4 sticker slots", function()
			local loadout = CosmeticConstants.defaultLoadout()
			local _, notOwned =
				CosmeticRules.checkEquip(loadout, { kind = "sticker", slot = 1, id = "BubblePack.Ducky" }, owns)
			expect(notOwned).to.equal("not owned")
			local _, kind = CosmeticRules.checkEquip(loadout, { kind = "sticker", slot = 1, id = "CozyPack" }, owns)
			expect(kind).to.equal("wrong kind")
			expect(CosmeticRules.checkEquip(loadout, { kind = "sticker", slot = 5, id = "CozyPack.Cocoa" }, owns)).to.equal(
				false
			)
			CosmeticRules.applyEquip(loadout, { kind = "sticker", slot = 2, id = "CozyPack.Cocoa" }, owns)
			expect(loadout.stickers[2]).to.equal("CozyPack.Cocoa")
		end)

		it("refuses unknown ids", function()
			local _, reason = CosmeticRules.checkEquip(
				CosmeticConstants.defaultLoadout(),
				{ kind = "skin", id = "Nope", style = 1 },
				owns
			)
			expect(reason).to.equal("unknown item")
		end)
	end)

	describe("unseen", function()
		it("keeps only owned, registered, non-free items not seen yet, once each", function()
			local loadout = CosmeticConstants.defaultLoadout()
			loadout.seen["Pippa.Gloomkeeper"] = true
			local owns = ownsOf({ "Pippa.GloomTouched", "Pippa.Gloomkeeper", "Cappy" })
			local ids = CosmeticRules.unseen(loadout, {
				"Pippa.GloomTouched",
				"Pippa.GloomTouched",
				"Pippa.Gloomkeeper",
				"Pippa.Default",
				"Pippa.BubbleBuddy",
				"Nope",
				"Cappy",
			}, owns)
			expect(table.concat(ids, ",")).to.equal("Pippa.GloomTouched,Cappy")
		end)
	end)

	describe("validateLoadout", function()
		it("accepts the default loadout and unknown (retired) ids", function()
			expect(CosmeticRules.validateLoadout(CosmeticConstants.defaultLoadout())).to.equal(true)
			local loadout = CosmeticConstants.defaultLoadout()
			loadout.looks.Cappy = { skin = "Cappy.Retired", style = 1, idle = "Gone", wheel = wheel() }
			expect(CosmeticRules.validateLoadout(loadout)).to.equal(true)
		end)

		it("rejects bad structure", function()
			local function bad(edit)
				local loadout = CosmeticConstants.defaultLoadout()
				loadout.looks.Cappy = { skin = "Cappy.PJ", style = 1, idle = "Cappy.Classic", wheel = wheel() }
				edit(loadout)
				local ok = CosmeticRules.validateLoadout(loadout)
				expect(ok).to.equal(false)
			end
			bad(function(l)
				l.looks.Cappy.wheel = { "", "", "" }
			end)
			bad(function(l)
				l.looks.Cappy.style = 1.5
			end)
			bad(function(l)
				l.looks.Cappy.style = 0
			end)
			bad(function(l)
				l.picked = "yes"
			end)
			bad(function(l)
				l.current = ""
			end)
			bad(function(l)
				l.seen.Cappy = false
			end)
			bad(function(l)
				l.stickers = { "", "" }
			end)
			bad(function(l)
				l.looks.Cappy.skin = 3
			end)
		end)
	end)
end
