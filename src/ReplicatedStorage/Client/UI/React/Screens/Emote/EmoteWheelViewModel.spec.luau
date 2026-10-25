local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticConstants = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticConstants)
local CosmeticRegistry = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticRegistry)
local VM = require(script.Parent.EmoteWheelViewModel)

return function()
	local function owner(ids)
		local set = {}
		for _, id in ids or {} do
			set[id] = true
		end
		return function(id)
			local item = CosmeticRegistry.get(id)
			return item ~= nil and (item.source == "default" or set[id] == true)
		end
	end

	it("shows the current employee's 4 slots: the free emote in slot 1, the rest empty", function()
		local view = VM.view(CosmeticConstants.defaultLoadout(), owner())
		expect(view.employee).to.equal("Pippa")
		expect(#view.slots).to.equal(4)
		expect(view.slots[1].name).to.equal("Big Wave")
		expect(view.slots[1].empty).to.equal(false)
		expect(view.slots[2].empty).to.equal(true)
		expect(view.slots[2].name).to.equal("Empty")
	end)

	it("follows the employee you play and flags a clip not made yet", function()
		local loadout = CosmeticConstants.defaultLoadout()
		loadout.current = "Cappy"
		local view = VM.view(loadout, owner({ "Cappy" }))
		expect(view.employee).to.equal("Cappy")
		expect(view.slots[1].id).to.equal("Cappy.FistBump")
		expect(view.slots[1].comingSoon).to.equal(true)
	end)

	it("lays the slots round a circle, slot 1 at the top, clockwise", function()
		local top = VM.position(1, 4, 100)
		local right = VM.position(2, 4, 100)
		expect(math.abs(top.X) < 0.001 and math.abs(top.Y + 100) < 0.001).to.equal(true)
		expect(math.abs(right.X - 100) < 0.001 and math.abs(right.Y) < 0.001).to.equal(true)
	end)

	it("picks the slot the pointer leans toward, none inside the middle", function()
		expect(VM.pick(Vector2.new(0, -80), 4, 30)).to.equal(1)
		expect(VM.pick(Vector2.new(80, 5), 4, 30)).to.equal(2)
		expect(VM.pick(Vector2.new(0, 90), 4, 30)).to.equal(3)
		expect(VM.pick(Vector2.new(-70, -10), 4, 30)).to.equal(4)
		expect(VM.pick(Vector2.new(5, 5), 4, 30)).never.to.be.ok()
	end)
end
