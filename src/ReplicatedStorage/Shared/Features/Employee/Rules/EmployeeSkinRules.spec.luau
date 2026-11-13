local EmployeeSkinRules = require(script.Parent.EmployeeSkinRules)

return function()
	local function skin(name, palette, facesFolder)
		return { name = name, paletteTextureId = palette, facesFolder = facesFolder, accessories = {} }
	end

	local def = {
		defaultSkin = "Default",
		skins = {
			Default = skin("Default", "rbxassetid://1"),
			Special = skin("Special", "rbxassetid://2", "SpecialFaces"),
			Pending = skin("Pending", nil),
		},
	}

	describe("idleOf / fidgetOf", function()
		local function emp(skins)
			return {
				defaultSkin = "Default",
				skins = skins,
				locomotion = { idle = "ownidle", fidget = "ownfidget" },
			}
		end
		local plain = skin("Default", nil)
		local legendary = skin("Legendary", nil)
		legendary.showcaseIdle = "skinidle"
		legendary.showcaseFidget = "skinfidget"
		local idleOnly = skin("IdleOnly", nil)
		idleOnly.showcaseIdle = "skinidle"
		local e = emp({ Default = plain, Legendary = legendary, IdleOnly = idleOnly })
		-- An idle item borrows a skin's showcase idle and fidget (EmployeeDef `idles`: idle key -> skin key).
		e.idles = { LegendaryIdle = "Legendary", IdleOnlyIdle = "IdleOnly", Broken = "Nope" }

		it("plays a chosen idle item's clip on any skin, and its fidget (or none)", function()
			for _, key in { "Default", "IdleOnly", "Nope" } do
				expect(EmployeeSkinRules.idleOf(e, key, "LegendaryIdle")).to.equal("skinidle")
				expect(EmployeeSkinRules.fidgetOf(e, key, "LegendaryIdle")).to.equal("skinfidget")
			end
			expect(EmployeeSkinRules.idleOf(e, "Default", "IdleOnlyIdle")).to.equal("skinidle")
			expect(EmployeeSkinRules.fidgetOf(e, "Default", "IdleOnlyIdle")).never.to.be.ok()
		end)

		it("plays the skin's own idle for no idle item, an unknown one or one pointing at a missing skin", function()
			for _, idle in { nil, "", "Unknown", "Broken" } do
				expect(EmployeeSkinRules.idleOf(e, "Legendary", idle)).to.equal("skinidle")
				expect(EmployeeSkinRules.idleOf(e, "Default", idle)).to.equal("ownidle")
				expect(EmployeeSkinRules.fidgetOf(e, "Default", idle)).to.equal("ownfidget")
			end
		end)

		it("plays the skin's own idle and fidget when it has them, in menus and in a shift alike", function()
			expect(EmployeeSkinRules.idleOf(e, "Legendary")).to.equal("skinidle")
			expect(EmployeeSkinRules.fidgetOf(e, "Legendary")).to.equal("skinfidget")
		end)

		it("plays the employee's own for a skin without them, an unknown skin or none", function()
			for _, key in { "Default", "Nope", nil } do
				expect(EmployeeSkinRules.idleOf(e, key)).to.equal("ownidle")
				expect(EmployeeSkinRules.fidgetOf(e, key)).to.equal("ownfidget")
			end
		end)

		it("never plays the employee's fidget over a skin's own idle (it would not fit it)", function()
			expect(EmployeeSkinRules.idleOf(e, "IdleOnly")).to.equal("skinidle")
			expect(EmployeeSkinRules.fidgetOf(e, "IdleOnly")).never.to.be.ok()
		end)

		it("is nil for an employee without its own locomotion", function()
			local stock = { defaultSkin = "Default", skins = { Default = plain } }
			expect(EmployeeSkinRules.idleOf(stock, "Default")).never.to.be.ok()
			expect(EmployeeSkinRules.fidgetOf(stock, "Default")).never.to.be.ok()
		end)
	end)

	describe("select", function()
		it("uses the employee's default skin when the player has none", function()
			expect(EmployeeSkinRules.select(def, nil).name).to.equal("Default")
		end)

		it("uses the player's skin when the employee has it", function()
			expect(EmployeeSkinRules.select(def, "Special").name).to.equal("Special")
		end)

		it("falls back to the default skin for a skin this employee lacks", function()
			expect(EmployeeSkinRules.select(def, "Missing").name).to.equal("Default")
		end)

		it("returns nil when even the default skin is missing", function()
			expect(EmployeeSkinRules.select({ defaultSkin = "Gone", skins = {} }, nil)).never.to.be.ok()
		end)
	end)

	describe("palette", function()
		it("returns a well-formed asset id", function()
			expect(EmployeeSkinRules.palette(def.skins.Special)).to.equal("rbxassetid://2")
		end)

		it("returns nil while the art is pending or the id is malformed", function()
			expect(EmployeeSkinRules.palette(def.skins.Pending)).never.to.be.ok()
			expect(EmployeeSkinRules.palette(skin("Bad", ""))).never.to.be.ok()
			expect(EmployeeSkinRules.palette(skin("Bad", "rbxassetid://TBD"))).never.to.be.ok()
			expect(EmployeeSkinRules.palette(skin("Bad", "http://example.com/x.png"))).never.to.be.ok()
		end)
	end)

	-- A skin with an outfit in three colour styles, each with its own body palette.
	local function styled()
		local styledSkin = skin("Styled", "rbxassetid://9")
		styledSkin.outfit = "Outfit"
		styledSkin.styles = {
			{ folder = "Blue", paletteTextureId = "rbxassetid://11" },
			{ folder = "Pink", paletteTextureId = "rbxassetid://12" },
			{ folder = "Lilac", paletteTextureId = "rbxassetid://13" },
		}
		return styledSkin
	end

	describe("style", function()
		it("returns the style for 1..n", function()
			local styledSkin = styled()
			for index, want in { "Blue", "Pink", "Lilac" } do
				expect(EmployeeSkinRules.style(styledSkin, index).folder).to.equal(want)
			end
		end)

		it("falls back to style 1 for nil, 0, n+1 and a non-integer", function()
			local styledSkin = styled()
			expect(EmployeeSkinRules.style(styledSkin, nil).folder).to.equal("Blue")
			for _, index in { 0, 4, 1.5, -2 } do
				expect(EmployeeSkinRules.style(styledSkin, index).folder).to.equal("Blue")
			end
		end)

		it("returns nil for a skin with no styles", function()
			expect(EmployeeSkinRules.style(def.skins.Default, 1)).never.to.be.ok()
			local empty = skin("Empty", nil)
			empty.styles = {}
			expect(EmployeeSkinRules.style(empty, 1)).never.to.be.ok()
		end)
	end)

	describe("styleIndex", function()
		it("keeps a style the skin has and clamps anything else to 1", function()
			local styledSkin = styled()
			expect(EmployeeSkinRules.styleIndex(styledSkin, 3)).to.equal(3)
			expect(EmployeeSkinRules.styleIndex(styledSkin, 9)).to.equal(1)
			expect(EmployeeSkinRules.styleIndex(styledSkin, nil)).to.equal(1)
		end)

		it("is 1 for a skin with no styles", function()
			expect(EmployeeSkinRules.styleIndex(def.skins.Default, 2)).to.equal(1)
		end)
	end)

	describe("hasStyles", function()
		it("is false for no styles, none and a single style", function()
			expect(EmployeeSkinRules.hasStyles(def.skins.Default)).to.equal(false)
			local empty = skin("Empty", nil)
			empty.styles = {}
			expect(EmployeeSkinRules.hasStyles(empty)).to.equal(false)
			local one = styled()
			one.styles = { one.styles[1] }
			expect(EmployeeSkinRules.hasStyles(one)).to.equal(false)
		end)

		it("is true for three", function()
			expect(EmployeeSkinRules.hasStyles(styled())).to.equal(true)
		end)
	end)

	describe("palette with a style", function()
		it("returns style n's palette for a styled skin", function()
			local styledSkin = styled()
			expect(EmployeeSkinRules.palette(styledSkin, 2)).to.equal("rbxassetid://12")
			expect(EmployeeSkinRules.palette(styledSkin, nil)).to.equal("rbxassetid://11")
			expect(EmployeeSkinRules.palette(styledSkin, 7)).to.equal("rbxassetid://11")
		end)

		it("keeps the skin's own palette for every other skin", function()
			expect(EmployeeSkinRules.palette(def.skins.Special, 2)).to.equal("rbxassetid://2")
		end)

		it("refuses a style's malformed palette", function()
			local styledSkin = styled()
			styledSkin.styles[1].paletteTextureId = "rbxassetid://TBD"
			expect(EmployeeSkinRules.palette(styledSkin, 1)).never.to.be.ok()
		end)

		it("leaves the body alone for a style with no palette (an outfit over the body's own palettes)", function()
			local styledSkin = styled()
			styledSkin.styles[2].paletteTextureId = nil
			expect(EmployeeSkinRules.palette(styledSkin, 2)).never.to.be.ok()
			expect(EmployeeSkinRules.palette(styledSkin, 3)).to.equal("rbxassetid://13")
		end)
	end)

	describe("stylesFor", function()
		it("lists a registered skin's real styles, in order", function()
			local styles = EmployeeSkinRules.stylesFor("Pippa", "BubbleBuddy")
			expect(#styles).to.equal(3)
			expect(styles[1].folder).to.equal("BlueYellow")
			local pj = EmployeeSkinRules.stylesFor("Cappy", "PJ")
			expect(#pj).to.equal(3)
			expect(pj[1].folder).to.equal("BlueButter")
		end)

		it("is empty for a skin with no styles, an unknown skin and an unknown employee", function()
			expect(#EmployeeSkinRules.stylesFor("Pippa", "Default")).to.equal(0)
			expect(#EmployeeSkinRules.stylesFor("Cappy", "GloomTouched")).to.equal(0)
			expect(#EmployeeSkinRules.stylesFor("Pippa", "Nope")).to.equal(0)
			expect(#EmployeeSkinRules.stylesFor(nil, "BubbleBuddy")).to.equal(0)
		end)
	end)

	describe("wornChanged", function()
		local current = { employee = "Pippa", skin = "Styled", style = 2 }

		it("is false when the employee, skin and style are all the same", function()
			expect(EmployeeSkinRules.wornChanged(current, "Pippa", "Styled", 2)).to.equal(false)
		end)

		it("is true for a style-only change, and for another skin or employee", function()
			expect(EmployeeSkinRules.wornChanged(current, "Pippa", "Styled", 3)).to.equal(true)
			expect(EmployeeSkinRules.wornChanged(current, "Pippa", "Default", 2)).to.equal(true)
			expect(EmployeeSkinRules.wornChanged(current, "Cappy", "Styled", 2)).to.equal(true)
		end)

		it("is true when nothing is worn yet", function()
			expect(EmployeeSkinRules.wornChanged(nil, "Pippa", "Styled", 1)).to.equal(true)
		end)
	end)

	describe("piecePalette", function()
		it("returns a piece's well-formed palette id", function()
			local withPieces = skin("A", nil)
			withPieces.piecePalettes = { Hoodie = "rbxassetid://7" }
			expect(EmployeeSkinRules.piecePalette(withPieces, "Hoodie")).to.equal("rbxassetid://7")
		end)

		it("returns nil for a piece without one, a malformed one, or a skin with none", function()
			local withPieces = skin("A", nil)
			expect(EmployeeSkinRules.piecePalette(withPieces, "Hoodie")).never.to.be.ok()
			withPieces.piecePalettes = { Hoodie = "rbxassetid://x" }
			expect(EmployeeSkinRules.piecePalette(withPieces, "Hoodie")).never.to.be.ok()
			expect(EmployeeSkinRules.piecePalette(withPieces, "Cap")).never.to.be.ok()
		end)
	end)
end
