local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Visual = require(script.Parent.DepotTruckVisualSystem)
local Constants = require(script.Parent.Parent.Data.DepotTruckVisualConstants)
local DepotConstants = require(ReplicatedStorage.Shared.Features.Depot.Data.DepotConstants)

local function deckPoint(bed, point)
	return (bed.CFrame * CFrame.new(0, bed.Size.Y / 2, 0)):PointToObjectSpace(point)
end

-- A stand-in for the uploaded art: pieces named like the mesh, pivoted at deck space's origin.
local function fakeTemplate(approved)
	local model = Instance.new("Model")
	model.Name = "Truck"
	model:SetAttribute(Constants.APPROVED_ATTRIBUTE, approved)
	for _, spec in
		{
			{ "BoxShell", Vector3.new(0, 3.65, 0.3), Vector3.new(13, 7.9, 16.4) },
			{ "BoxRoof", Vector3.new(0, 7.35, 0.3), Vector3.new(13.4, 0.75, 16.9) },
			{ "ScannerLight", Vector3.new(0, 4.5, -8.6), Vector3.new(12, 7.6, 1) },
		}
	do
		local part = Instance.new("Part")
		part.Name = spec[1]
		part.Size = spec[3]
		part.CFrame = CFrame.new(spec[2])
		part.CanCollide = true
		part.Anchored = false
		part.Parent = model
	end
	model.WorldPivot = CFrame.identity
	return model
end

