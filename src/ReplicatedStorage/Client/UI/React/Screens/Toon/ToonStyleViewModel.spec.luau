local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)
local VM = require(script.Parent.ToonStyleViewModel)

local MOTION = UIToonConstants.MOTION
local DEPTH = UIToonConstants.DEPTH

local function state(overrides)
	local base = { hovered = false, pressed = false, selected = false, disabled = false, receded = false }
	for key, value in overrides do
		base[key] = value
	end
	return base
end

return function()
	describe("pose", function()
		it("rests with the full hard drop and no ring", function()
			local pose = VM.pose(state({}))
			expect(pose.lift).to.equal(0)
			expect(pose.scale).to.equal(1)
			expect(pose.drop).to.equal(DEPTH.drop)
			expect(pose.ring).to.equal(0)
		end)

		it("lifts and grows on hover, with the drop growing under it", function()
			local pose = VM.pose(state({ hovered = true }))
			expect(pose.lift).to.equal(MOTION.hoverLift)
			expect(pose.scale).to.equal(MOTION.hoverScale)
			expect(pose.drop).to.equal(DEPTH.drop + MOTION.hoverLift)
		end)

		it("drops onto its shadow when pressed: the drop and lip collapse", function()
			local pose = VM.pose(state({ hovered = true, pressed = true }))
			expect(pose.lift < 0).to.equal(true)
			expect(pose.drop < DEPTH.drop and pose.drop > 0).to.equal(true)
			expect(pose.scale).to.equal(MOTION.pressScale)
			expect(pose.lip < 1).to.equal(true)
		end)

		it("lifts, grows and rings in lilac when selected", function()
			local pose = VM.pose(state({ selected = true }))
			expect(pose.lift).to.equal(MOTION.selectedLift)
			expect(pose.scale).to.equal(MOTION.selectedScale)
			expect(pose.ring).to.equal(1)
		end)

		it("keeps the ring while a selected item is hovered or pressed", function()
			expect(VM.pose(state({ selected = true, hovered = true })).ring).to.equal(1)
			expect(VM.pose(state({ selected = true, pressed = true })).ring).to.equal(1)
		end)

		it("leaves the hard drop where it was: the body moves, its shadow does not", function()
			for _, overrides in { {}, { hovered = true }, { pressed = true }, { selected = true } } do
				local pose = VM.pose(state(overrides))
				expect(pose.drop).to.equal(DEPTH.drop + pose.lift)
			end
		end)

		it("recedes the unselected siblings", function()
			local pose = VM.pose(state({ receded = true }))
			expect(pose.scale).to.equal(MOTION.recedeScale)
			expect(pose.dim > 0).to.equal(true)
		end)

		it("ignores hover and press while disabled", function()
			local pose = VM.pose(state({ disabled = true, hovered = true, pressed = true, selected = true }))
			expect(pose.lift).to.equal(0)
			expect(pose.scale).to.equal(1)
			expect(pose.ring).to.equal(0)
		end)
	end)

	describe("blend", function()
		it("runs from one pose to the next", function()
			local rest = VM.pose(state({}))
			local hover = VM.pose(state({ hovered = true }))
			expect(VM.blend(rest, hover, 0).lift).to.equal(rest.lift)
			expect(VM.blend(rest, hover, 1).scale).to.equal(hover.scale)
			local half = VM.blend(rest, hover, 0.5)
			expect(half.lift).to.equal((rest.lift + hover.lift) / 2)
			expect(half.drop).to.equal((rest.drop + hover.drop) / 2)
		end)
	end)

	describe("hue", function()
		it("maps each variant to its palette colour", function()
			expect(VM.hue("primary", false)).to.equal("mint")
			expect(VM.hue("gleam", false)).to.equal("gold")
			expect(VM.hue("danger", false)).to.equal("coral")
			expect(VM.hue("secondary", false)).to.equal("cream")
			expect(VM.hue("grape", false)).to.equal("grape")
		end)

		it("greys any variant out when disabled", function()
			expect(VM.hue("primary", true)).to.equal("steel")
			expect(VM.hue("gleam", true)).to.equal("steel")
		end)

		it("writes ink on light faces and white on dark ones", function()
			expect(VM.textOn("cream")).to.equal("ink")
			expect(VM.textOn("gold")).to.equal("white")
			expect(VM.textOn("night")).to.equal("white")
		end)
	end)

	describe("text depth", function()
		it("scales the stroke and drop with the text, within bounds", function()
			expect(VM.stroke(30)).to.equal(4)
			expect(VM.stroke(100)).to.equal(12)
			expect(VM.stroke(4)).to.equal(2)
			expect(VM.drop(60)).to.equal(5)
			expect(VM.drop(10)).to.equal(2)
			expect(VM.drop(300)).to.equal(8)
		end)
	end)

	describe("grouped", function()
		it("writes whole numbers with thousands commas", function()
			expect(VM.grouped(0)).to.equal("0")
			expect(VM.grouped(950)).to.equal("950")
			expect(VM.grouped(1240)).to.equal("1,240")
			expect(VM.grouped(1234567)).to.equal("1,234,567")
		end)

		it("rounds down fractions and clamps a negative or broken value to 0", function()
			expect(VM.grouped(12.9)).to.equal("12")
			expect(VM.grouped(-5)).to.equal("0")
			expect(VM.grouped(0 / 0)).to.equal("0")
		end)
	end)
end
