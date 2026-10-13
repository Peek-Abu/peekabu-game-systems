local EmployeeRegistry = require(script.Parent.EmployeeRegistry)

return function()
	describe("get", function()
		it("knows the default employee", function()
			local def = EmployeeRegistry.get(EmployeeRegistry.DEFAULT)
			expect(def).to.be.ok()
			expect(def.name).to.equal(EmployeeRegistry.DEFAULT)
		end)

		it("returns nil for an unknown employee", function()
			expect(EmployeeRegistry.get("Nobody")).never.to.be.ok()
		end)

		it("gives every employee a non-empty template path and a default face it owns", function()
			for _, name in EmployeeRegistry.names() do
				local def = EmployeeRegistry.get(name)
				expect(def).to.be.ok()
				expect(def.name).to.equal(name)
				expect(#def.templatePath > 0).to.equal(true)
				expect(table.find(def.faces, def.defaultFace)).to.be.ok()
			end
		end)

		it("points Pippa at the art asset in ReplicatedStorage.Assets", function()
			local def = EmployeeRegistry.get("Pippa")
			expect(table.concat(def.templatePath, ".")).to.equal("Assets.CleanupCrew.Characters.Pippa")
		end)
	end)

	describe("toFace", function()
		it("accepts the three expressions", function()
			expect(EmployeeRegistry.toFace("Happy")).to.equal("Happy")
			expect(EmployeeRegistry.toFace("Worried")).to.equal("Worried")
			expect(EmployeeRegistry.toFace("Content")).to.equal("Content")
		end)

		it("refuses anything else", function()
			expect(EmployeeRegistry.toFace("Angry")).never.to.be.ok()
			expect(EmployeeRegistry.toFace(nil)).never.to.be.ok()
			expect(EmployeeRegistry.toFace(3)).never.to.be.ok()
		end)
	end)
end