return function()
	local folder
	local bed

	beforeEach(function()
		folder = Instance.new("Folder")
		bed = Instance.new("Part")
		bed.Name = "TruckBed"
		bed.Size = Vector3.new(12, 3, 16)
		bed.CFrame = CFrame.new(100, 1.5, -40) * CFrame.Angles(0, math.rad(90), 0)
		bed.Parent = folder
	end)

	afterEach(function()
		folder:Destroy()
	end)

	describe("build", function()
		it("never resizes the bed and hides it under the art's floor", function()
			Visual.buildWith(bed, folder, nil)
			expect(bed.Size).to.equal(Vector3.new(12, 3, 16))
			expect(bed.CFrame.Position).to.equal(Vector3.new(100, 1.5, -40))
			expect(bed.Transparency).to.equal(Constants.BED_TRANSPARENCY)
		end)

		it("falls back to the graybox truck, none of which collides or is queryable", function()
			local art = Visual.buildWith(bed, folder, nil)
			expect(art.Name).to.equal(Constants.ART_NAME)
			expect(art:GetAttribute(Constants.ART_KIND_ATTRIBUTE)).to.equal("graybox")
			local tires = 0
			for _, part in art:GetDescendants() do
				if part:IsA("BasePart") then
					expect(part.Anchored).to.equal(true)
					expect(part.CanCollide).to.equal(false)
					expect(part.CanQuery).to.equal(false)
					expect(part.CanTouch).to.equal(false)
					if part.Name == "Tire" then
						tires += 1
					end
				end
			end
			expect(tires).to.equal(4)
		end)

		it(
			"builds invisible collision under the bed, so the load prompt's sight check sees the bed through it",
			function()
				Visual.buildWith(bed, folder, nil)
				for _, entry in Constants.COLLISION do
					local part = bed:FindFirstChild(entry.name)
					expect(part).to.be.ok()
					expect(part.Transparency).to.equal(1)
					expect(part.Anchored).to.equal(true)
					expect(part.CanCollide).to.equal(true)
					expect(part.CanQuery).to.equal(true)
					expect(part.CanTouch).to.equal(false)
					expect((deckPoint(bed, part.Position) - entry.centre).Magnitude < 1e-3).to.equal(true)
				end
			end
		)

		it("rises the ramp from the ground behind the truck to the bed's back edge", function()
			Visual.buildWith(bed, folder, nil)
			local ramp = bed:FindFirstChild("TruckRamp")
			expect(ramp:IsA("WedgePart")).to.equal(true)
			-- A wedge's high edge is its local +Y/+Z corner; its low edge is local -Y/-Z.
			local high = deckPoint(bed, ramp.CFrame:PointToWorldSpace(Vector3.new(0, ramp.Size.Y / 2, ramp.Size.Z / 2)))
			local low =
				deckPoint(bed, ramp.CFrame:PointToWorldSpace(Vector3.new(0, -ramp.Size.Y / 2, -ramp.Size.Z / 2)))
			expect(high.Y).to.be.near(0, 1e-3)
			expect(high.Z).to.be.near(-8, 1e-3)
			expect(low.Y).to.be.near(-3, 1e-3)
			expect(low.Z).to.be.near(-12, 1e-3)
		end)

		it("puts the art on the bed with the cab toward +Z", function()
			local art = Visual.buildWith(bed, folder, nil)
			local cab = art:FindFirstChild("CabBody")
			local local_ = deckPoint(bed, cab.Position)
			expect(local_.Z > 8).to.equal(true)
		end)

		it("tags the scanner light with its sweep path and a glow", function()
			local art = Visual.buildWith(bed, folder, nil)
			local scanner = art:FindFirstChild(Constants.SCANNER_PIECE)
			expect(CollectionService:HasTag(scanner, DepotConstants.SCANNER_TAG)).to.equal(true)
			expect(scanner:FindFirstChild(Constants.SCANNER_GLOW_NAME):IsA("PointLight")).to.equal(true)
			local top = scanner:FindFirstChild(DepotConstants.SCANNER_SWEEP_TOP)
			local bottom = scanner:FindFirstChild(DepotConstants.SCANNER_SWEEP_BOTTOM)
			expect((deckPoint(bed, top.WorldPosition) - Constants.SWEEP_TOP).Magnitude < 1e-3).to.equal(true)
			expect((deckPoint(bed, bottom.WorldPosition) - Constants.SWEEP_BOTTOM).Magnitude < 1e-3).to.equal(true)
			expect(scanner:GetAttribute(DepotConstants.SCANNER_WIDTH_ATTRIBUTE)).to.equal(Constants.SWEEP_WIDTH)
			expect(scanner:GetAttribute(DepotConstants.SCANNER_IDLE_ATTRIBUTE)).to.equal(Constants.SCANNER_IDLE)
		end)

		it("paints the livery on both box sides and lights the box", function()
			local art = Visual.buildWith(bed, folder, nil)
			local faces = {}
			for _, gui in art:GetDescendants() do
				if gui:IsA("SurfaceGui") then
					faces[gui.Face] = true
					expect(gui:FindFirstChildWhichIsA("ImageLabel").Image).to.equal(Constants.LIVERY_IMAGE)
				end
			end
			expect(faces[Enum.NormalId.Left]).to.equal(true)
			expect(faces[Enum.NormalId.Right]).to.equal(true)
			expect(art:FindFirstChild(Constants.ROOF_PIECE):FindFirstChildWhichIsA("SurfaceLight")).to.be.ok()
		end)

		it("uses an approved template, placed by its pivot on the deck, and makes it inert", function()
			local art = Visual.buildWith(bed, folder, fakeTemplate(true))
			expect(art:GetAttribute(Constants.ART_KIND_ATTRIBUTE)).to.equal("approved-mesh")
			local shell = art:FindFirstChild("BoxShell")
			expect((deckPoint(bed, shell.Position) - Vector3.new(0, 3.65, 0.3)).Magnitude < 1e-3).to.equal(true)
			expect(shell.CanCollide).to.equal(false)
			expect(shell.Anchored).to.equal(true)
			expect(#shell:GetChildren()).to.equal(2)
			expect(CollectionService:HasTag(art:FindFirstChild("ScannerLight"), DepotConstants.SCANNER_TAG)).to.equal(
				true
			)
		end)

		it("ignores a template that is not approved", function()
			local art = Visual.buildWith(bed, folder, fakeTemplate(false))
			expect(art:GetAttribute(Constants.ART_KIND_ATTRIBUTE)).to.equal("graybox")
		end)
	end)
end
