local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrainingSpotlightUtils = require(ReplicatedStorage.Client.Features.Training.Utils.TrainingSpotlightUtils)

local SCREEN = Vector2.new(1000, 600)

local function area(rect)
	return rect.size.X * rect.size.Y
end

return function()
	describe("hole", function()
		it("pads the target and keeps it on screen", function()
			local hole = TrainingSpotlightUtils.hole(Vector2.new(100, 100), Vector2.new(50, 40), SCREEN, 10)
			expect(hole.position).to.equal(Vector2.new(90, 90))
			expect(hole.size).to.equal(Vector2.new(70, 60))
		end)

		it("clamps a target at the screen edge", function()
			local hole = TrainingSpotlightUtils.hole(Vector2.new(980, -5), Vector2.new(50, 40), SCREEN, 10)
			expect(hole.position).to.equal(Vector2.new(970, 0))
			expect(hole.size).to.equal(Vector2.new(30, 45))
		end)
	end)

	describe("shades", function()
		it("covers the whole screen except the hole, with no overlap", function()
			local hole = TrainingSpotlightUtils.hole(Vector2.new(400, 200), Vector2.new(100, 80), SCREEN, 0)
			local shades = TrainingSpotlightUtils.shades(hole, SCREEN)
			local total = 0
			for _, rect in shades do
				total += area(rect)
			end
			expect(total + area(hole)).to.equal(SCREEN.X * SCREEN.Y)
			expect(#shades).to.equal(4)
		end)

		it("leaves no gap above a hole at the top edge", function()
			local hole = TrainingSpotlightUtils.hole(Vector2.new(0, 0), Vector2.new(100, 80), SCREEN, 0)
			local shades = TrainingSpotlightUtils.shades(hole, SCREEN)
			expect(area(shades[1])).to.equal(0)
		end)
	end)

	describe("lineAt", function()
		it("puts the line under the hole when there is room", function()
			local hole = TrainingSpotlightUtils.hole(Vector2.new(400, 100), Vector2.new(100, 80), SCREEN, 0)
			local line = TrainingSpotlightUtils.lineAt(hole, SCREEN, Vector2.new(300, 60), 12)
			expect(line.Y).to.equal(192)
			expect(line.X).to.equal(300)
		end)

		it("puts the line above a hole near the bottom", function()
			local hole = TrainingSpotlightUtils.hole(Vector2.new(400, 500), Vector2.new(100, 80), SCREEN, 0)
			local line = TrainingSpotlightUtils.lineAt(hole, SCREEN, Vector2.new(300, 60), 12)
			expect(line.Y).to.equal(428)
		end)

		it("keeps the line inside the screen sideways", function()
			local hole = TrainingSpotlightUtils.hole(Vector2.new(950, 100), Vector2.new(50, 50), SCREEN, 0)
			local line = TrainingSpotlightUtils.lineAt(hole, SCREEN, Vector2.new(300, 60), 12)
			expect(line.X).to.equal(700)
		end)
	end)

	describe("edge", function()
		it("points straight down at a target on screen", function()
			local at, rotation, onEdge = TrainingSpotlightUtils.edge(Vector2.new(300, 200), true, SCREEN, 40)
			expect(at).to.equal(Vector2.new(300, 200))
			expect(rotation).to.equal(0)
			expect(onEdge).to.equal(false)
		end)

		it("sits on the right edge pointing right for a target off to the right", function()
			local at, rotation, onEdge = TrainingSpotlightUtils.edge(Vector2.new(2000, 300), true, SCREEN, 40)
			expect(at.X).to.equal(960)
			expect(at.Y).to.equal(300)
			expect(rotation).to.equal(-90)
			expect(onEdge).to.equal(true)
		end)

		it("mirrors a target behind the camera", function()
			local at, _, onEdge = TrainingSpotlightUtils.edge(Vector2.new(800, 300), false, SCREEN, 40)
			expect(onEdge).to.equal(true)
			expect(at.X < 500).to.equal(true)
		end)
	end)
end
