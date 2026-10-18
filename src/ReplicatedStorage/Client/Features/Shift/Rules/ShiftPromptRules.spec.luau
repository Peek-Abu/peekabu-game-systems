local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rules = require(script.Parent.ShiftPromptRules)
local CameraOccluderConstants = require(ReplicatedStorage.Shared.Features.Camera.Data.CameraOccluderConstants)
local function candidate(id, distance, dot, enabled)
	return { id = id, distance = distance, dot = dot, range = 6, visible = true, enabled = enabled ~= false }
end
return function()
	describe("nearby selection", function()
		it("rejects far, hidden, behind-camera and disabled targets", function()
			local a = candidate(1, 7, 1)
			local b = candidate(2, 2, 1, false)
			local c = candidate(3, 2, 1)
			c.visible = false
			expect(Rules.choose({ a, b, c, candidate(4, 2, -1) }, nil)).to.equal(nil)
		end)
		it("selects one close target and prefers aim for similar distances", function()
			expect(Rules.choose({ candidate(1, 4, 0.1), candidate(2, 4, 0.95) }, nil)).to.equal(2)
		end)
		it("keeps close ties stable but yields to a materially better target", function()
			expect(Rules.choose({ candidate(1, 3, 1), candidate(2, 3.4, 1) }, 2)).to.equal(2)
			expect(Rules.choose({ candidate(1, 1, 1), candidate(2, 4, 1) }, 2)).to.equal(1)
		end)
		it("resolves equal scores by stable id, independent of iteration order", function()
			expect(Rules.choose({ candidate(4, 3, 1), candidate(2, 3, 1) }, nil)).to.equal(2)
		end)
	end)

	describe("sight", function()
		local made = {}
		local function part(props)
			local p = Instance.new("Part")
			p.Anchored = true
			for key, value in props or {} do
				p[key] = value
			end
			table.insert(made, p)
			return p
		end
		afterEach(function()
			for _, p in made do
				p:Destroy()
			end
			table.clear(made)
		end)

		it("sees the target, or a part of the target", function()
			local target = part()
			local child = part({ Parent = target })
			expect(Rules.sight(target, target, nil)).to.equal("target")
			expect(Rules.sight(child, target, nil)).to.equal("target")
		end)

		it("is blocked by an opaque colliding part and by a flagged collision proxy", function()
			local target = part()
			expect(Rules.sight(part(), target, nil)).to.equal("blocked")
			local proxy = part({ Transparency = 1 })
			proxy:SetAttribute(CameraOccluderConstants.ATTRIBUTE, true)
			expect(Rules.sight(proxy, target, nil)).to.equal("blocked")
		end)

		it("looks past an invisible non-colliding volume (the truck's SafeZone) and non-colliding art", function()
			local target = part()
			local zone = part({ Transparency = 1, CanCollide = false })
			expect(Rules.sight(zone, target, nil)).to.equal("past")
			expect(Rules.sight(part({ CanCollide = false }), target, nil)).to.equal("past")
			expect(Rules.sight(part({ Transparency = 0.5 }), target, nil)).to.equal("past")
		end)

		it("looks past whatever the local player carries, even a flagged proxy welded to them", function()
			local target = part()
			local root = part({ Anchored = false, Parent = workspace })
			local jug = part({ Anchored = false, Parent = workspace })
			jug:SetAttribute(CameraOccluderConstants.ATTRIBUTE, true)
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = jug
			weld.Parent = root
			expect(Rules.sight(jug, target, root)).to.equal("past")
			expect(Rules.sight(jug, target, nil)).to.equal("blocked")
		end)
	end)
end
