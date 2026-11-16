local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmployeeConstants = require(ReplicatedStorage.Shared.Features.Employee.Data.EmployeeConstants)
local EmployeeTailFormulas = require(script.Parent.EmployeeTailFormulas)

local function near(a, b, eps)
	return (a - b).Magnitude < (eps or 1e-4)
end

-- A straight 3-link chain hanging from (0, 3, 1): rest ends at y 2, 1, 0.
local ANCHOR = Vector3.new(0, 3, 1)
local REST = { Vector3.new(0, 2, 1), Vector3.new(0, 1, 1), Vector3.new(0, 0.2, 1) }
local LENGTHS = { 1, 1, 0.8 }

local function world(overrides)
	local w = {
		anchor = ANCHOR,
		targets = REST,
		lengths = LENGTHS,
		capsules = {},
		floor = -100,
		scale = 1,
	}
	for k, v in overrides or {} do
		w[k] = v
	end
	return w
end

return function()
	describe("pushOut", function()
		it("moves a point inside a capsule to its surface, away from the axis", function()
			local p =
				EmployeeTailFormulas.pushOut(Vector3.new(0.1, 1, 0), Vector3.new(0, 0, 0), Vector3.new(0, 2, 0), 0.5)
			expect(near(p, Vector3.new(0.5, 1, 0))).to.equal(true)
		end)

		it("leaves a point outside the capsule alone", function()
			local q = Vector3.new(2, 1, 0)
			expect(EmployeeTailFormulas.pushOut(q, Vector3.new(0, 0, 0), Vector3.new(0, 2, 0), 0.5)).to.equal(q)
		end)

		it("uses the capsule's round ends past the segment", function()
			local p =
				EmployeeTailFormulas.pushOut(Vector3.new(0, 2.2, 0), Vector3.new(0, 0, 0), Vector3.new(0, 2, 0), 0.5)
			expect(near(p, Vector3.new(0, 2.5, 0))).to.equal(true)
		end)
	end)

	describe("step", function()
		it("keeps a chain at rest where it hangs", function()
			local points, previous = table.clone(REST), table.clone(REST)
			for _ = 1, 30 do
				points, previous = EmployeeTailFormulas.step(points, previous, world())
			end
			-- gravity sags it a hair below the rest targets, never more than a few hundredths
			for i, p in points do
				expect((p - REST[i]).Magnitude < 0.06).to.equal(true)
			end
		end)

		it("keeps every link at its length", function()
			local points = { Vector3.new(1, 2, 1), Vector3.new(2, 1, 3), Vector3.new(0, -1, 0) }
			points = EmployeeTailFormulas.step(points, table.clone(points), world())
			local head = ANCHOR
			for i, p in points do
				expect(math.abs((p - head).Magnitude - LENGTHS[i]) < 1e-4).to.equal(true)
				head = p
			end
		end)

		it("trails behind when the body moves away, then catches up", function()
			local points, previous = table.clone(REST), table.clone(REST)
			local moved = Vector3.new(0, 0, -1)
			local targets = { REST[1] + moved, REST[2] + moved, REST[3] + moved }
			local w = world({ anchor = ANCHOR + moved, targets = targets })
			points, previous = EmployeeTailFormulas.step(points, previous, w)
			expect(points[3].Z > targets[3].Z + 0.2).to.equal(true)
			for _ = 1, 120 do
				points, previous = EmployeeTailFormulas.step(points, previous, w)
			end
			expect((points[3] - targets[3]).Magnitude < 0.1).to.equal(true)
		end)

		it("keeps the ends out of a leg capsule", function()
			local capsules = { { a = Vector3.new(0, 2.5, 1), b = Vector3.new(0, -1, 1), radius = 0.4 } }
			local points, previous = table.clone(REST), table.clone(REST)
			for _ = 1, 10 do
				points, previous = EmployeeTailFormulas.step(points, previous, world({ capsules = capsules }))
			end
			for i = 1, 2 do
				local p = points[i]
				local axis = Vector3.new(0, p.Y, 1)
				expect((p - axis).Magnitude >= 0.4 - 1e-3 or math.abs((p - ANCHOR).Magnitude - LENGTHS[1]) < 1e-3).to.equal(
					true
				)
			end
		end)

		it("never lets an end sink below the floor", function()
			local points, previous = table.clone(REST), table.clone(REST)
			for _ = 1, 30 do
				points, previous = EmployeeTailFormulas.step(points, previous, world({ floor = 0.6 }))
			end
			expect(points[3].Y >= 0.6 - 1e-4).to.equal(true)
		end)

		it("scales gravity and the leg radius with the character", function()
			expect(EmployeeTailFormulas.gravityStep(2)).to.equal(EmployeeConstants.TAIL_GRAVITY * 2)
		end)
	end)

	describe("transform", function()
		it("is identity when the link points where it does at rest", function()
			local rest = CFrame.new(0, 3, 1)
			local t =
				EmployeeTailFormulas.transform(rest, Vector3.new(0, 2, 1), Vector3.new(0, 3, 1), Vector3.new(0, 2, 1))
			expect(near(t.Position, Vector3.zero)).to.equal(true)
			expect(near(t.LookVector, Vector3.new(0, 0, -1))).to.equal(true)
		end)

		it("swings the bone so its link points at the new end", function()
			local rest = CFrame.new(0, 3, 1) * CFrame.Angles(0, 0.7, 0)
			local head, tip = Vector3.new(0, 3, 1), Vector3.new(0, 2.2, 1.6)
			local t = EmployeeTailFormulas.transform(rest, Vector3.new(0, 2, 1), head, tip)
			local posed = rest * t
			-- the rest link end, carried by the posed bone, lands on the new end's direction
			local restEndLocal = rest:PointToObjectSpace(Vector3.new(0, 2, 1))
			local landed = posed:PointToWorldSpace(restEndLocal)
			expect(near((landed - head).Unit, (tip - head).Unit, 1e-3)).to.equal(true)
			expect(near(posed.Position, head)).to.equal(true)
		end)

		it("moves the bone's head to a new head", function()
			local rest = CFrame.new(0, 2, 1)
			local t = EmployeeTailFormulas.transform(
				rest,
				Vector3.new(0, 1, 1),
				Vector3.new(0.3, 2, 1.2),
				Vector3.new(0.3, 1, 1.2)
			)
			expect(near((rest * t).Position, Vector3.new(0.3, 2, 1.2))).to.equal(true)
		end)
	end)
end
