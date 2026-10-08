--!strict
--[=[
	Unit tests for the RollPreview Cmdr command implementation. Read-only — it calls the pure
	ItemAffixFormulas, so no service mocking is needed; we assert on the formatted output string.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local rollPreviewCommand = require(ServerScriptService.Commands.ItemRollPreviewServer)
local ItemContentRegistry = require(ReplicatedStorage.Shared.Features.Item.Data.ItemContentRegistry)

return function()
	describe("ItemRollPreviewServer", function()
		beforeAll(function()
			ItemContentRegistry.init()
		end)

		it("reports a per-sample line and a summary count", function()
			local output = rollPreviewCommand(nil, "phoenix-blade", 8)
			expect(output:find("phoenix-blade", 1, true)).to.be.ok()
			expect(output:find("/8 rolled an affix", 1, true)).to.be.ok()
		end)

		it("reports a summary for a common item (now eligible under the flat, rarity-independent chance)", function()
			-- Common rolls at the same flat rate as everything else, so hit/miss counts are RNG-dependent
			-- (the flat rate itself is proven deterministically in ItemAffixFormulas.spec). Assert only that the
			-- summary line is present — i.e. the item was processed and is eligible.
			local output = rollPreviewCommand(nil, "rusted-saw", 5)
			expect(output:find("/5 rolled an affix", 1, true)).to.be.ok()
		end)

		it("reports all misses for an item kind with no pool", function()
			local output = rollPreviewCommand(nil, "healing-tonic", 5)
			expect(output:find("0/5 rolled an affix", 1, true)).to.be.ok()
		end)

		it("reports an unknown itemType instead of previewing", function()
			local output = rollPreviewCommand(nil, "not-a-real-item", 5)
			expect(output:find("Unknown itemType", 1, true)).to.be.ok()
		end)

		it("clamps an oversized sample count (bounded work at the boundary)", function()
			-- 10_000 requested → clamped to MAX_SAMPLES (100); the summary reflects the clamped count.
			local output = rollPreviewCommand(nil, "rusted-saw", 10000)
			expect(output:find("/100 rolled an affix", 1, true)).to.be.ok()
		end)
	end)
end
