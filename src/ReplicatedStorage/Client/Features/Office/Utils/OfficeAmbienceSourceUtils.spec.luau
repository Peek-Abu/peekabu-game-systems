local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local OfficeDecorConstants = require(ReplicatedStorage.Shared.Features.Office.Data.OfficeDecorConstants)
local OfficeAmbienceSourceUtils = require(script.Parent.OfficeAmbienceSourceUtils)

local function volume(kind, cframe, size)
	local p = Instance.new("Part")
	p.Name = "AmbienceSourceSpecVolume"
	p.Anchored = true
	p.CanCollide = false
	p.CFrame = cframe
	p.Size = size
	p:SetAttribute(OfficeDecorConstants.AMBIENT_KIND_ATTRIBUTE, kind)
	return p
end

return function()
	describe("emitters", function()
		it("lists each tagged part with a kind, its position and the part at the same index", function()
			local p = volume("specKind", CFrame.new(5000, 5000, 5000), Vector3.new(1, 1, 1))
			CollectionService:AddTag(p, OfficeDecorConstants.AMBIENT_TAG)
			p.Parent = Workspace
			local list, parts = OfficeAmbienceSourceUtils.emitters()
			local index = table.find(parts, p)
			p:Destroy()
			expect(index).to.be.ok()
			expect(#list).to.equal(#parts)
			expect(list[index].kind).to.equal("specKind")
			expect(list[index].position).to.equal(Vector3.new(5000, 5000, 5000))
		end)

		it("skips a tagged part with no kind", function()
			local p = volume("specKind", CFrame.new(5000, 5000, 5000), Vector3.new(1, 1, 1))
			p:SetAttribute(OfficeDecorConstants.AMBIENT_KIND_ATTRIBUTE, nil)
			CollectionService:AddTag(p, OfficeDecorConstants.AMBIENT_TAG)
			p.Parent = Workspace
			local _, parts = OfficeAmbienceSourceUtils.emitters()
			local index = table.find(parts, p)
			p:Destroy()
			expect(index).to.equal(nil)
		end)
	end)

	describe("crew", function()
		it("returns a list of positions", function()
			for _, position in OfficeAmbienceSourceUtils.crew() do
				expect(typeof(position)).to.equal("Vector3")
			end
		end)
	end)

	describe("yardSource", function()
		local center = Vector3.new(0, 0, 0)

		it("is nil when no source of the kind is within reach", function()
			local near = volume("owl", CFrame.new(0, 0, 0), Vector3.new(4, 4, 4))
			local far = volume("fence", CFrame.new(1000, 0, 0), Vector3.new(4, 4, 4))
			local list = {
				{ kind = "owl", position = near.Position },
				{ kind = "fence", position = far.Position },
			}
			local at = OfficeAmbienceSourceUtils.yardSource(Random.new(1), "fence", 100, center, list, { near, far })
			expect(at).to.equal(nil)
			expect(OfficeAmbienceSourceUtils.yardSource(Random.new(1), "can", 100, center, list, { near, far })).to.equal(
				nil
			)
			near:Destroy()
			far:Destroy()
		end)

		it("rolls a point inside the source volume within reach", function()
			local near = volume("owl", CFrame.new(10, 0, 0), Vector3.new(4, 4, 4))
			local list = { { kind = "owl", position = near.Position } }
			local at = OfficeAmbienceSourceUtils.yardSource(Random.new(1), "owl", 100, center, list, { near })
			expect(at).to.be.ok()
			expect(math.abs(at.X - 10) <= 2 + 1e-4).to.equal(true)
			expect(math.abs(at.Y) <= 2 + 1e-4).to.equal(true)
			expect(math.abs(at.Z) <= 2 + 1e-4).to.equal(true)
			near:Destroy()
		end)
	end)
end
