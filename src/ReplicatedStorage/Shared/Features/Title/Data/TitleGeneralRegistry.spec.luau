--[=[
	Unit tests for TitleGeneralRegistry — the seed titles domain. Asserts every entry is well-formed by the same
	rules TitleRegistry.composeDomains enforces (id equals key, non-empty displayName, Color3 color)
	plus frozenness, so a malformed edit fails here first with a domain-local message.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TitleGeneralRegistry = require(ReplicatedStorage.Shared.Features.Title.Data.TitleGeneralRegistry)

return function()
	describe("General", function()
		it("registers exactly the three seed titles", function()
			local count = 0
			for _ in TitleGeneralRegistry do
				count += 1
			end
			expect(count).to.equal(3)
			expect(TitleGeneralRegistry.veteran).to.be.ok()
			expect(TitleGeneralRegistry.champion).to.be.ok()
			expect(TitleGeneralRegistry.guildmaster).to.be.ok()
		end)

		it("every entry is well-formed: id equals key, non-empty displayName, Color3 color", function()
			for key, def in TitleGeneralRegistry do
				expect(def.id).to.equal(key)
				expect(type(def.displayName)).to.equal("string")
				expect(#def.displayName > 0).to.equal(true)
				expect(typeof(def.color) == "Color3").to.equal(true)
			end
		end)

		it("declares the seed display names", function()
			expect(TitleGeneralRegistry.veteran.displayName).to.equal("Veteran")
			expect(TitleGeneralRegistry.champion.displayName).to.equal("Champion")
			expect(TitleGeneralRegistry.guildmaster.displayName).to.equal("Guild Master")
		end)

		it("is frozen — the domain and every definition are data, not mutable tables", function()
			expect(table.isfrozen(TitleGeneralRegistry)).to.equal(true)
			for _, def in TitleGeneralRegistry do
				expect(table.isfrozen(def)).to.equal(true)
			end
		end)
	end)
end
