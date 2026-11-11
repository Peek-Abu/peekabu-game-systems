local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OccupantHeadRules = require(script.Parent.OccupantHeadRules)
local C = require(ReplicatedStorage.Shared.Features.Occupant.Data.OccupantConstants)

local SWAP = C.HEAD_SWAP_SECONDS

-- Crew member `userId` `distance` studs down +X from the monster at the origin.
local function member(userId, distance, extra)
	local value = { userId = userId, position = Vector3.new(distance, 0, 0), hidden = false, noticed = true }
	for key, item in extra or {} do
		value[key] = item
	end
	return value
end

local function input(crew, watched, now, brainTarget)
	return {
		position = Vector3.zero,
		crew = crew,
		watched = watched,
		now = now,
		brainTarget = brainTarget,
		swapSeconds = SWAP,
	}
end

return function()
	describe("the target", function()
		it("is the brain's chase or search target when it has one", function()
			local head = OccupantHeadRules.advance(
				OccupantHeadRules.newHead(),
				input({ member(1, 5), member(2, 20) }, false, 0, 2)
			)
			expect(head.target).to.equal(2)
		end)

		it("else the nearest crew member it saw or heard", function()
			local head = OccupantHeadRules.advance(
				OccupantHeadRules.newHead(),
				input({ member(1, 30), member(2, 10), member(3, 4, { noticed = false }) }, false, 0, nil)
			)
			expect(head.target).to.equal(2)
		end)

		it("is nobody when it saw or heard nobody", function()
			local head = OccupantHeadRules.advance(
				OccupantHeadRules.newHead(),
				input({ member(1, 5, { noticed = false }) }, false, 0, nil)
			)
			expect(head.target).to.equal(nil)
		end)

		it("never a hidden crew member, even its own target", function()
			local head = OccupantHeadRules.advance(
				OccupantHeadRules.newHead(),
				input({ member(1, 5, { hidden = true }), member(2, 20) }, false, 0, 1)
			)
			expect(head.target).to.equal(2)
		end)

		it("ignores a brain target who is not in the crew any more", function()
			local head = OccupantHeadRules.advance(OccupantHeadRules.newHead(), input({ member(2, 20) }, false, 0, 9))
			expect(head.target).to.equal(2)
		end)
	end)

	describe("the 10 s swap", function()
		local crew = { member(1, 5), member(2, 10), member(3, 30) }

		it("keeps its target while watched under 10 s", function()
			local head = OccupantHeadRules.advance(OccupantHeadRules.newHead(), input(crew, true, 100, 1))
			head = OccupantHeadRules.advance(head, input(crew, true, 100 + SWAP - 0.1, 1))
			expect(head.target).to.equal(1)
		end)

		it("swaps to the next nearest crew member after 10 s of non-stop watching", function()
			local head = OccupantHeadRules.advance(OccupantHeadRules.newHead(), input(crew, true, 100, 1))
			head = OccupantHeadRules.advance(head, input(crew, true, 100 + SWAP, 1))
			expect(head.target).to.equal(2)
			head = OccupantHeadRules.advance(head, input(crew, true, 100 + SWAP + 1, 1))
			expect(head.target).to.equal(2)
		end)

		it("swaps again 10 s later, never to the one it looks at", function()
			local head = OccupantHeadRules.advance(OccupantHeadRules.newHead(), input(crew, true, 100, 1))
			head = OccupantHeadRules.advance(head, input(crew, true, 100 + SWAP, 1))
			head = OccupantHeadRules.advance(head, input(crew, true, 100 + 2 * SWAP, 1))
			expect(head.target).to.equal(1)
		end)

		it("swaps to anyone not hidden, even someone it never noticed", function()
			local two = { member(1, 5), member(2, 10, { noticed = false }) }
			local head = OccupantHeadRules.advance(OccupantHeadRules.newHead(), input(two, true, 100, 1))
			head = OccupantHeadRules.advance(head, input(two, true, 100 + SWAP, 1))
			expect(head.target).to.equal(2)
		end)

		it("never swaps to a hidden crew member", function()
			local two = { member(1, 5), member(2, 10, { hidden = true }) }
			local head = OccupantHeadRules.advance(OccupantHeadRules.newHead(), input(two, true, 100, 1))
			head = OccupantHeadRules.advance(head, input(two, true, 100 + SWAP, 1))
			expect(head.target).to.equal(1)
		end)

		it("keeps the same kid in solo play", function()
			local solo = { member(1, 5) }
			local head = OccupantHeadRules.advance(OccupantHeadRules.newHead(), input(solo, true, 100, 1))
			head = OccupantHeadRules.advance(head, input(solo, true, 100 + SWAP, 1))
			expect(head.target).to.equal(1)
			head = OccupantHeadRules.advance(head, input(solo, true, 100 + 2 * SWAP, 1))
			expect(head.target).to.equal(1)
		end)

		it("starts the 10 s again when the watching stops, back on the brain's target", function()
			local head = OccupantHeadRules.advance(OccupantHeadRules.newHead(), input(crew, true, 100, 1))
			head = OccupantHeadRules.advance(head, input(crew, true, 100 + SWAP, 1))
			expect(head.target).to.equal(2)
			head = OccupantHeadRules.advance(head, input(crew, false, 100 + SWAP + 1, 1))
			expect(head.target).to.equal(1)
			expect(head.watchedSince).to.equal(nil)
			head = OccupantHeadRules.advance(head, input(crew, true, 100 + SWAP + 2, 1))
			head = OccupantHeadRules.advance(head, input(crew, true, 100 + 2 * SWAP + 1, 1))
			expect(head.target).to.equal(1)
		end)

		it("drops a swapped target who hides, back on the brain's target", function()
			local head = OccupantHeadRules.advance(OccupantHeadRules.newHead(), input(crew, true, 100, 1))
			head = OccupantHeadRules.advance(head, input(crew, true, 100 + SWAP, 1))
			expect(head.target).to.equal(2)
			local hid = { member(1, 5), member(2, 10, { hidden = true }), member(3, 30) }
			head = OccupantHeadRules.advance(head, input(hid, true, 100 + SWAP + 1, 1))
			expect(head.target).to.equal(1)
		end)

		it("never changes the head it is given", function()
			local head = OccupantHeadRules.advance(OccupantHeadRules.newHead(), input(crew, true, 100, 1))
			OccupantHeadRules.advance(head, input(crew, true, 100 + SWAP, 1))
			expect(head.target).to.equal(1)
		end)
	end)
end
