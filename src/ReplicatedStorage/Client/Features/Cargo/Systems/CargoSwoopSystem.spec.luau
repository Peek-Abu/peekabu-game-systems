local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Swoop = require(script.Parent.CargoSwoopSystem)
local Art = require(ReplicatedStorage.Shared.Features.Art.Systems.ArtVisualSystem)
return function()
	local assets, parent, source, system
	local function template(kitId, color)
		local kit = Instance.new("Folder")
		kit.Name = kitId
		kit.Parent = assets
		local group = Instance.new("Folder")
		group.Name = "cargo"
		group.Parent = kit
		local model = Instance.new("Model")
		model.Name = "recyclingBox"
		model:SetAttribute("RuntimeApproved", true)
		model:SetAttribute("BaseSize", Vector3.new(2, 2, 2))
		model:SetAttribute("FrontAxis", "PositiveZ")
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Shape = Enum.PartType.Ball
		body.Size = Vector3.new(2, 2, 2)
		body.Color = color
		body.CFrame = CFrame.new(0, 1, 0)
		body.Parent = model
		model.WorldPivot = CFrame.identity
		model.Parent = group
		return model
	end
	beforeEach(function()
		assets = Instance.new("Folder")
		parent = Instance.new("Folder")
		source = template("company-a", Color3.fromRGB(20, 80, 180))
		template("company-b", Color3.fromRGB(180, 50, 20))
		system = Swoop.new(Art.new(assets), parent)
	end)
	afterEach(function()
		parent:Destroy()
		assets:Destroy()
	end)
	describe("actual banked model ghosts", function()
		it("uses selected kit geometry and current proxy rotation without altering its source", function()
			local body = source.Body
			local frame, size = body.CFrame, body.Size
			local from = CFrame.new(10, 5, 20) * CFrame.Angles(0, 0.4, 0)
			local ghost = system:spawn(
				"recyclingBox",
				from,
				{ kitId = "company-a", proxySize = Vector3.new(4, 6, 4), rotation = from.Rotation }
			)
			local visual = ghost.model:FindFirstChild("ArtVisual", true)
			expect(visual ~= nil).to.equal(true)
			expect(visual:GetAttribute("ArtKitId")).to.equal("company-a")
			expect(visual.Body.Shape).to.equal(Enum.PartType.Ball)
			local expectedFront = (from.Rotation * CFrame.Angles(0, math.pi, 0)).LookVector
			expect(visual.Body.CFrame.LookVector:Dot(expectedFront) > 0.9999).to.equal(true)
			expect(ghost.model:GetPivot()).to.equal(from)
			expect(body.CFrame).to.equal(frame)
			expect(body.Size).to.equal(size)
			ghost:destroy()
		end)
		it("uniformly shrinks the entire assembled model without renderer callbacks resetting offsets", function()
			local ghost = system:spawn(
				"recyclingBox",
				CFrame.new(0, 5, 0),
				{ kitId = "company-a", proxySize = Vector3.new(4, 6, 4), rotation = CFrame.identity }
			)
			local body = ghost.model:FindFirstChild("Body", true)
			local size = body.Size
			local to = CFrame.new(20, 10, 30) * CFrame.Angles(0, 1, 0)
			ghost:update(to, 0.5)
			expect(body.Size).to.equal(size * 0.5)
			expect(ghost.model:GetPivot()).to.equal(to)
			expect(ghost.model.PrimaryPart.Size).to.equal(Vector3.new(2, 3, 2))
			for _, part in ghost.model:GetDescendants() do
				if part:IsA("BasePart") then
					expect(part.Anchored).to.equal(true)
					expect(part.CanCollide).to.equal(false)
					expect(part.CanQuery).to.equal(false)
					expect(part.CanTouch).to.equal(false)
				end
			end
		end)
		it("keeps simultaneous different kit ghosts isolated and cleans up idempotently", function()
			local a = system:spawn(
				"recyclingBox",
				CFrame.identity,
				{ kitId = "company-a", proxySize = Vector3.one, rotation = CFrame.identity }
			)
			local b = system:spawn(
				"recyclingBox",
				CFrame.identity,
				{ kitId = "company-b", proxySize = Vector3.one, rotation = CFrame.identity }
			)
			expect(a.model:FindFirstChild("Body", true).Color == b.model:FindFirstChild("Body", true).Color).to.equal(
				false
			)
			a:destroy()
			a:destroy()
			expect(a.model.Parent).to.equal(nil)
			expect(b.model.Parent).to.equal(parent)
			expect(a:update(CFrame.identity, 1)).to.equal(false)
		end)
		it("uses a safe catalog fallback only when art is missing and rejects unknown kinds", function()
			local ghost = system:spawn(
				"recyclingBox",
				CFrame.identity,
				{ kitId = "missing-company", proxySize = Vector3.one, rotation = CFrame.identity }
			)
			expect(ghost.model:FindFirstChild("ArtVisual", true)).to.equal(nil)
			expect(ghost.model.PrimaryPart.Transparency).to.equal(0)
			expect(system:spawn("not-cargo", CFrame.identity, nil)).to.equal(nil)
		end)
	end)
end
