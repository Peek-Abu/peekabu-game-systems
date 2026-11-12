local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ArtKitRegistry = require(ReplicatedStorage.Shared.Features.Art.Data.ArtKitRegistry)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local Visuals = require(ServerScriptService.Features.Art.Systems.ArtVisualSystem)
local PileArt = require(script.Parent.VacuumPileArtSystem)

return function()
	local assets, art, pile
	beforeEach(function()
		assets = Instance.new("Folder")
		art = Visuals.new(assets)
		local kit = Instance.new("Folder")
		kit.Name = ArtKitRegistry.DEFAULT_KIT
		kit.Parent = assets
		local props = Instance.new("Folder")
		props.Name = "props"
		props.Parent = kit
		local template = Instance.new("Model")
		template.Name = VacuumConstants.PILE_KINDS.paper.art
		template:SetAttribute("RuntimeApproved", true)
		template:SetAttribute("BaseSize", Vector3.new(4, 1.2, 4))
		local body = Instance.new("Part")
		body.Size = Vector3.new(4, 1.2, 4)
		body.CFrame = CFrame.new(0, 0.6, 0)
		body.Parent = template
		template.WorldPivot = CFrame.identity
		template.Parent = props
		pile = Instance.new("Part")
		pile.Anchored = true
		pile.Size = Vector3.new(4, 1.2, 4)
		pile.CFrame = CFrame.new(0, 0.6, 0)
		pile.Parent = workspace
	end)
	afterEach(function()
		pile:Destroy()
		assets:Destroy()
	end)

	it("names a registered props art key for every pile kind", function()
		for kind, style in VacuumConstants.PILE_KINDS do
			expect(`{kind} {ArtKitRegistry.contains("props", style.art)}`).to.equal(`{kind} true`)
		end
	end)

	it("dresses a pile in its kind's art from the default kit (every map), hiding the block", function()
		local visual = PileArt.dress(pile, "paper", art)
		expect(visual ~= nil).to.equal(true)
		expect(visual.Parent).to.equal(pile)
		expect(pile.Transparency).to.equal(1)
		expect(pile:GetAttribute(PileArt.SCALE_ATTRIBUTE)).to.equal(1)
	end)

	it("leaves a pile whose art the place lacks as its plain block", function()
		expect(PileArt.dress(pile, "cables", art)).to.equal(nil)
		expect(pile:FindFirstChild("ArtVisual")).to.equal(nil)
	end)

	it("re-fits the art only once the pile has shrunk a whole step since the last fit", function()
		PileArt.dress(pile, "paper", art)
		local first = pile:FindFirstChild("ArtVisual")
		pile.Size = Vector3.new(4, 1.2, 4) * (1 - VacuumConstants.PILE_ART_STEP / 2)
		expect(PileArt.rescale(pile, "paper", 1 - VacuumConstants.PILE_ART_STEP / 2, art)).to.equal(false)
		expect(pile:FindFirstChild("ArtVisual")).to.equal(first)
		local scale = 1 - VacuumConstants.PILE_ART_STEP
		pile.Size = Vector3.new(4, 1.2, 4) * scale
		expect(PileArt.rescale(pile, "paper", scale, art)).to.equal(true)
		local refit = pile:FindFirstChild("ArtVisual")
		expect(refit ~= nil and refit ~= first).to.equal(true)
		expect(pile:GetAttribute(PileArt.SCALE_ATTRIBUTE)).to.equal(scale)
	end)
end
