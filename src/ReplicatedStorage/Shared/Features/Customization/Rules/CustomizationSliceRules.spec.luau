--!strict
--[=[
	Unit tests for CustomizationSliceRules — the pure data-layer invariants for the `appearance`
	(per-slot) and `entitlements` (account) slices. Covers registered-id checks, the Color tagged
	union (dye vs free RGB + the per-channel allowFreeRgb policy), accessory slot/shape limits, and
	the entitlements "only lockable ids are stored" rule.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CustomizationSliceRules = require(ReplicatedStorage.Shared.Features.Customization.Rules.CustomizationSliceRules)
local CustomizationCosmeticRegistry =
	require(ReplicatedStorage.Shared.Features.Customization.Data.CustomizationCosmeticRegistry)

return function()
	local function emptyAppearance()
		return { cosmetics = {}, accessories = {}, body = {}, headType = "Uncovered", surfaces = {} }
	end

	local function rgb(r, g, b)
		return { source = "rgb", r = r, g = g, b = b }
	end

	describe("validateAppearance — shape", function()
		it("accepts a fully empty appearance", function()
			local ok = CustomizationSliceRules.validateAppearance(emptyAppearance())
			expect(ok).to.equal(true)
		end)

		it("rejects a non-table appearance", function()
			local ok, reason = CustomizationSliceRules.validateAppearance(42)
			expect(ok).to.equal(false)
			expect(type(reason)).to.equal("string")
		end)

		-- headType is REQUIRED, unlike every other channel (absent = "none"): a character always has a
		-- head, so an absent value would leave the facemask in an undefined state.
		it("rejects a missing headType", function()
			local appearance = emptyAppearance()
			appearance.headType = nil
			local ok, reason = CustomizationSliceRules.validateAppearance(appearance)
			expect(ok).to.equal(false)
			expect(string.find(reason, "headType") ~= nil).to.equal(true)
		end)

		it("rejects an unregistered headType", function()
			local appearance = emptyAppearance()
			appearance.headType = "Partial"
			expect(CustomizationSliceRules.validateAppearance(appearance)).to.equal(false)
		end)

		it("accepts every registered headType", function()
			for _, headType in CustomizationCosmeticRegistry.headTypes() do
				local appearance = emptyAppearance()
				appearance.headType = headType
				expect(CustomizationSliceRules.validateAppearance(appearance)).to.equal(true)
			end
		end)

		-- The CROSS-FIELD rule. Driven straight through validateAppearance (not a service method),
		-- because that is what a raw `appearanceOp` does — the whole point of enforcing this in the
		-- data layer rather than the service is that no write path can dodge it.
		it("rejects a Covered-only hair while the head type is Uncovered", function()
			local appearance = emptyAppearance()
			appearance.headType = "Uncovered"
			appearance.cosmetics.hair = { id = "Hair2", colors = {} }
			local ok, reason = CustomizationSliceRules.validateAppearance(appearance)
			expect(ok).to.equal(false)
			expect(string.find(reason, "Hair2", 1, true) ~= nil).to.equal(true)
		end)

		it("rejects an Uncovered-only hair while the head type is Covered", function()
			local appearance = emptyAppearance()
			appearance.headType = "Covered"
			appearance.cosmetics.hair = { id = "Hair10", colors = {} }
			expect(CustomizationSliceRules.validateAppearance(appearance)).to.equal(false)
		end)

		it("accepts each hair with its own head type", function()
			local covered = emptyAppearance()
			covered.headType = "Covered"
			covered.cosmetics.hair = { id = "Hair2", colors = {} }
			expect(CustomizationSliceRules.validateAppearance(covered)).to.equal(true)

			local uncovered = emptyAppearance()
			uncovered.headType = "Uncovered"
			uncovered.cosmetics.hair = { id = "Hair10", colors = {} }
			expect(CustomizationSliceRules.validateAppearance(uncovered)).to.equal(true)
		end)

		it("rejects missing sub-tables", function()
			expect(CustomizationSliceRules.validateAppearance({ accessories = {}, body = {} })).to.equal(false)
			expect(CustomizationSliceRules.validateAppearance({ cosmetics = {}, body = {} })).to.equal(false)
			expect(CustomizationSliceRules.validateAppearance({ cosmetics = {}, accessories = {} })).to.equal(false)
		end)
	end)

	describe("validateAppearance — cosmetics", function()
		it("accepts a registered cosmetic with the right color count", function()
			local appearance = emptyAppearance()
			-- Eyebrows, not hair: hair is head-type partitioned, and this case is about color count.
			appearance.cosmetics.eyebrows = { id = "Eyebrows2", colors = { rgb(10, 20, 30) } }
			expect(CustomizationSliceRules.validateAppearance(appearance)).to.equal(true)
		end)

		-- LENIENCY, matching the affix precedent (PR #8). The validator runs against the WHOLE resulting
		-- appearance on every write, so refusing a retired id would freeze the entire slice: a player
		-- holding a since-retired hat could not change their head type, colours, or anything else until
		-- it was cleared. The plan-builder already skips retired ids so the character still renders, and
		-- services pre-check registration on equip, so nothing can newly EQUIP one.
		it("TOLERATES a retired cosmetic id so it cannot freeze the slice", function()
			local appearance = emptyAppearance()
			appearance.cosmetics.hair = { id = "HairRetired", colors = {} }
			expect(CustomizationSliceRules.validateAppearance(appearance)).to.equal(true)
		end)

		-- Leniency covers the ID, never the SHAPE. A malformed colors table is corruption whatever the
		-- id says, and callers are entitled to treat it as a table once it has validated.
		it("still rejects a malformed colors table on a RETIRED id", function()
			local appearance = emptyAppearance()
			appearance.cosmetics.hair = { id = "HairRetired", colors = "not a table" }
			expect(CustomizationSliceRules.validateAppearance(appearance)).to.equal(false)
		end)

		it("still lets an unrelated write through while a retired id is stored", function()
			local appearance = emptyAppearance()
			appearance.accessories = { { id = "RetiredHat", colors = {} } }
			appearance.body.color1 = { source = "rgb", r = 10, g = 20, b = 30 }
			expect(CustomizationSliceRules.validateAppearance(appearance)).to.equal(true)
		end)

		-- NOTE: there is deliberately no "rejects an unregistered cosmetic id" case any more. It was
		-- replaced by the leniency tests above: refusing a retired id here froze the whole slice, and
		-- the equip-time registry pre-check is what actually stops a bad id being chosen.

		-- A RETIRED CATEGORY is tolerated for the same reason a retired id is: dropping a category from
		-- the registry would otherwise freeze the slice of every player still storing one, and the
		-- plan-builder already skips it so nothing renders. Structural faults (a non-table selection, a
		-- malformed colour) are still rejected — this leniency is about ids and categories that USED to
		-- exist, not about accepting garbage.
		it("tolerates an unregistered category rather than freezing the slice", function()
			local appearance = emptyAppearance()
			appearance.cosmetics.antennae = { id = "Hair2", colors = {} }
			expect(CustomizationSliceRules.validateAppearance(appearance)).to.equal(true)
		end)

		it("rejects the accessory category in the cosmetics map (accessories have their own slots)", function()
			local appearance = emptyAppearance()
			appearance.cosmetics.accessory = { id = "WizardHat", colors = {} }
			expect(CustomizationSliceRules.validateAppearance(appearance)).to.equal(false)
		end)

		it("rejects MORE colors than the cosmetic has channels", function()
			local appearance = emptyAppearance()
			appearance.cosmetics.hair = { id = "Hair2", colors = { rgb(1, 2, 3), rgb(4, 5, 6) } }
			expect(CustomizationSliceRules.validateAppearance(appearance)).to.equal(false)
		end)

		it("accepts FEWER colors than channels (unset channels keep the model's authored colors)", function()
			local appearance = emptyAppearance()
			appearance.cosmetics.eyebrows = { id = "Eyebrows2", colors = {} }
			expect(CustomizationSliceRules.validateAppearance(appearance)).to.equal(true)
		end)
	end)

	describe("validateAppearance — surfaces", function()
		it("accepts a pattern and a texture on a registered channel", function()
			local appearance = emptyAppearance()
			appearance.surfaces.clothing1 = { pattern = "Skin2", texture = "Floral" }
			expect(CustomizationSliceRules.validateAppearance(appearance)).to.equal(true)
		end)

		it("accepts either aspect on its own (the other keeps the rig's authored surface)", function()
			local patternOnly = emptyAppearance()
			patternOnly.surfaces.backpack1 = { pattern = "Back2" }
			expect(CustomizationSliceRules.validateAppearance(patternOnly)).to.equal(true)

			local textureOnly = emptyAppearance()
			textureOnly.surfaces.backpack1 = { texture = "Fern" }
			expect(CustomizationSliceRules.validateAppearance(textureOnly)).to.equal(true)
		end)

		it("rejects an unregistered surface channel", function()
			local appearance = emptyAppearance()
			appearance.surfaces.kneepads = { pattern = "Skin2" }
			local ok, reason = CustomizationSliceRules.validateAppearance(appearance)
			expect(ok).to.equal(false)
			expect(string.find(reason, "kneepads") ~= nil).to.equal(true)
		end)

		it("rejects an unregistered pattern or texture", function()
			local badPattern = emptyAppearance()
			badPattern.surfaces.clothing1 = { pattern = "NotAPattern" }
			expect(CustomizationSliceRules.validateAppearance(badPattern)).to.equal(false)

			local badTexture = emptyAppearance()
			badTexture.surfaces.clothing1 = { texture = "NotATexture" }
			expect(CustomizationSliceRules.validateAppearance(badTexture)).to.equal(false)
		end)

		-- Backpack patterns are NOT clothing patterns: each channel validates against its own catalog,
		-- so a valid id from the wrong catalog is still rejected.
		it("rejects a pattern from a different channel's catalog", function()
			local appearance = emptyAppearance()
			appearance.surfaces.clothing1 = { pattern = "Back2" }
			expect(CustomizationSliceRules.validateAppearance(appearance)).to.equal(false)
		end)
	end)

	describe("validateAppearance — accessories", function()
		-- SOCKET OCCUPANCY: an equipped accessory reserves its sockets, so no second accessory may use
		-- one. Two hats on `Head` would clip through each other, and a multi-socket cosmetic like a cowl
		-- (Head + Chest) has to exclude a separate chest piece.
		it("rejects two accessories competing for the same socket", function()
			local appearance = emptyAppearance()
			appearance.accessories = {
				{ id = "FishingHat", colors = {} },
				{ id = "PaperboyHat", colors = {} },
			}
			local ok, reason = CustomizationSliceRules.validateAppearance(appearance)
			expect(ok).to.equal(false)
			expect(string.find(reason, "Head") ~= nil).to.equal(true)
		end)

		it("rejects an accessory whose SECOND socket is already taken", function()
			local appearance = emptyAppearance()
			appearance.accessories = {
				{ id = "Cowl 1", colors = {} }, -- Head + Chest
				{ id = "Poncho 1", colors = {} }, -- Chest
			}
			local ok, reason = CustomizationSliceRules.validateAppearance(appearance)
			expect(ok).to.equal(false)
			expect(string.find(reason, "Chest") ~= nil).to.equal(true)
		end)

		-- Occupancy is between ACCESSORIES only. Eyelashes and glasses both mount on `Eyes` and are worn
		-- together today — a Roblox attachment happily hosts several accessories — so a blanket
		-- one-cosmetic-per-socket rule would outlaw a combination that already ships.
		it("lets a single-selection category share a socket with an accessory", function()
			local appearance = emptyAppearance()
			appearance.cosmetics.eyelashes = { id = "Eyelashes2", colors = {} }
			appearance.accessories = { { id = "Round Glasses", colors = {} } }
			expect(CustomizationSliceRules.validateAppearance(appearance)).to.equal(true)
		end)

		it("accepts accessories up to the slot limit", function()
			local appearance = emptyAppearance()
			-- Distinct sockets: the slot cap is what is under test, not socket occupancy.
			for _, id in { "FishingHat", "Round Glasses", "FaceWrap" } do
				table.insert(appearance.accessories, { id = id, colors = { rgb(1, 2, 3) } })
			end
			expect(CustomizationSliceRules.validateAppearance(appearance)).to.equal(true)
		end)

		it("rejects more accessories than there are slots", function()
			local appearance = emptyAppearance()
			for _, id in { "FishingHat", "Round Glasses", "FaceWrap", "Poncho 1" } do
				table.insert(appearance.accessories, { id = id, colors = { rgb(1, 2, 3) } })
			end
			expect(CustomizationSliceRules.validateAppearance(appearance)).to.equal(false)
		end)

		-- Accessories go through the same validateSelection path as the single-selection categories, so
		-- a retired accessory is tolerated too. The SLOT CAP below is what still constrains this array.
		it("tolerates a retired accessory id, the same as any other cosmetic", function()
			local appearance = emptyAppearance()
			table.insert(appearance.accessories, { id = "SombreroOfDoom", colors = {} })
			expect(CustomizationSliceRules.validateAppearance(appearance)).to.equal(true)
		end)

		-- A SPARSE array must never slip past the capacity check: `#` is undefined on a table with
		-- holes, so a raw op could report a short length while every entry still persists. Density is
		-- enforced, so the over-capacity write is rejected outright.
		it("rejects a sparse accessories array (holes cannot bypass the slot cap)", function()
			local appearance = emptyAppearance()
			appearance.accessories[1] = { id = "FishingHat", colors = {} }
			appearance.accessories[9] = { id = "Round Glasses", colors = {} }
			local ok, reason = CustomizationSliceRules.validateAppearance(appearance)
			expect(ok).to.equal(false)
			expect(string.find(reason, "sparse") ~= nil).to.equal(true)
		end)

		it("rejects a non-integer key in the accessories array", function()
			local appearance = emptyAppearance()
			appearance.accessories.nope = { id = "FishingHat", colors = {} }
			expect(CustomizationSliceRules.validateAppearance(appearance)).to.equal(false)
		end)

		it("rejects a sparse colors array on a cosmetic", function()
			local appearance = emptyAppearance()
			local colors = {}
			colors[1] = rgb(1, 2, 3)
			colors[7] = rgb(4, 5, 6)
			appearance.cosmetics.hair = { id = "Hair2", colors = colors }
			expect(CustomizationSliceRules.validateAppearance(appearance)).to.equal(false)
		end)
	end)

	describe("validateAppearance — Color union", function()
		it("accepts a registered dye reference", function()
			local appearance = emptyAppearance()
			appearance.body.color1 = { source = "dye", id = "crimson" }
			expect(CustomizationSliceRules.validateAppearance(appearance)).to.equal(true)
		end)

		it("rejects an unregistered dye reference", function()
			local appearance = emptyAppearance()
			appearance.body.color1 = { source = "dye", id = "chartreuse" }
			expect(CustomizationSliceRules.validateAppearance(appearance)).to.equal(false)
		end)

		it("rejects an unknown color source", function()
			local appearance = emptyAppearance()
			appearance.body.color1 = { source = "hex", value = "#ff00ff" }
			expect(CustomizationSliceRules.validateAppearance(appearance)).to.equal(false)
		end)

		it("rejects an out-of-range rgb component", function()
			local appearance = emptyAppearance()
			appearance.body.color1 = rgb(300, 0, 0)
			expect(CustomizationSliceRules.validateAppearance(appearance)).to.equal(false)
		end)

		it("rejects a non-integer rgb component", function()
			local appearance = emptyAppearance()
			appearance.body.color1 = rgb(10.5, 0, 0)
			expect(CustomizationSliceRules.validateAppearance(appearance)).to.equal(false)
		end)
	end)

	describe("validateAppearance — body channels", function()
		it("accepts every registered body channel", function()
			local appearance = emptyAppearance()
			for _, channel in CustomizationCosmeticRegistry.bodyChannels() do
				appearance.body[channel.key] = rgb(1, 2, 3)
			end
			expect(CustomizationSliceRules.validateAppearance(appearance)).to.equal(true)
		end)

		it("rejects an unregistered body channel key", function()
			local appearance = emptyAppearance()
			appearance.body.elbows = rgb(1, 2, 3)
			local ok, reason = CustomizationSliceRules.validateAppearance(appearance)
			expect(ok).to.equal(false)
			expect(string.find(reason, "elbows") ~= nil).to.equal(true)
		end)
	end)

	describe("validateEntitlements", function()
		it("accepts an empty entitlements record", function()
			expect(CustomizationSliceRules.validateEntitlements({ cosmetics = {} })).to.equal(true)
		end)

		it("accepts an owned lockable id", function()
			local entitlements = { cosmetics = { accessory = { WizardHat = true } } }
			expect(CustomizationSliceRules.validateEntitlements(entitlements)).to.equal(true)
		end)

		it("rejects storing a FREE (non-lockable) id — free ids need no entitlement row", function()
			local entitlements = { cosmetics = { accessory = { FishingHat = true } } }
			local ok, reason = CustomizationSliceRules.validateEntitlements(entitlements)
			expect(ok).to.equal(false)
			expect(string.find(reason, "FishingHat") ~= nil).to.equal(true)
		end)

		it("rejects an unregistered id", function()
			local entitlements = { cosmetics = { accessory = { NotAThing = true } } }
			expect(CustomizationSliceRules.validateEntitlements(entitlements)).to.equal(false)
		end)

		it("rejects a non-table entitlements or a missing cosmetics table", function()
			expect(CustomizationSliceRules.validateEntitlements(7)).to.equal(false)
			expect(CustomizationSliceRules.validateEntitlements({})).to.equal(false)
			expect(CustomizationSliceRules.validateEntitlements({ cosmetics = "nope" })).to.equal(false)
		end)
	end)
end
