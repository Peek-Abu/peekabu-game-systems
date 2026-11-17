local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Fixture = require(script.Parent.OfficeDecorFixtureSystem)
local Visuals = require(ServerScriptService.Features.Art.Systems.ArtVisualSystem)
local Constants = require(ReplicatedStorage.Shared.Features.Office.Data.OfficeDecorConstants)

return function()
	local root
	local art
	local assets
	beforeEach(function()
		root = Instance.new("Folder")
		assets = Instance.new("Folder")
		art = Visuals.new(assets)
	end)
	afterEach(function()
		root:Destroy()
		assets:Destroy()
	end)

	describe("part", function()
		it("makes an anchored, non-colliding, unqueried part", function()
			local made = Fixture.part("Thing", Vector3.new(1, 2, 3), CFrame.new(4, 5, 6), Color3.new(1, 0, 0), root)
			expect(made.Parent).to.equal(root)
			expect(made.Name).to.equal("Thing")
			expect(made.Size).to.equal(Vector3.new(1, 2, 3))
			expect(made.Anchored).to.equal(true)
			expect(made.CanCollide).to.equal(false)
			expect(made.CanQuery).to.equal(false)
			expect(made.CanTouch).to.equal(false)
		end)
	end)

	describe("emitter", function()
		it("makes an invisible tagged sound spot of the given kind", function()
			Fixture.emitter("phone", Vector3.new(1, 2, 3), root)
			local spot = root:FindFirstChildWhichIsA("Part")
			expect(spot).to.be.ok()
			expect(spot.Transparency).to.equal(1)
			expect(spot:GetAttribute(Constants.AMBIENT_KIND_ATTRIBUTE)).to.equal("phone")
			expect(CollectionService:HasTag(spot, Constants.AMBIENT_TAG)).to.equal(true)
		end)
	end)

	describe("exitSign", function()
		it("falls back to a neon sign reading EXIT on both faces, with a glow", function()
			local sign = Fixture.exitSign(CFrame.new(), root, art, nil)
			expect(sign.Name).to.equal("ExitSign")
			expect(sign.Material).to.equal(Enum.Material.Neon)
			local faces = 0
			for _, child in sign:GetChildren() do
				if child:IsA("SurfaceGui") then
					faces += 1
				end
			end
			expect(faces).to.equal(2)
			expect(sign:FindFirstChildWhichIsA("PointLight")).to.be.ok()
		end)
	end)
end
