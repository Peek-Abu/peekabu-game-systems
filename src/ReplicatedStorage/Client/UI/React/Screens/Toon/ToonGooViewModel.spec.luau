local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)
local VM = require(script.Parent.ToonGooViewModel)

local GOO = UIToonConstants.GOO

local function visibleStart(run, kind)
	local first = run.pieces[1]
	local start = if kind == "cap" then GOO.capLeftStart else GOO.poolLeftStart
	return first.x + start * run.scale
end

local function visibleEnd(run, kind)
	local last = run.pieces[#run.pieces]
	local stop = if kind == "cap" then GOO.capRightEnd else GOO.poolRightEnd
	return last.x + stop * run.scale
end

return function()
	describe("a goo run along an edge", function()
		it("starts and stops exactly where it is asked to (never past the component's corner)", function()
			for _, kind in { "cap", "pool" } do
				local run = VM.run(kind, 26, 574)
				expect(math.abs(visibleStart(run, kind) - 26) < 0.01).to.equal(true)
				expect(math.abs(visibleEnd(run, kind) - 574) < 0.01).to.equal(true)
			end
		end)

		it("is an end, whole tiles in proportion and an end, close to the requested scale", function()
			for _, span in { 300, 517, 974, 1400 } do
				local run = VM.run("cap", 26, 26 + span)
				expect(run.pieces[1].image).to.equal("ends")
				expect(run.pieces[#run.pieces].image).to.equal("ends")
				for index = 2, #run.pieces - 1 do
					local piece = run.pieces[index]
					expect(piece.image).to.equal("tile")
					expect(math.abs(piece.width - (GOO.tile * run.scale + 1)) < 0.001).to.equal(true)
				end
				expect(run.scale > 0.8 and run.scale <= 1.2).to.equal(true)
			end
		end)

		it("leaves no gap between neighbouring pieces", function()
			local run = VM.run("pool", 30, 731)
			for index = 2, #run.pieces do
				local before = run.pieces[index - 1]
				local piece = run.pieces[index]
				expect(piece.x <= before.x + before.width + 0.001).to.equal(true)
			end
		end)

		it("shrinks the goo on a short edge rather than overlapping its ends", function()
			local run = VM.run("cap", 20, 120)
			expect(run.scale < 1).to.equal(true)
			expect(#run.pieces).to.equal(2)
			expect(math.abs(visibleStart(run, "cap") - 20) < 0.01).to.equal(true)
			expect(math.abs(visibleEnd(run, "cap") - 120) < 0.01).to.equal(true)
		end)

		it("honours a smaller requested scale and reports the run's drawn height", function()
			local run = VM.run("cap", 0, 600, 0.6)
			expect(run.scale > 0.5 and run.scale < 0.7).to.equal(true)
			expect(run.height).to.equal(GOO.capHeight * run.scale)
			local pool = VM.run("pool", 0, 600)
			expect(pool.height).to.equal(GOO.poolHeight * pool.scale)
		end)

		it("picks each end's cell from the atlas", function()
			local cap = VM.run("cap", 0, 600)
			expect(cap.pieces[1].rectOffset).to.equal(Vector2.new(0, GOO.capRow))
			expect(cap.pieces[#cap.pieces].rectOffset).to.equal(Vector2.new(256, GOO.capRow))
			local pool = VM.run("pool", 0, 600)
			expect(pool.pieces[1].rectOffset).to.equal(Vector2.new(0, GOO.poolRow))
			expect(pool.pieces[1].rectSize).to.equal(Vector2.new(256, 80))
		end)

		it("draws nothing for an empty or inverted span", function()
			expect(#VM.run("cap", 100, 100).pieces).to.equal(0)
			expect(#VM.run("cap", 200, 100).pieces).to.equal(0)
		end)
	end)

	describe("inset", function()
		it("keeps the goo off a component's rounded corners", function()
			local from, to = VM.inset(400, 26)
			expect(from).to.equal(26)
			expect(to).to.equal(374)
		end)
	end)
end
