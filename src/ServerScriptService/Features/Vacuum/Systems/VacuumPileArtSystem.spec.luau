local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ArtKitRegistry = require(ReplicatedStorage.Shared.Features.Art.Data.ArtKitRegistry)
local ArtKitRules = require(ReplicatedStorage.Shared.Features.Art.Rules.ArtKitRules)
local VacuumConstants = require(ReplicatedStorage.Shared.Features.Vacuum.Data.VacuumConstants)
local Visuals = require(ServerScriptService.Features.Art.Systems.ArtVisualSystem)
local PileArt = require(script.Parent.VacuumPileArtSystem)
local PileFormulas = require(script.Parent.Parent.Utils.VacuumPileFormulas)

-- The lowest world Y of every part under `root` (each part's rotated box corners).
local function lowestOf(root)
	local lowest = math.huge
	for _, part in root:GetDescendants() do
		if part:IsA("BasePart") then
			local half = part.Size / 2
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						lowest = math.min(lowest, (part.CFrame * Vector3.new(x * half.X, y * half.Y, z * half.Z)).Y)
					end
				end
			end
		end
	end
	return lowest
end

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
		local host = pile:FindFirstChild(PileArt.HOST_NAME)
		expect(host ~= nil).to.equal(true)
		expect(visual.Parent).to.equal(host)
		expect(pile.Transparency).to.equal(1)
		expect(pile:GetAttribute(PileArt.SCALE_ATTRIBUTE)).to.equal(1)
	end)

	it(
		"fits the art to its kind's art box, which may overhang the gameplay block, standing on the block's floor",
		function()
			PileArt.dress(pile, "paper", art)
			local host = pile:FindFirstChild(PileArt.HOST_NAME)
			local box = VacuumConstants.PILE_KINDS.paper.artSize
			expect((host.Size - box).Magnitude < 1e-4).to.equal(true)
			expect(host.CanCollide or host.CanQuery or host.CanTouch).to.equal(false)
			expect(host.Transparency).to.equal(1)
			local floor = pile.Position.Y - pile.Size.Y / 2
			expect(math.abs((host.Position.Y - host.Size.Y / 2) - floor) < 1e-4).to.equal(true)
			expect(math.abs(host.Position.X - pile.Position.X) < 1e-4).to.equal(true)
			expect(math.abs(host.Position.Z - pile.Position.Z) < 1e-4).to.equal(true)
		end
	)

	it("stands the art's base exactly on the floor, even when a uniform fit leaves it shorter than its box", function()
		-- A squat template (wider than tall for its box): the uniform fit is limited across, so the art is shorter than
		-- the host; it must still stand on the floor, not hang centred in the box.
		local template = assets[ArtKitRegistry.DEFAULT_KIT].props[VacuumConstants.PILE_KINDS.paper.art]
		template:SetAttribute("BaseSize", Vector3.new(8, 1, 8))
		template:FindFirstChildWhichIsA("BasePart").Size = Vector3.new(8, 1, 8)
		template:FindFirstChildWhichIsA("BasePart").CFrame = CFrame.new(0, 0.5, 0)
		pile.CFrame = PileFormulas.standing(CFrame.new(3, 4, -2) * CFrame.Angles(0, 0.7, 0), pile.Size)
		local visual = PileArt.dress(pile, "paper", art)
		expect(visual ~= nil).to.equal(true)
		expect(lowestOf(visual)).to.be.near(4, 1e-3)
	end)

	it("keeps the art on the floor at every step as the pile is vacuumed down to nothing", function()
		local floor = CFrame.new(-6, 2.5, 9) * CFrame.Angles(0, -0.3, 0)
		local base = pile.Size
		pile.CFrame = PileFormulas.standing(floor, base)
		PileArt.dress(pile, "paper", art)
		local refits = 0
		for step = 1, 40 do
			local progress = step / 40
			local frame, size = PileFormulas.shrunk(pile.CFrame, pile.Size, base, progress)
			pile.Size = size
			pile.CFrame = frame
			if PileArt.rescale(pile, "paper", PileFormulas.scaleAt(progress), art) then
				refits += 1
			end
			expect(pile.Position.Y - pile.Size.Y / 2).to.be.near(2.5, 1e-4)
			local host = pile:FindFirstChild(PileArt.HOST_NAME)
			expect(host.Position.Y - host.Size.Y / 2).to.be.near(2.5, 1e-4)
			expect(lowestOf(host:FindFirstChild("ArtVisual"))).to.be.near(2.5, 1e-3)
		end
		expect(refits > 5).to.equal(true)
	end)

	it("has every pile template in this place's kit pivoted at its base and accepted by the art system", function()
		local live = ReplicatedStorage:FindFirstChild("Assets")
		local crew = live and live:FindFirstChild("CleanupCrew")
		local kits = crew and crew:FindFirstChild("ArtKits")
		local kit = kits and kits:FindFirstChild(ArtKitRegistry.DEFAULT_KIT)
		local props = kit and kit:FindFirstChild("props")
		for kind, style in VacuumConstants.PILE_KINDS do
			local template = props and props:FindFirstChild(style.art)
			if template ~= nil and template:IsA("Model") then
				local below = lowestOf(template) - template:GetPivot().Position.Y
				expect(`{kind} {math.abs(below) < 0.02}`).to.equal(`{kind} true`)
				-- and the art system accepts it (BaseSize = its whole bounds, bottom-centred), or the pile shows no art
				expect(`{kind} {ArtKitRules.validateTemplate(template, "props")}`).to.equal(`{kind} true`)
			end
		end
	end)

	it("never sizes a pile's art box smaller than its gameplay block", function()
		for kind, style in VacuumConstants.PILE_KINDS do
			local fits = style.artSize.X >= style.size.X and style.artSize.Z >= style.size.Z
			expect(`{kind} {fits}`).to.equal(`{kind} true`)
		end
	end)

	it("leaves a pile whose art the place lacks as its plain block", function()
		expect(PileArt.dress(pile, "cables", art)).to.equal(nil)
		expect(pile:FindFirstChild(PileArt.HOST_NAME)).to.equal(nil)
		expect(pile.Transparency).to.equal(0)
	end)

	it("re-fits the art only once the pile has shrunk a whole step since the last fit", function()
		PileArt.dress(pile, "paper", art)
		local first = pile:FindFirstChild(PileArt.HOST_NAME):FindFirstChild("ArtVisual")
		pile.Size = Vector3.new(4, 1.2, 4) * (1 - VacuumConstants.PILE_ART_STEP / 2)
		expect(PileArt.rescale(pile, "paper", 1 - VacuumConstants.PILE_ART_STEP / 2, art)).to.equal(false)
		expect(pile:FindFirstChild(PileArt.HOST_NAME):FindFirstChild("ArtVisual")).to.equal(first)
		local scale = 1 - VacuumConstants.PILE_ART_STEP
		pile.Size = Vector3.new(4, 1.2, 4) * scale
		expect(PileArt.rescale(pile, "paper", scale, art)).to.equal(true)
		local host = pile:FindFirstChild(PileArt.HOST_NAME)
		local refit = host:FindFirstChild("ArtVisual")
		expect(refit ~= nil and refit ~= first).to.equal(true)
		local box = VacuumConstants.PILE_KINDS.paper.artSize * scale
		expect((host.Size - box).Magnitude < 1e-4).to.equal(true)
		expect(pile:GetAttribute(PileArt.SCALE_ATTRIBUTE)).to.equal(scale)
	end)
end
