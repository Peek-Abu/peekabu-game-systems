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
		expect(price.props.content.price.props.amount).to.equal("2,500")
		price.props.onActivated()
		expect(hired).to.equal("Cappy")
	end)
end
