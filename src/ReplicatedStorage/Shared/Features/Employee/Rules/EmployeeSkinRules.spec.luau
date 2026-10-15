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

	describe("portrait", function()
		local employee = { portrait = "rbxassetid://10" }

		it("uses the skin's own portrait", function()
			local own = skin("Own", "rbxassetid://2")
			own.portrait = "rbxassetid://11"
			expect(EmployeeSkinRules.portrait(employee, own)).to.equal("rbxassetid://11")
		end)

		it("falls back to the employee's portrait without one, or for a malformed one", function()
			expect(EmployeeSkinRules.portrait(employee, skin("None", "rbxassetid://2"))).to.equal("rbxassetid://10")
			local bad = skin("Bad", "rbxassetid://2")
			bad.portrait = "rbxassetid://TBD"
			expect(EmployeeSkinRules.portrait(employee, bad)).to.equal("rbxassetid://10")
		end)
	end)
end
