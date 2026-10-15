local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Surface = require(ReplicatedStorage.Shared.Features.Animation.Utils.AnimationCarrySurfaceUtils)
return function()
	-- Surfaces in the item's own space: a solid box, a ball, and nothing.
	local function boxProbe(size)
		local half = size / 2
		return function(from, along)
			local tNear, tFar = -math.huge, math.huge
			local normal = Vector3.zero
			for _, axis in { "X", "Y", "Z" } do
				local o, d, h = from[axis], along[axis], half[axis]
				if math.abs(d) < 1e-9 then
					if o < -h or o > h then
						return nil, nil
					end
				else
					local t1, t2 = (-h - o) / d, (h - o) / d
					local n1 = Vector3.new(axis == "X" and -1 or 0, axis == "Y" and -1 or 0, axis == "Z" and -1 or 0)
					if t1 > t2 then
						t1, t2 = t2, t1
						n1 = -n1
					end
					if t1 > tNear then
						tNear, normal = t1, n1
					end
					tFar = math.min(tFar, t2)
				end
			end
			if tNear > tFar or tNear < 0 or tNear > 1 then
				return nil, nil
			end
			return from + along * tNear, normal
		end
	end
	local function ballProbe(radius)
		return function(from, along)
			local a = along:Dot(along)
			local b = 2 * from:Dot(along)
			local c = from:Dot(from) - radius * radius
			local disc = b * b - 4 * a * c
			if disc < 0 then
				return nil, nil
			end
			local t = (-b - math.sqrt(disc)) / (2 * a)
			if t < 0 or t > 1 then
				return nil, nil
			end
			local hit = from + along * t
			return hit, hit.Unit
		end
	end
	local function nothing()
		return nil, nil
	end

	describe("surface contacts", function()
		local size = Vector3.new(2, 1, 1)
		local item = { size = size, probe = boxProbe(size) }

		it("support: on the bottom, palm up, fingers forward", function()
			local contact = Surface.support(item, 0.5, 0.2)
			expect((contact.Position - Vector3.new(0.5, -0.5, 0.2)).Magnitude < 1e-3).to.equal(true)
			expect(contact.UpVector:FuzzyEq(Vector3.yAxis, 1e-3)).to.equal(true)
			expect(contact.LookVector:FuzzyEq(-Vector3.zAxis, 1e-3)).to.equal(true)
		end)

		it("support: steps in under a narrow item to find its bottom", function()
			local contact = Surface.support({ size = Vector3.one * 1.2, probe = ballProbe(0.6) }, 0.55, 0.3)
			expect(contact).to.be.ok()
			expect(contact.Position.Magnitude).to.be.near(0.6, 1e-3)
			expect(Surface.support({ size = size, probe = nothing }, 0.5, 0.2)).to.equal(nil)
		end)

		it("face: on the near face, palm into it", function()
			local contact = Surface.face(item, 0.5, 0, 1)
			expect(contact.Position.Z).to.be.near(0.5, 1e-3)
			expect(contact.UpVector:FuzzyEq(-Vector3.zAxis, 1e-3)).to.equal(true)
		end)

		it("cup: on the side, palm in", function()
			local right = Surface.cup(item, 1, -0.2, 0.2)
			expect(right.Position.X).to.be.near(1, 1e-3)
			expect(right.UpVector:FuzzyEq(-Vector3.xAxis, 1e-3)).to.equal(true)
			local left = Surface.cup(item, -1, -0.2, 0.2)
			expect(left.UpVector:FuzzyEq(Vector3.xAxis, 1e-3)).to.equal(true)
		end)
	end)

	it("finds the top of the real surface above the middle, else the box's top", function()
		local top = Surface.top({ size = Vector3.one * 1.2, probe = ballProbe(0.6) })
		expect(top:FuzzyEq(Vector3.new(0, 0.6, 0), 1e-3)).to.equal(true)
		expect(Surface.top({ size = Vector3.one, probe = nothing }):FuzzyEq(Vector3.new(0, 0.5, 0), 1e-6)).to.equal(
			true
		)
	end)
end
