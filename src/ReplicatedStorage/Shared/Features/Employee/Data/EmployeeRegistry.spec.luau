local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
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

		it("maps every gameplay state to a face the employee owns", function()
			for _, name in EmployeeRegistry.names() do
				local def = EmployeeRegistry.get(name)
				for _, state in EmployeeRegistry.STATES do
					local face = def.expressions[state]
					expect(face).to.be.ok()
					expect(table.find(def.faces, face)).to.be.ok()
				end
			end
		end)

		it("gives every employee its default skin, every skin named by its key", function()
			for _, name in EmployeeRegistry.names() do
				local def = EmployeeRegistry.get(name)
				expect(def.skins[def.defaultSkin]).to.be.ok()
				for key, skin in def.skins do
					expect(skin.name).to.equal(key)
					expect(skin.accessories).to.be.a("table")
				end
			end
		end)

		it("points Pippa at the art asset in ReplicatedStorage.Assets", function()
			local def = EmployeeRegistry.get("Pippa")
			expect(table.concat(def.templatePath, ".")).to.equal("Assets.CleanupCrew.Characters.Pippa")
		end)

		it("gives Pippa her approved expressions: carrying is Content, not Happy", function()
			local def = EmployeeRegistry.get("Pippa")
			expect(def.expressions.threatened).to.equal("Worried")
			expect(def.expressions.cleaning).to.equal("Happy")
			expect(def.expressions.carrying).to.equal("Content")
			expect(def.expressions.idle).to.equal("Content")
		end)

		it("gives Pippa a Default skin with her palette and an OwnerSpecial skin", function()
			local def = EmployeeRegistry.get("Pippa")
			expect(def.defaultSkin).to.equal("Default")
			expect(def.skins.Default.paletteTextureId).to.equal("rbxassetid://123317546570312")
			expect(def.skins.OwnerSpecial).to.be.ok()
		end)
	end)

	describe("locomotion", function()
		it("names only looped clips the animation registry knows, with positive speeds and caps", function()
			for _, name in EmployeeRegistry.names() do
				local locomotion = EmployeeRegistry.get(name).locomotion
				if locomotion ~= nil then
					for _, key in { locomotion.idle, locomotion.walk, locomotion.run } do
						local def = AnimationRegistry.get(key)
						expect(def).to.be.ok()
						expect(def.looped).to.equal(true)
					end
					expect(locomotion.walkPlantedSpeed > 0).to.equal(true)
					expect(locomotion.runPlantedSpeed > 0).to.equal(true)
					expect(locomotion.minRate > 0).to.equal(true)
					expect(locomotion.walkMaxRate >= locomotion.minRate).to.equal(true)
					expect(locomotion.runMaxRate >= locomotion.minRate).to.equal(true)
				end
			end
		end)

		it("gives Pippa her own idle, walk and run with their measured planted speeds", function()
			local locomotion = EmployeeRegistry.get("Pippa").locomotion
			expect(locomotion).to.be.ok()
			expect(locomotion.idle).to.equal("pippaidle")
			expect(locomotion.walk).to.equal("pippawalk")
			expect(locomotion.run).to.equal("pipparun")
			expect(locomotion.walkPlantedSpeed).to.be.near(1.27, 1e-6)
			expect(locomotion.runPlantedSpeed).to.be.near(1.52, 1e-6)
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
