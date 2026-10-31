local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationRegistry = require(ReplicatedStorage.Shared.Features.Animation.Data.AnimationRegistry)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
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

		it("gives Pippa a Bubble Buddy skin wearing its outfit, in its catalogue's 3 styles", function()
			local skin = EmployeeRegistry.get("Pippa").skins.BubbleBuddy
			expect(skin).to.be.ok()
			expect(skin.outfit).to.equal("PippaBubbleBuddy")
			expect(#skin.styles).to.equal(CosmeticRegistry.get("Pippa.BubbleBuddy").styles)
			for index, folder in { "BlueYellow", "PinkTurquoise", "LilacOrange" } do
				expect(skin.styles[index].folder).to.equal(folder)
				expect(string.match(skin.styles[index].paletteTextureId, "^rbxassetid://%d+$")).to.be.ok()
			end
			-- The style's palette wins: the skin has no palette of its own.
			expect(skin.paletteTextureId).never.to.be.ok()
		end)

		it("gives Prickles a Sheriff skin wearing its outfit, in its catalogue's 3 styles", function()
			local skin = EmployeeRegistry.get("Prickles").skins.Sheriff
			expect(skin).to.be.ok()
			expect(skin.outfit).to.equal("PricklesSheriff")
			expect(#skin.styles).to.equal(CosmeticRegistry.get("Prickles.Sheriff").styles)
			for index, folder in { "BrownRed", "CharcoalBlue", "IvoryTeal" } do
				expect(skin.styles[index].folder).to.equal(folder)
				expect(string.match(skin.styles[index].paletteTextureId, "^rbxassetid://%d+$")).to.be.ok()
			end
		end)

		it("gives Cappy a PJ skin wearing its outfit in 3 styles, over his own palettes", function()
			local skin = EmployeeRegistry.get("Cappy").skins.PJ
			expect(skin).to.be.ok()
			expect(skin.outfit).to.equal("CappyPJ")
			expect(#skin.styles).to.equal(CosmeticRegistry.get("Cappy.PJ").styles)
			for index, folder in { "BlueButter", "MintRose", "CoralCream" } do
				expect(skin.styles[index].folder).to.equal(folder)
				-- The PJs cover him; his skin, hair and face keep their own palettes in every style.
				expect(skin.styles[index].paletteTextureId).never.to.be.ok()
			end
			expect(skin.paletteTextureId).never.to.be.ok()
			local idle = AnimationRegistry.get(skin.showcaseIdle)
			expect(idle).to.be.ok()
			expect(idle.looped).to.equal(true)
		end)

		it("gives every styled skin as many styles as its catalogue item, each naming a folder", function()
			for _, name in EmployeeRegistry.names() do
				local def = EmployeeRegistry.get(name)
				for key, skin in def.skins do
					if skin.styles ~= nil then
						local item = CosmeticRegistry.get(`{name}.{key}`)
						expect(item).to.be.ok()
						expect(#skin.styles).to.equal(item.styles or 1)
						for _, style in skin.styles do
							expect(#style.folder > 0).to.equal(true)
							-- A chip in the Shop and the locker: a short name and the fur and outfit colours.
							expect(#style.name > 0).to.equal(true)
							expect(#style.swatch).to.equal(2)
							for _, colour in style.swatch do
								expect(typeof(colour)).to.equal("Color3")
							end
						end
					end
				end
			end
		end)

		it("registers Cappy and Prickles from their art in ReplicatedStorage.Assets, at Pippa's scale", function()
			for _, name in { "Cappy", "Prickles" } do
				local def = EmployeeRegistry.get(name)
				expect(def).to.be.ok()
				expect(table.concat(def.templatePath, ".")).to.equal("Assets.CleanupCrew.Characters." .. name)
				expect(def.scale).to.equal(EmployeeRegistry.get("Pippa").scale)
				expect(def.skins.Default).to.be.ok()
				-- Multi-palette art (each garment has its own palette): the Default skin never repaints it.
				expect(def.skins.Default.paletteTextureId).never.to.be.ok()
			end
		end)

		it("gives every employee a Gloom-Touched skin with well-formed art ids", function()
			local function wellFormed(id)
				return type(id) == "string" and string.match(id, "^rbxassetid://%d+$") ~= nil
			end
			for _, name in { "Pippa", "Cappy", "Prickles" } do
				local skin = EmployeeRegistry.get(name).skins.GloomTouched
				expect(skin).to.be.ok()
				expect(skin.paletteTextureId ~= nil or skin.piecePalettes ~= nil).to.equal(true)
				if skin.paletteTextureId ~= nil then
					expect(wellFormed(skin.paletteTextureId)).to.equal(true)
				end
				for _, id in skin.piecePalettes or {} do
					expect(wellFormed(id)).to.equal(true)
				end
			end
		end)

		it(
			"routes footsteps: a set name or nil (Cappy and Prickles borrow Pippa's until they have their own)",
			function()
				for _, name in EmployeeRegistry.names() do
					local set = EmployeeRegistry.get(name).footstepSet
					expect(set == nil or (type(set) == "string" and set ~= "")).to.equal(true)
				end
				expect(EmployeeRegistry.get("Cappy").footstepSet).to.equal("pippa")
				expect(EmployeeRegistry.get("Prickles").footstepSet).to.equal("pippa")
			end
		)

		it("gives every employee a positive, sane scale", function()
			for _, name in EmployeeRegistry.names() do
				local def = EmployeeRegistry.get(name)
				expect(def.scale > 0.5 and def.scale <= 2).to.equal(true)
			end
		end)

		it("spawns Pippa at 1.25x her authored size (head about 4.9 studs, like a stock avatar's 5)", function()
			expect(EmployeeRegistry.get("Pippa").scale).to.be.near(1.25, 1e-6)
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

		it("gives Pippa the Dazed face when she is knocked out (ragdolled, caught and thrown, dead)", function()
			local def = EmployeeRegistry.get("Pippa")
			expect(def.expressions.knockedOut).to.equal("Dazed")
			expect(table.find(def.faces, "Dazed")).to.be.ok()
		end)

		it("gives Pippa a Default skin with her palette and an OwnerSpecial skin", function()
			local def = EmployeeRegistry.get("Pippa")
			expect(def.defaultSkin).to.equal("Default")
			expect(def.skins.Default.paletteTextureId).to.equal("rbxassetid://123317546570312")
			expect(def.skins.OwnerSpecial).to.be.ok()
		end)

		it("dresses the owner's skin in the lavender palette and the round glasses, with Pippa's own faces", function()
			local owner = EmployeeRegistry.get("Pippa").skins.OwnerSpecial
			expect(owner.paletteTextureId).to.be.ok()
			expect(string.match(owner.paletteTextureId, "^rbxassetid://%d+$")).to.be.ok()
			expect(owner.paletteTextureId).never.to.equal(EmployeeRegistry.get("Pippa").skins.Default.paletteTextureId)
			expect(owner.facesFolder).never.to.be.ok()
			expect(table.find(owner.accessories, "PippaRoundGlasses")).to.be.ok()
		end)

		it("drops the legacy company vest and static uniform pieces (v6 lanyards are fitted per body)", function()
			for _, name in EmployeeRegistry.names() do
				local uniform = EmployeeRegistry.get(name).uniform
				expect(uniform).to.be.a("table")
				expect(table.find(uniform, "PippaVest")).never.to.be.ok()
				expect(table.find(uniform, "PippaLanyard")).never.to.be.ok()
			end
		end)

		it("keeps no per-skin ID-card photos (a portrait that cannot draw shows the shared error)", function()
			for _, name in EmployeeRegistry.names() do
				local def = EmployeeRegistry.get(name)
				expect(def.portrait).never.to.be.ok()
				for _, skin in def.skins do
					expect(skin.portrait).never.to.be.ok()
				end
			end
		end)
	end)

	describe("backpack", function()
		it("fits any backpack with a sane mount behind the torso and positive sizes", function()
			for _, name in EmployeeRegistry.names() do
				local fit = EmployeeRegistry.get(name).backpack
				if fit ~= nil then
					-- Behind the UpperTorso's centre (+Z is back), not far from it.
					expect(fit.mount.Position.Z > 0).to.equal(true)
					expect(fit.mount.Position.Magnitude < 2).to.equal(true)
					expect(fit.size > 0.25 and fit.size <= 2).to.equal(true)
					expect(fit.strapStretch.X > 0 and fit.strapStretch.Y > 0 and fit.strapStretch.Z > 0).to.equal(true)
				end
			end
		end)

		it("wears Pippa's backpack high on her back, clear of her tail, as it was modelled on her", function()
			local fit = EmployeeRegistry.get("Pippa").backpack
			expect(fit).to.be.ok()
			-- Above the UpperTorso's centre: the tail sits below the waist.
			expect(fit.mount.Position.Y > 0).to.equal(true)
			expect(fit.size).to.equal(1)
			expect(fit.strapStretch).to.equal(Vector3.one)
		end)
	end)

	describe("reveals", function()
		it("names only one-shot clips the animation registry knows", function()
			for _, name in EmployeeRegistry.names() do
				local def = EmployeeRegistry.get(name)
				local keys = { def.hireReveal }
				for _, skin in def.skins do
					table.insert(keys, skin.unlockReveal)
				end
				for _, key in keys do
					local clip = AnimationRegistry.get(key)
					expect(clip).to.be.ok()
					expect(clip.looped).to.equal(false)
				end
			end
		end)

		it("gives every employee their hire reveal", function()
			expect(EmployeeRegistry.get("Pippa").hireReveal).to.equal("pippahirereveal")
			expect(EmployeeRegistry.get("Prickles").hireReveal).to.equal("prickleshirereveal")
			expect(EmployeeRegistry.get("Cappy").hireReveal).to.equal("cappyhirereveal")
		end)

		it("gives no skin its own unlock reveal yet: every skin plays the hire reveal (owner, 2026-10-29)", function()
			for _, name in EmployeeRegistry.names() do
				for _, skin in EmployeeRegistry.get(name).skins do
					expect(skin.unlockReveal).never.to.be.ok()
				end
			end
		end)
	end)

	describe("showcase idle", function()
		it("names only looped clips the animation registry knows", function()
			for _, name in EmployeeRegistry.names() do
				for _, skin in EmployeeRegistry.get(name).skins do
					local key = skin.showcaseIdle
					if key ~= nil then
						local def = AnimationRegistry.get(key)
						expect(def).to.be.ok()
						expect(def.looped).to.equal(true)
					end
				end
			end
		end)

		it("gives the Legendary skins their own idle", function()
			-- Bubble Buddy's batch-3 idle was rejected (owner, 2026-10-29): she plays Pippa's own for now.
			expect(EmployeeRegistry.get("Pippa").skins.BubbleBuddy.showcaseIdle).never.to.be.ok()
			expect(EmployeeRegistry.get("Prickles").skins.Sheriff.showcaseIdle).to.equal("pricklessheriffidle")
		end)
	end)

	describe("locomotion", function()
		it("names menu reactions the animation registry holds", function()
			for _, name in EmployeeRegistry.names() do
				local reaction = EmployeeRegistry.get(name).selectReaction
				if reaction ~= nil then
					expect(AnimationRegistry.get(reaction)).to.be.ok()
				end
			end
			expect(EmployeeRegistry.get("Pippa").selectReaction).to.equal("pippaselect")
			expect(EmployeeRegistry.get("Cappy").selectReaction).to.equal("cappyselect")
			expect(EmployeeRegistry.get("Prickles").selectReaction).to.equal("pricklesselect")
		end)

		it("names fidgets the animation registry holds", function()
			for _, name in EmployeeRegistry.names() do
				local locomotion = EmployeeRegistry.get(name).locomotion
				if locomotion ~= nil and locomotion.fidget ~= nil then
					expect(AnimationRegistry.get(locomotion.fidget)).to.be.ok()
				end
			end
			expect(EmployeeRegistry.get("Pippa").locomotion.fidget).to.equal("pippafidget")
			expect(EmployeeRegistry.get("Cappy").locomotion.fidget).to.equal("cappyfidget")
			expect(EmployeeRegistry.get("Prickles").locomotion.fidget).to.equal("pricklesfidget")
		end)

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

		it("gives Cappy and Prickles their own clips and measured planted speeds", function()
			local cappy = EmployeeRegistry.get("Cappy").locomotion
			expect(cappy.walk).to.equal("cappywalk")
			expect(cappy.crouchWalk).to.equal("cappycrouchwalk")
			expect(cappy.walkPlantedSpeed).to.be.near(1.06, 1e-6)
			expect(cappy.runPlantedSpeed).to.be.near(2.06, 1e-6)
			local prickles = EmployeeRegistry.get("Prickles").locomotion
			expect(prickles.idle).to.equal("pricklesidle")
			expect(prickles.walkPlantedSpeed).to.be.near(1.03, 1e-6)
			expect(prickles.runPlantedSpeed).to.be.near(1.93, 1e-6)
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
		it("accepts the four expressions", function()
			expect(EmployeeRegistry.toFace("Happy")).to.equal("Happy")
			expect(EmployeeRegistry.toFace("Worried")).to.equal("Worried")
			expect(EmployeeRegistry.toFace("Content")).to.equal("Content")
			expect(EmployeeRegistry.toFace("Dazed")).to.equal("Dazed")
		end)

		it("refuses anything else", function()
			expect(EmployeeRegistry.toFace("Angry")).never.to.be.ok()
			expect(EmployeeRegistry.toFace(nil)).never.to.be.ok()
			expect(EmployeeRegistry.toFace(3)).never.to.be.ok()
		end)
	end)
end
