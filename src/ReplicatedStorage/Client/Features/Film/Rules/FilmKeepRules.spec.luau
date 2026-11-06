local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FilmKeepRules = require(script.Parent.FilmKeepRules)
local FilmConstants = require(ReplicatedStorage.Shared.Features.Film.Data.FilmConstants)
local UILayerConstants = require(ReplicatedStorage.Client.UI.Layers.UILayerConstants)

return function()
	describe("FilmKeepRules", function()
		it("always keeps the admin console, in every mode", function()
			expect(FilmKeepRules.keeps("Cmdr", "none")).to.equal(true)
			expect(FilmKeepRules.keeps("Cmdr", "screen")).to.equal(true)
		end)

		it("hides the open screen in the default mode", function()
			expect(FilmKeepRules.keeps(FilmConstants.SCREEN_LAYER_GUI, "none")).to.equal(false)
			expect(FilmKeepRules.keeps("UILayer_Hud", "none")).to.equal(false)
		end)

		it("keeps only the open screen's layer in screen mode, never the HUD", function()
			expect(FilmKeepRules.keeps(FilmConstants.SCREEN_LAYER_GUI, "screen")).to.equal(true)
			expect(FilmKeepRules.keeps("UILayer_Hud", "screen")).to.equal(false)
			expect(FilmKeepRules.keeps("UILayer_Overlay", "screen")).to.equal(false)
			expect(FilmKeepRules.keeps("SomeBillboard", "screen")).to.equal(false)
		end)

		it("names the real Panel layer root (results, Locker, reveal and the shop are Panel scenes)", function()
			expect(UILayerConstants.orderOf("Panel")).to.be.ok()
			expect(FilmConstants.SCREEN_LAYER_GUI).to.equal("UILayer_Panel")
		end)

		it("cycles between the two modes", function()
			expect(FilmKeepRules.nextMode("none")).to.equal("screen")
			expect(FilmKeepRules.nextMode("screen")).to.equal("none")
		end)
	end)
end
