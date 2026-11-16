local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIToonConstants = require(ReplicatedStorage.Client.UI.React.Screens.Toon.UIToonConstants)
local ToonViewportPlatform = require(script.Parent.ToonViewportPlatform)

return function()
	-- A model 10 studs tall, 1 stud wide, its feet at y = 0.
	local bounds = { min = Vector3.new(0, 0, 0), max = Vector3.new(1, 10, 1) }
	local colors = { top = Color3.fromRGB(255, 0, 0), side = Color3.fromRGB(0, 0, 255) }

	describe("platformFor", function()
		it("builds a Platform model of four slabs: Top, Rim, Side and Foot", function()
			local model = ToonViewportPlatform.platformFor(bounds, colors)
			expect(model.Name).to.equal("Platform")
			expect(#model:GetChildren()).to.equal(4)
			for _, name in { "Top", "Rim", "Side", "Foot" } do
				local part = model:FindFirstChild(name)
				expect(part).to.be.ok()
				expect(part:IsA("Part")).to.equal(true)
				expect(part.Anchored).to.equal(true)
				expect(part.CanCollide).to.equal(false)
			end
			model:Destroy()
		end)

		it("paints the top and side in the given colours, the rim and foot in ink", function()
			local model = ToonViewportPlatform.platformFor(bounds, colors)
			expect(model.Top.Color:ToHex()).to.equal(colors.top:ToHex())
			expect(model.Side.Color:ToHex()).to.equal(colors.side:ToHex())
			expect(model.Rim.Color:ToHex()).to.equal(UIToonConstants.COLOR.ink:ToHex())
			expect(model.Foot.Color:ToHex()).to.equal(UIToonConstants.COLOR.ink:ToHex())
			model:Destroy()
		end)

		it("grows the bounds down under the platform and out to its rim, keeping the top", function()
			local model, grown = ToonViewportPlatform.platformFor(bounds, colors)
			-- height 0.7 (7% of 10) plus a 0.084 ink line below the feet.
			expect(grown.min.Y).to.be.near(-0.784, 1e-6)
			expect(grown.max.Y).to.equal(10)
			-- The foot reaches 3.57 (34% of 10, times 1.05) from the centre (0.5).
			expect(grown.min.X).to.be.near(0.5 - 3.57, 1e-6)
			expect(grown.max.X).to.be.near(0.5 + 3.57, 1e-6)
			expect(grown.min.Z).to.be.near(0.5 - 3.57, 1e-6)
			expect(grown.max.Z).to.be.near(0.5 + 3.57, 1e-6)
			model:Destroy()
		end)

		it("keeps a model wider than the platform as it is", function()
			local wide = { min = Vector3.new(-10, 0, -10), max = Vector3.new(10, 10, 10) }
			local model, grown = ToonViewportPlatform.platformFor(wide, colors)
			expect(grown.min.X).to.equal(-10)
			expect(grown.max.X).to.equal(10)
			expect(grown.min.Z).to.equal(-10)
			expect(grown.max.Z).to.equal(10)
			model:Destroy()
		end)
	end)
end
