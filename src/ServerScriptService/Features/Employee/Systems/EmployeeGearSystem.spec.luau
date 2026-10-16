local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeGearSystem = require(script.Parent.EmployeeGearSystem)

return function()
	local MOUNT_FRAME = CFrame.new(3, 4, 5) * CFrame.Angles(0, math.rad(30), 0)

	local function makeCharacter(scale)
		local model = Instance.new("Model")
		local torso = Instance.new("Part")
		torso.Name = "UpperTorso"
		torso.Anchored = true
		torso.Size = Vector3.new(1, 2, 1)
		torso.CFrame = MOUNT_FRAME
		torso.Parent = model
		model.PrimaryPart = torso
		if scale ~= 1 then
			model:ScaleTo(scale)
		end
		torso.CFrame = MOUNT_FRAME
		return model, torso
	end

	-- A fitted-gear template: one 1x1x1 part 0.5 studs in front of (-Z) its mount part's frame at template scale.
	local function makeGear(name, mount, extra)
		local gear = Instance.new("Model")
		gear.Name = name
		local piece = Instance.new("Part")
		piece.Name = "Piece"
		piece.Size = Vector3.new(1, 1, 1)
		piece.CFrame = CFrame.new(0, 0, -0.5)
		piece.Anchored = true
		piece.CanCollide = true
		piece.Parent = gear
		if extra ~= nil then
			extra(gear)
		end
		gear.WorldPivot = CFrame.identity
		if mount ~= nil then
			gear:SetAttribute(EmployeeConstants.GEAR_MOUNT_ATTRIBUTE, mount)
		end
		return gear, piece
	end

	describe("fit", function()
		it("puts the gear on its mount part, scaled with the character, welded and weightless", function()
			local character, torso = makeCharacter(2)
			local template = makeGear("Vest", "UpperTorso")
			local fitted = EmployeeGearSystem.fit(character, template)
			expect(fitted).to.be.ok()
			expect(fitted.Parent).to.equal(character)
			expect(fitted.Name).to.equal("Vest")
			local piece = fitted:FindFirstChild("Piece")
			expect(piece.Size.X).to.be.near(2, 1e-4)
			local expected = MOUNT_FRAME * CFrame.new(0, 0, -1)
			expect((piece.Position - expected.Position).Magnitude < 1e-3).to.equal(true)
			expect(piece.Anchored).to.equal(false)
			expect(piece.CanCollide).to.equal(false)
			expect(piece.CanQuery).to.equal(false)
			expect(piece.CanTouch).to.equal(false)
			expect(piece.Massless).to.equal(true)
			local weld = piece:FindFirstChildOfClass("WeldConstraint")
			expect(weld).to.be.ok()
			expect(weld.Part0).to.equal(torso)
			expect(weld.Part1).to.equal(piece)
			expect(template:FindFirstChild("Piece").Size.X).to.be.near(1, 1e-4)
			character:Destroy()
		end)

		it("leaves the gear at template size on an unscaled character", function()
			local character = makeCharacter(1)
			local fitted = EmployeeGearSystem.fit(character, makeGear("Vest", "UpperTorso"))
			expect(fitted:FindFirstChild("Piece").Size.X).to.be.near(1, 1e-4)
			character:Destroy()
		end)

		it("refuses gear that names no mount part, or one the character lacks", function()
			local character = makeCharacter(1)
			expect(EmployeeGearSystem.fit(character, makeGear("NoMount", nil))).never.to.be.ok()
			expect(EmployeeGearSystem.fit(character, makeGear("Hat", "Head"))).never.to.be.ok()
			expect(#character:GetChildren()).to.equal(1)
			character:Destroy()
		end)
	end)

	describe("wear", function()
		it("fits every named gear model found in the source and skips missing or non-model names", function()
			local character = makeCharacter(1)
			local source = Instance.new("Folder")
			makeGear("Vest", "UpperTorso").Parent = source
			makeGear("Lanyard", "UpperTorso").Parent = source
			local notGear = Instance.new("Folder")
			notGear.Name = "Loose"
			notGear.Parent = source
			expect(EmployeeGearSystem.wear(character, { "Vest", "Lanyard", "Loose", "Nope" }, source)).to.equal(2)
			expect(character:FindFirstChild("Vest")).to.be.ok()
			expect(character:FindFirstChild("Lanyard")).to.be.ok()
			expect(EmployeeGearSystem.wear(character, { "Vest" }, nil)).to.equal(0)
			character:Destroy()
			source:Destroy()
		end)
	end)

	describe("badge", function()
		local function lanyard(gear)
			local strap = Instance.new("Part")
			strap.Name = EmployeeConstants.LANYARD_STRAP
			strap.Parent = gear
			local card = Instance.new("Part")
			card.Name = "IdCard"
			card.Parent = gear
			local gui = Instance.new("SurfaceGui")
			gui.Parent = card
			local band = Instance.new("Frame")
			band.Name = EmployeeConstants.BADGE_BAND
			band.Parent = gui
			for _, name in
				{ EmployeeConstants.BADGE_HOLDER, EmployeeConstants.BADGE_TITLE, EmployeeConstants.BADGE_BAND_TEXT }
			do
				local label = Instance.new("TextLabel")
				label.Name = name
				label.Parent = if name == EmployeeConstants.BADGE_BAND_TEXT then band else gui
			end
			local photo = Instance.new("ImageLabel")
			photo.Name = EmployeeConstants.BADGE_PHOTO
			photo.Parent = gui
		end

		it("paints the strap and band in the rank colour and writes the holder and title", function()
			local character = makeCharacter(1)
			EmployeeGearSystem.fit(character, makeGear("Lanyard", "UpperTorso", lanyard))
			local colour = Color3.fromRGB(30, 122, 70)
			local painted = EmployeeGearSystem.badge(character, {
				holder = "Pip",
				title = "Probationary Associate",
				band = "RANK: PROBATIONARY ASSOCIATE",
				colour = colour,
				photo = "rbxassetid://42",
			})
			expect(painted).to.equal(6)
			local fitted = character.Lanyard
			expect(fitted[EmployeeConstants.LANYARD_STRAP].Color).to.equal(colour)
			local gui = fitted.IdCard.SurfaceGui
			expect(gui[EmployeeConstants.BADGE_HOLDER].Text).to.equal("Pip")
			expect(gui[EmployeeConstants.BADGE_TITLE].Text).to.equal("Probationary Associate")
			expect(gui[EmployeeConstants.BADGE_BAND].BackgroundColor3).to.equal(colour)
			expect(gui[EmployeeConstants.BADGE_BAND][EmployeeConstants.BADGE_BAND_TEXT].Text).to.equal(
				"RANK: PROBATIONARY ASSOCIATE"
			)
			expect(gui[EmployeeConstants.BADGE_PHOTO].Image).to.equal("rbxassetid://42")
			character:Destroy()
		end)

		it("paints nothing on a character without a lanyard", function()
			local character = makeCharacter(1)
			local painted = EmployeeGearSystem.badge(character, {
				holder = "Pip",
				title = "Intern",
				band = "RANK",
				colour = Color3.new(1, 1, 1),
				photo = "rbxassetid://1",
			})
			expect(painted).to.equal(0)
			character:Destroy()
		end)
	end)
end
