local ShiftVariantRules = require(script.Parent.ShiftVariantRules)

local function pick(overrides)
	local input = { mode = "alternate", fixed = "B", override = nil, session = "studio", shift = 1 }
	for key, value in overrides or {} do
		input[key] = value
	end
	return ShiftVariantRules.pick(input)
end

return function()
	describe("parseOverride", function()
		it("accepts A or B in any case, spaces trimmed", function()
			expect(ShiftVariantRules.parseOverride("A")).to.equal("A")
			expect(ShiftVariantRules.parseOverride(" b ")).to.equal("B")
		end)

		it("ignores anything else", function()
			for _, raw in { "C", "", "AB", 1, true, nil } do
				expect(ShiftVariantRules.parseOverride(raw)).to.equal(nil)
			end
		end)
	end)

	describe("pick", function()
		it("uses the Workspace override over everything", function()
			local variant, source = pick({ override = "A", mode = "fixed" })
			expect(variant).to.equal("A")
			expect(source).to.equal("override")
			local alternate, alternateSource = pick({ override = "b", shift = 2 })
			expect(alternate).to.equal("B")
			expect(alternateSource).to.equal("override")
		end)

		it("ignores an override that is not A or B", function()
			local variant, source = pick({ override = "C" })
			expect(variant).to.equal("B")
			expect(source).to.equal("alternate")
		end)

		it("always plays the fixed variant in fixed mode", function()
			for shift = 1, 4 do
				local variant, source = pick({ mode = "fixed", shift = shift, session = "job-7" })
				expect(variant).to.equal("B")
				expect(source).to.equal("fixed")
			end
		end)

		it("starts on the default B in Studio and flips every shift", function()
			local expected = { "B", "A", "B", "A" }
			for shift, variant in expected do
				expect((pick({ shift = shift }))).to.equal(variant)
			end
			expect((pick({ session = "", shift = 1 }))).to.equal("B")
		end)

		it("treats a shift number below 1 as the first shift", function()
			expect((pick({ shift = 0 }))).to.equal("B")
		end)

		it("is the same for the same session and shift", function()
			for shift = 1, 3 do
				expect((pick({ session = "job-7", shift = shift }))).to.equal(
					(pick({ session = "job-7", shift = shift }))
				)
			end
		end)

		it("flips each shift from a live session's start", function()
			local first = pick({ session = "job-7", shift = 1 })
			expect((pick({ session = "job-7", shift = 2 }))).to.equal(ShiftVariantRules.other(first))
			expect((pick({ session = "job-7", shift = 3 }))).to.equal(first)
		end)

		it("starts some live sessions on A and some on B", function()
			local seen = {}
			for index = 1, 40 do
				seen[pick({ session = `job-{index}`, shift = 1 })] = true
			end
			expect(seen.A).to.equal(true)
			expect(seen.B).to.equal(true)
		end)
	end)

	describe("hash", function()
		it("is stable and inside 0..2147483646", function()
			expect(ShiftVariantRules.hash("abc")).to.equal(ShiftVariantRules.hash("abc"))
			local value = ShiftVariantRules.hash("8f3c1e2a-0b7d-4c55-9e1f-6a2b3c4d5e6f")
			expect(value >= 0 and value < 2147483647).to.equal(true)
			expect(value % 1).to.equal(0)
		end)
	end)
end
