local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticConstants = require(ReplicatedStorage.Shared.Features.Cosmetic.Data.CosmeticConstants)
local CosmeticRules = require(ReplicatedStorage.Shared.Features.Cosmetic.Rules.CosmeticRules)
local InventoryCrewPanel = require(script.Parent.InventoryCrewPanel)
local VM = require(script.Parent.InventoryViewModel)
local ToonButton = require(script.Parent.Parent.Toon.ToonButton)

return function()
	it("opens the hire flow when the locked Cappy price is activated", function()
		local hired = nil
		local panel = InventoryCrewPanel({
			cards = VM.crew(CosmeticConstants.defaultLoadout(), function(id)
				return CosmeticRules.owns({ owned = {} }, id)
			end),
			layout = VM.layout(Vector2.new(1920, 1080), false),
			onHire = function(id)
				hired = id
			end,
			onEquip = function() end,
			onOpen = function() end,
		})
		local price = panel.props.children.Cappy.props.children.surface.props.children.price
		expect(price.type).to.equal(ToonButton)
		expect(price.props.content.price.props.amount).to.equal("5,000")
		price.props.onActivated()
		expect(hired).to.equal("Cappy")
	end)
	-- Owner pick 2026-11-15 (Option 2): nothing over a portrait; the hire tag sits on the card's top-right corner,
	-- where the wearer's "You!" flag sits.
	local function panel(phone)
		return InventoryCrewPanel({
			cards = VM.crew(CosmeticConstants.defaultLoadout(), function(id)
				return CosmeticRules.owns({ owned = {} }, id)
			end),
			layout = VM.layout(if phone then Vector2.new(844, 390) else Vector2.new(1920, 1080), phone),
			onHire = function() end,
			onEquip = function() end,
			onOpen = function() end,
		})
	end

	it("puts nothing over a locked employee's portrait", function()
		for _, phone in { false, true } do
			local cappy = panel(phone).props.children.Cappy
			local window = cappy.props.children.surface.props.children.window
			for key in window.props.children do
				expect(key == "lock" or key == "tag").to.equal(false)
			end
		end
	end)

	it("hangs the hire tag on the top-right corner of a locked card, like the You! flag", function()
		for _, phone in { false, true } do
			local children = panel(phone).props.children
			local tag = children.Cappy.props.children.tag
			expect(tag).never.to.equal(nil)
			local frame = VM.crewTagFrame(phone)
			expect(tag.props.position).to.equal(frame.position)
			expect(frame.anchor).to.equal(Vector2.new(1, 0))
			expect(frame.position.X.Scale).to.equal(1)
			expect(frame.position.Y.Scale).to.equal(0)
			-- At the very top: over the card body's top edge (12 px down) and the window's corner, never lower.
			expect(frame.position.Y.Offset <= 4).to.equal(true)
			expect(frame.size <= (if phone then 40 else 64)).to.equal(true)
			expect(children.Pippa.props.children.tag).to.equal(nil)
		end
	end)
end
