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

	describe("offscreen", function()
		it("puts a target to the camera's left on the left edge, in front or behind", function()
			local front = TrainingSpotlightUtils.offscreen(Vector3.new(-50, 0, -10), SCREEN, 40)
			local behind = TrainingSpotlightUtils.offscreen(Vector3.new(-50, 0, 10), SCREEN, 40)
			expect(front.X).to.equal(40)
			expect(behind.X).to.equal(40)
		end)

		it("puts a target to the camera's right on the right edge, pointing right", function()
			local at, rotation = TrainingSpotlightUtils.offscreen(Vector3.new(50, 0, -10), SCREEN, 40)
			expect(at.X).to.equal(SCREEN.X - 40)
			expect(rotation).to.equal(-90)
		end)

		it("points down for a target straight behind (turn around)", function()
			local at, rotation = TrainingSpotlightUtils.offscreen(Vector3.new(0, 0, 10), SCREEN, 40)
			expect(at.Y).to.equal(SCREEN.Y - 40)
			expect(rotation).to.equal(0)
		end)
	end)

	describe("leftInset", function()
		it("keeps clear of a button column on the left side of the screen", function()
			local column = { position = Vector2.new(30, 180), size = Vector2.new(90, 360) }
			expect(TrainingSpotlightUtils.leftInset({ column }, SCREEN, 12)).to.equal(132)
		end)

		it("ignores buttons that are not on the left", function()
			local right = { position = Vector2.new(800, 100), size = Vector2.new(90, 90) }
			expect(TrainingSpotlightUtils.leftInset({ right }, SCREEN, 12)).to.equal(0)
		end)

		it("is 0 with nothing to avoid", function()
			expect(TrainingSpotlightUtils.leftInset({}, SCREEN, 12)).to.equal(0)
		end)
	end)

	describe("pinnedCoach", function()
		it("puts Pippa's card at the bottom left, just past the button column", function()
			local at = TrainingSpotlightUtils.pinnedCoach(SCREEN, Vector2.new(400, 120), 132, 16)
			expect(at.X).to.equal(148)
			expect(at.Y).to.equal(584)
		end)

		it("hugs the left edge when there is no button column", function()
			local at = TrainingSpotlightUtils.pinnedCoach(SCREEN, Vector2.new(400, 120), 0, 16)
			expect(at.X).to.equal(16)
			expect(at.Y).to.equal(584)
		end)

		it("keeps the whole card on the screen when the column leaves too little room", function()
			local at = TrainingSpotlightUtils.pinnedCoach(SCREEN, Vector2.new(400, 120), 800, 16)
			expect(at.X).to.equal(584)
		end)

		it("never goes past the left edge on a screen narrower than the card", function()
			local at = TrainingSpotlightUtils.pinnedCoach(Vector2.new(300, 600), Vector2.new(400, 120), 0, 16)
			expect(at.X).to.equal(0)
		end)

		it("on a phone sits centred at the top, clear of the thumbstick in the bottom left", function()
			local at = TrainingSpotlightUtils.pinnedCoach(Vector2.new(800, 400), Vector2.new(340, 110), 120, 8, true)
			expect(at.X).to.equal(230)
			expect(at.Y).to.equal(110 + TrainingSpotlightUtils.PHONE_TOP)
		end)
	end)

	describe("waits", function()
		it("waits behind an open page or an open popup (the Timecard on a first spawn)", function()
			expect(TrainingSpotlightUtils.waits(1, 0)).to.equal(true)
			expect(TrainingSpotlightUtils.waits(0, 1)).to.equal(true)
		end)

		it("shows when nothing is open over the hub", function()
			expect(TrainingSpotlightUtils.waits(0, 0)).to.equal(false)
		end)
	end)
end
