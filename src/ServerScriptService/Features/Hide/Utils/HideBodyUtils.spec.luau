local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HideBodyUtils = require(script.Parent.HideBodyUtils)
local HideSpotUtils = require(ReplicatedStorage.Shared.Features.Hide.Utils.HideSpotUtils)

return function()
	-- A character model with a root part and a humanoid, not in the world.
	local function character(hipHeight, rootHeight)
		local model = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.new(2, rootHeight or 2, 1)
		root.Parent = model
		local humanoid = Instance.new("Humanoid")
		humanoid.HipHeight = hipHeight or 2
		humanoid.Parent = model
		return model, root, humanoid
	end

	-- A spot on a part high over the map (no floor anywhere under its exits), not in the world.
	local function spot(noun)
		local furniture = Instance.new("Part")
		furniture.Size = Vector3.new(5, 3, 3)
		local frame = CFrame.new(0, 5000, 0)
		furniture.CFrame = frame
		return { id = "spec", kind = "under", noun = noun, furniture = furniture, frame = frame, reach = {} }
	end

	describe("rootOf / humanoidOf", function()
		it("finds a player's root and humanoid", function()
			local model, root, humanoid = character()
			local player = { Character = model }
			expect(HideBodyUtils.rootOf(player)).to.equal(root)
			expect(HideBodyUtils.humanoidOf(player)).to.equal(humanoid)
			model:Destroy()
		end)

		it("is nil without a character", function()
			local player = { Character = nil }
			expect(HideBodyUtils.rootOf(player)).to.equal(nil)
			expect(HideBodyUtils.humanoidOf(player)).to.equal(nil)
		end)
	end)

	describe("standHeight", function()
		it("is the hip height plus half the root's height", function()
			local model, root, humanoid = character(2, 2)
			expect(HideBodyUtils.standHeight(root, humanoid)).to.be.near(3, 1e-6)
			model:Destroy()
		end)
	end)

	describe("hideFrame", function()
		it("keeps the fallback for a cabinet (no free space to hug in)", function()
			local fallback = CFrame.new(1, 2, 3)
			local model = character()
			expect(HideBodyUtils.hideFrame(spot("cabinet"), model, fallback)).to.equal(fallback)
			model:Destroy()
		end)

		it("keeps the fallback with no character to measure", function()
			local fallback = CFrame.new(1, 2, 3)
			expect(HideBodyUtils.hideFrame(spot("desk"), nil, fallback)).to.equal(fallback)
		end)

		it("keeps the fallback for furniture it does not know", function()
			local fallback = CFrame.new(4, 5, 6)
			expect(HideBodyUtils.hideFrame(spot("sofa"), nil, fallback)).to.equal(fallback)
		end)
	end)

	describe("exitFrame", function()
		it("falls back to where they went in when no exit has a floor under it", function()
			local model, root, humanoid = character()
			local entry = CFrame.new(0, 5000, -10)
			expect(HideBodyUtils.exitFrame(spot("desk"), root, humanoid, entry)).to.equal(entry)
			model:Destroy()
		end)

		it("falls back to the front exit with no entry and no floor", function()
			local model, root, humanoid = character()
			local s = spot("desk")
			local front = HideSpotUtils.frames(
				s.noun,
				s.frame,
				s.furniture.Size,
				HideBodyUtils.standHeight(root, humanoid)
			).exits[1]
			expect(HideBodyUtils.exitFrame(s, root, humanoid, nil)).to.equal(front)
			model:Destroy()
		end)
	end)
end
