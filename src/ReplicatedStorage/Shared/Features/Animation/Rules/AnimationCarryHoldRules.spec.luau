local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage.Shared.Features.Animation.Rules.AnimationCarryHoldRules)
return function()
	-- A carrier with 1-stud arms (shoulders 1.15 above the root), a 0.4-long hand and a head from 1.45 to 3.45.
	local function arm(side)
		local palm =
			CFrame.fromMatrix(Vector3.new(0, -0.15, 0), Vector3.new(0, 0, side), -Vector3.yAxis, -Vector3.xAxis * side)
		return {
			side = side,
			shoulder = Vector3.new(side * 0.45, 1.15, 0),
			upperRest = CFrame.new(side * 0.7, 1.15, 0),
			lowerRest = CFrame.new(side * 1.2, 1.15, 0),
			handRest = CFrame.new(side * 1.65, 1.15, 0),
			shoulderInUpper = Vector3.new(-side * 0.25, 0, 0),
			elbowInUpper = Vector3.new(side * 0.25, 0, 0),
			elbowInLower = Vector3.new(-side * 0.25, 0, 0),
			wristInLower = Vector3.new(side * 0.25, 0, 0),
			wristInHand = Vector3.new(-side * 0.2, 0, 0),
			palmInHand = palm,
			gripInHand = palm.Rotation,
			handLength = 0.4,
		}
	end
	local rig = {
		right = arm(1),
		left = arm(-1),
		front = -0.7,
		headFront = -1,
		headBottom = 1.45,
		headTop = 3.45,
		floor = -1.4,
		torsoHalfWidth = 0.6,
		body = {},
		head = {},
	}
	local function item(size, weight, handle, override)
		return { size = size, weight = weight, handle = handle == true, override = override }
	end

	it("pushes anything as heavy as furniture, and only pushes it", function()
		local order = Rules.choose(item(Vector3.new(2.2, 5, 2.3), 10), rig)
		expect(#order).to.equal(1)
		expect(order[1]).to.equal("push")
	end)

	it("offers one hand first for a light item with a handle or a side a hand closes round", function()
		expect(Rules.choose(item(Vector3.new(1.8, 2, 1.3), 1.5, true), rig)[1]).to.equal("hand")
		expect(Rules.choose(item(Vector3.new(0.36, 0.4, 0.16), 1.5), rig)[1]).to.equal("hand")
		-- Under it next: a bag too big to hang clear is held from below instead.
		expect(Rules.choose(item(Vector3.new(1.8, 2, 1.3), 1.5, true), rig)[2]).to.equal("under")
	end)

	it("holds everything else from below first: a light box with no handle, a medium monitor", function()
		expect(Rules.choose(item(Vector3.new(2, 1.6, 1.7), 1.5), rig)[1]).to.equal("under")
		expect(Rules.choose(item(Vector3.new(2.5, 2, 0.8), 4), rig)[1]).to.equal("under")
	end)

	it("pushes a heavy item first when lifting it would hide the carrier's eyes, else lifts it", function()
		-- Carried with the palms ~0.78 below the shoulders: a 3-stud jug's top at ~3.35, past the head's middle (2.45).
		expect(Rules.choose(item(Vector3.new(3, 3, 2.2), 7), rig)[1]).to.equal("push")
		expect(Rules.choose(item(Vector3.new(3, 3, 2.2), 7), rig)[2]).to.equal("under")
		-- A 1.5-stud printer rides lower than that: lifted.
		expect(Rules.choose(item(Vector3.new(2.9, 1.5, 3), 7), rig)[1]).to.equal("under")
	end)

	it("always ends with push as the last resort", function()
		local order = Rules.choose(item(Vector3.new(2, 1.6, 1.7), 1.5), rig)
		expect(order[#order]).to.equal("push")
	end)

	it("tries the art's own CarryHold first, then the rules' order", function()
		local order = Rules.choose(item(Vector3.new(2, 1.6, 1.7), 1.5, false, "push"), rig)
		expect(order[1]).to.equal("push")
		expect(order[2]).to.equal("under")
		expect(#order).to.equal(2)
	end)

	it("reads a CarryHold attribute value, ignoring anything else", function()
		expect(Rules.style("hand")).to.equal("hand")
		expect(Rules.style("under")).to.equal("under")
		expect(Rules.style("push")).to.equal("push")
		expect(Rules.style("cart")).to.equal(nil)
		expect(Rules.style(3)).to.equal(nil)
		expect(Rules.style(nil)).to.equal(nil)
	end)

	it("judges a grasp by the item's narrower level side against the hand", function()
		expect(Rules.graspable(item(Vector3.new(0.6, 1, 2), 1), rig)).to.equal(true)
		expect(Rules.graspable(item(Vector3.new(0.7, 1, 2), 1), rig)).to.equal(false)
		expect(Rules.graspable(item(Vector3.new(2, 1, 2), 1, true), rig)).to.equal(true)
	end)

	it("pushes instead a heavy item whose planned lift would hide the eyes, and keeps any other lift", function()
		local heavy = item(Vector3.new(3, 1.9, 1.8), 7)
		-- The head runs 1.45 to 3.45 above the root: its middle is 1 above the chin.
		expect(Rules.instead(heavy, "under", 1.2, rig)).to.equal("push")
		expect(Rules.instead(heavy, "under", 0.8, rig)).to.equal(nil)
		expect(Rules.instead(item(Vector3.new(2.5, 2, 0.8), 4), "under", 1.3, rig)).to.equal(nil)
		expect(Rules.instead(heavy, "push", 1.2, rig)).to.equal(nil)
		expect(Rules.instead(item(Vector3.new(3, 1.9, 1.8), 7, false, "under"), "under", 1.2, rig)).to.equal(nil)
	end)
end
