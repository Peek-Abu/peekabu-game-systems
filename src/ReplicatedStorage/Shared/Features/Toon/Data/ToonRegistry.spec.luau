local ToonRegistry = require(script.Parent.ToonRegistry)

return function()
	describe("get", function()
		it("knows the default toon", function()
			local def = ToonRegistry.get(ToonRegistry.DEFAULT)
			expect(def).to.be.ok()
			expect(def.name).to.equal(ToonRegistry.DEFAULT)
		end)

		it("returns nil for an unknown toon", function()
			expect(ToonRegistry.get("Nobody")).never.to.be.ok()
		end)

		it("gives every toon a non-empty template path and a default face it owns", function()
			for _, name in ToonRegistry.names() do
				local def = ToonRegistry.get(name)
				expect(def).to.be.ok()
				expect(def.name).to.equal(name)
				expect(#def.templatePath > 0).to.equal(true)
				expect(table.find(def.faces, def.defaultFace)).to.be.ok()
			end
		end)

		it("points Pippa at the art asset in ReplicatedStorage.Assets", function()
			local def = ToonRegistry.get("Pippa")
			expect(table.concat(def.templatePath, ".")).to.equal("Assets.CleanupCrew.Characters.Pippa")
		end)
	end)

	describe("toFace", function()
		it("accepts the three expressions", function()
			expect(ToonRegistry.toFace("Happy")).to.equal("Happy")
			expect(ToonRegistry.toFace("Worried")).to.equal("Worried")
			expect(ToonRegistry.toFace("Content")).to.equal("Content")
		end)

		it("refuses anything else", function()
			expect(ToonRegistry.toFace("Angry")).never.to.be.ok()
			expect(ToonRegistry.toFace(nil)).never.to.be.ok()
			expect(ToonRegistry.toFace(3)).never.to.be.ok()
		end)
	end)
end
