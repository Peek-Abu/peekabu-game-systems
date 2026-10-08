--!strict
--[=[
	Unit tests for CustomizationWearRules — the pure "does this cosmetic work with this head type"
	rule, and the set of equipped cosmetics a head-type switch would invalidate.

	`find` takes an injectable lookup so the RULE is testable without depending on which cosmetics the
	catalog happens to restrict today (the real restrictions are authored in 5b's content pass). The
	registry-backed default path is covered by `isCompatible`'s cases below.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CustomizationWearRules = require(ReplicatedStorage.Shared.Features.Customization.Rules.CustomizationWearRules)

return function()
	local function appearanceWith(cosmetics, accessories)
		return {
			cosmetics = cosmetics or {},
			accessories = accessories or {},
			body = {},
			headType = "Uncovered",
			surfaces = {},
		}
	end

	describe("defaultAppearance", function()
		it("stamps a default cosmetic for every defaulted category and the registry's head type", function()
			local appearance = CustomizationWearRules.defaultAppearance()
			expect(appearance.headType).to.equal("Uncovered")
			local registry = require(ReplicatedStorage.Shared.Features.Customization.Data.CustomizationCosmeticRegistry)
			for _, category in registry.defaultedCategories() do
				expect(appearance.cosmetics[category]).to.be.ok()
				expect(appearance.cosmetics[category].id).to.equal(registry.defaultCosmetic(category, "Uncovered"))
			end
		end)
	end)

	describe("allows", function()
		it("treats an absent restriction as compatible with every head type", function()
			expect(CustomizationWearRules.allows(nil, "Covered")).to.equal(true)
			expect(CustomizationWearRules.allows(nil, "Uncovered")).to.equal(true)
		end)

		it("permits only the declared head types", function()
			local coveredOnly = { Covered = true }
			expect(CustomizationWearRules.allows(coveredOnly, "Covered")).to.equal(true)
			expect(CustomizationWearRules.allows(coveredOnly, "Uncovered")).to.equal(false)
		end)

		it("permits a cosmetic that declares both", function()
			local both = { Covered = true, Uncovered = true }
			expect(CustomizationWearRules.allows(both, "Covered")).to.equal(true)
			expect(CustomizationWearRules.allows(both, "Uncovered")).to.equal(true)
		end)
	end)

	describe("isCompatible (registry-backed)", function()
		it("is true for an unrestricted registered cosmetic in either mode", function()
			-- Eyebrows are unrestricted; hair is NOT (see the head-type partition), so this case
			-- deliberately does not use hair.
			expect(CustomizationWearRules.isCompatible("eyebrows", "Eyebrows2", "Covered")).to.equal(true)
			expect(CustomizationWearRules.isCompatible("eyebrows", "Eyebrows2", "Uncovered")).to.equal(true)
		end)

		it("honours the real hair partition from the catalog", function()
			expect(CustomizationWearRules.isCompatible("hair", "Hair2", "Covered")).to.equal(true)
			expect(CustomizationWearRules.isCompatible("hair", "Hair2", "Uncovered")).to.equal(false)
			expect(CustomizationWearRules.isCompatible("hair", "Hair10", "Uncovered")).to.equal(true)
			expect(CustomizationWearRules.isCompatible("hair", "Hair10", "Covered")).to.equal(false)
		end)

		it("is true for an UNREGISTERED id — retired ids stay wearable, like everywhere else", function()
			expect(CustomizationWearRules.isCompatible("hair", "HairRetired", "Covered")).to.equal(true)
		end)
	end)

	describe("find", function()
		it("returns nothing to clear when no equipped cosmetic is restricted", function()
			local appearance = appearanceWith({ hair = { id = "Hair2", colors = {} } })
			local result = CustomizationWearRules.find(appearance, "Covered")
			expect(#result.categories).to.equal(0)
			expect(#result.accessoryIndices).to.equal(0)
		end)

		it("names a single-selection category whose cosmetic is restricted", function()
			local lookup = function(_category: string, id: string)
				return if id == "Hair5" then { Uncovered = true } else nil
			end
			local appearance = appearanceWith({
				hair = { id = "Hair5", colors = {} },
				eyebrows = { id = "Eyebrows2", colors = {} },
			})

			local result = CustomizationWearRules.find(appearance, "Covered", lookup)
			expect(#result.categories).to.equal(1)
			expect(result.categories[1]).to.equal("hair")
		end)

		it("keeps a restricted cosmetic that DOES allow the target head type", function()
			local lookup = function(_category: string, id: string)
				return if id == "Hair5" then { Uncovered = true } else nil
			end
			local appearance = appearanceWith({ hair = { id = "Hair5", colors = {} } })
			expect(#CustomizationWearRules.find(appearance, "Uncovered", lookup).categories).to.equal(0)
		end)

		it("reports accessory slots DESCENDING, so removing them in order cannot shift a later target", function()
			local lookup = function(category: string, _id: string)
				return if category == "accessory" then { Uncovered = true } else nil
			end
			local appearance = appearanceWith(nil, {
				{ id = "FishingHat", colors = {} },
				{ id = "Round Glasses", colors = {} },
				{ id = "PaperboyHat", colors = {} },
			})

			local result = CustomizationWearRules.find(appearance, "Covered", lookup)
			expect(#result.accessoryIndices).to.equal(3)
			expect(result.accessoryIndices[1]).to.equal(3)
			expect(result.accessoryIndices[2]).to.equal(2)
			expect(result.accessoryIndices[3]).to.equal(1)
		end)

		it("sorts categories so the reported set is deterministic", function()
			local lookup = function()
				return { Uncovered = true }
			end
			local appearance = appearanceWith({
				hair = { id = "Hair2", colors = {} },
				eyebrows = { id = "Eyebrows2", colors = {} },
				eyelashes = { id = "Eyelashes2", colors = {} },
			})

			local result = CustomizationWearRules.find(appearance, "Covered", lookup)
			expect(result.categories[1]).to.equal("eyebrows")
			expect(result.categories[2]).to.equal("eyelashes")
			expect(result.categories[3]).to.equal("hair")
		end)
	end)

	describe("fillEmptyDefaults", function()
		local function bareAppearance(headType)
			return { cosmetics = {}, accessories = {}, body = {}, headType = headType, surfaces = {} }
		end

		it("fills every defaulted category for the head type, and reports what it filled", function()
			local appearance = bareAppearance("Uncovered")
			local filled = {}
			expect(CustomizationWearRules.fillEmptyDefaults(appearance, filled)).to.equal(true)
			expect(appearance.cosmetics.hair.id).to.equal("Hair9")
			expect(appearance.cosmetics.shoes.id).to.equal("Boots1")
			expect(#filled >= 2).to.equal(true)
		end)

		-- The backfill runs on EVERY spawn, so already-filled must be a true no-op: a false "changed"
		-- would make the data layer commit, mirror and reapply the look for nothing, every spawn.
		it("no-ops when every defaulted category is already filled", function()
			local appearance = bareAppearance("Uncovered")
			CustomizationWearRules.fillEmptyDefaults(appearance)
			expect(CustomizationWearRules.fillEmptyDefaults(appearance)).to.equal(false)
		end)

		it("never overwrites an existing selection", function()
			local appearance = bareAppearance("Uncovered")
			appearance.cosmetics.hair = { id = "Hair10", colors = {} }
			CustomizationWearRules.fillEmptyDefaults(appearance)
			expect(appearance.cosmetics.hair.id).to.equal("Hair10")
		end)

		it("contributes nothing for a head type with no declared default", function()
			local appearance = bareAppearance("Covered")
			CustomizationWearRules.fillEmptyDefaults(appearance)
			-- Covered declares no hair default (the developer's call: helmets cover hair).
			expect(appearance.cosmetics.hair).to.equal(nil)
		end)
	end)
end
