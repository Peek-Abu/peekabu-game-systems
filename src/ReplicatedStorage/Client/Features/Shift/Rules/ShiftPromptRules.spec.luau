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

	describe("aim", function()
		-- The office truck's bed (12 x 3 x 16, axis-aligned) and a camera behind the player looking toward the cab (+Z).
		local BED = CFrame.new(1090.5, 2.5, -17)
		local BED_SIZE = Vector3.new(12, 3, 16)
		local LOOK = Vector3.new(0, -0.3, 0.95).Unit

		it("counts the bed straight ahead from its front half, facing the cab (its centre is behind)", function()
			local root = Vector3.new(1087.75, 5.43, -11)
			-- The old measure, to the bed's centre, was behind the player: Load was never offered.
			expect(LOOK:Dot((BED.Position - root).Unit) < 0).to.equal(true)
			expect(Rules.aim(BED, BED_SIZE, root, LOOK)).to.equal(1)
			local bed = candidate(1, (BED.Position - root).Magnitude, Rules.aim(BED, BED_SIZE, root, LOOK))
			bed.range = 16
			expect(Rules.choose({ bed }, nil)).to.equal(1)
		end)

		it("counts a part ahead when its nearest edge is, beside the bed's front half", function()
			local root = Vector3.new(1083, 3, -11)
			expect(LOOK:Dot((BED.Position - root).Unit) < 0).to.equal(true)
			expect(Rules.aim(BED, BED_SIZE, root, LOOK) >= 0).to.equal(true)
		end)

		it("is straight ahead inside a part, and keeps a part wholly behind the player behind", function()
			expect(Rules.aim(BED, BED_SIZE, BED.Position, LOOK)).to.equal(1)
			local behind = CFrame.new(1090.5, 2.5, -40)
			expect(Rules.aim(behind, Vector3.new(4, 3, 4), Vector3.new(1090.5, 5.43, -20), LOOK) < 0).to.equal(true)
		end)

		it("measures a small part like its centre, and a point (an attachment) exactly so", function()
			local root = Vector3.new(0, 3, 0)
			local look = Vector3.new(1, 0, 0)
			local small = CFrame.new(4, 3, 3)
			local toCentre = look:Dot((small.Position - root).Unit)
			expect(math.abs(Rules.aim(small, Vector3.new(0.5, 0.5, 0.5), root, look) - toCentre) < 0.1).to.equal(true)
			expect(math.abs(Rules.aim(small, Vector3.zero, root, look) - toCentre) < 1e-6).to.equal(true)
		end)

		it("follows a rotated part's own axes", function()
			-- A long thin part (20 along its own X) at Z = 10. Turned 90 degrees about Y it runs along world Z
			-- (X -0.5..0.5, Z 0..20), so from (5, 3, 0) its nearest point is to the -X side; unturned (X -10..10,
			-- Z 9.5..10.5) it is to the +Z side.
			local size = Vector3.new(20, 1, 1)
			local root = Vector3.new(5, 3, 0)
			local west = Vector3.new(-1, 0, 0)
			local turned = CFrame.new(0, 3, 10) * CFrame.Angles(0, math.rad(90), 0)
			expect(math.abs(Rules.aim(turned, size, root, west) - 1) < 1e-4).to.equal(true)
			expect(math.abs(Rules.aim(CFrame.new(0, 3, 10), size, root, west)) < 1e-4).to.equal(true)
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
