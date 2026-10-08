--[[
	Unit tests for TitleRegistry — composition rules (uniqueness, id/key match, entry sanity),
	frozenness of every exported surface, and the lookup functions consumers resolve through.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TitleRegistry = require(ReplicatedStorage.Shared.Features.Title.Data.TitleRegistry)
local TitleTypes = require(ReplicatedStorage.Shared.Features.Title.Data.TitleTypes)

local function makeEntry(id: string, displayName: string): TitleTypes.TitleDef
	local def: TitleTypes.TitleDef = {
		id = id,
		displayName = displayName,
		color = Color3.fromRGB(10, 20, 30),
	}
	return table.freeze(def)
end

local function makeDomain(id: string, displayName: string): TitleTypes.TitleDomain
	return table.freeze({ [id] = makeEntry(id, displayName) })
end

return function()
	describe("composeDomains", function()
		it("composes fabricated domains into one validated index", function()
			local index = TitleRegistry.composeDomains({
				alpha = makeDomain("alpha", "Alpha"),
				beta = makeDomain("beta", "Beta"),
			})
			expect(index.byId.alpha).to.be.ok()
			expect(index.byId.alpha.displayName).to.equal("Alpha")
			expect(index.domainOf.beta).to.equal("beta")
		end)

		it("throws when two domains declare the same key", function()
			expect(function()
				TitleRegistry.composeDomains({
					first = makeDomain("clash", "One"),
					second = makeDomain("clash", "Two"),
				})
			end).to.throw()
		end)

		it("throws when an entry's id does not match its registry key", function()
			local def: TitleTypes.TitleDef = {
				id = "something-else",
				displayName = "Mislabeled",
				color = Color3.fromRGB(0, 0, 0),
			}
			expect(function()
				TitleRegistry.composeDomains({
					bad = table.freeze({ mislabeled = table.freeze(def) }),
				})
			end).to.throw()
		end)

		it("throws on an empty displayName", function()
			expect(function()
				TitleRegistry.composeDomains({ bad = makeDomain("nameless", "") })
			end).to.throw()
		end)

		it("throws on a non-Color3 color", function()
			-- Built UNFROZEN inline with the bad value already in place: mutating a frozen
			-- makeDomain entry would throw out here instead of inside the call under test.
			local def = {
				id = "offcolor",
				displayName = "OffColor",
				color = "red" :: any,
			}
			expect(function()
				TitleRegistry.composeDomains({ bad = { offcolor = def } })
			end).to.throw()
		end)
	end)

	describe("the real index", function()
		it("resolves every General entry and reports unknown ids as nil", function()
			local veteran = TitleRegistry.get("veteran")
			expect(veteran).to.be.ok()
			expect(veteran.displayName).to.equal("Veteran")
			expect(TitleRegistry.domainOf("veteran")).to.equal("general")
			expect(TitleRegistry.get("no-such-title")).to.equal(nil)
		end)

		it("answers isValidTitleId for registered and unknown ids", function()
			expect(TitleRegistry.isValidTitleId("veteran")).to.equal(true)
			expect(TitleRegistry.isValidTitleId("no-such-title")).to.equal(false)
		end)

		it("exposes a whole domain unchanged", function()
			local general = TitleRegistry.domain("general")
			expect(general).to.be.ok()
			expect(general.guildmaster).to.be.ok()
			expect(TitleRegistry.domain("nonexistent")).to.equal(nil)
		end)

		it("returns getAllIds sorted and consistent with the index", function()
			local ids = TitleRegistry.getAllIds()
			for i, id in ids do
				expect(TitleRegistry.isValidTitleId(id)).to.equal(true)
				if i > 1 then
					-- Sorted ascending, so no duplicates either.
					expect(ids[i - 1] < id).to.equal(true)
				end
			end
			local count = 0
			for _ in ids do
				count += 1
			end
			expect(count).to.equal(#ids)
		end)
	end)

	describe("frozenness", function()
		it("freezes the index, the id list, and every definition", function()
			expect(table.isfrozen(TitleRegistry.getAllIds())).to.equal(true)
			expect(table.isfrozen(TitleRegistry.get("champion"))).to.equal(true)
			expect(table.isfrozen(TitleRegistry.domain("general"))).to.equal(true)
			local composed = TitleRegistry.composeDomains({ a = makeDomain("a", "A") })
			expect(table.isfrozen(composed.byId)).to.equal(true)
			expect(table.isfrozen(composed.domainOf)).to.equal(true)
		end)
	end)
end
