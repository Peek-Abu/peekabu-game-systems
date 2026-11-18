local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UISoundFormulas = require(script.Parent.UISoundFormulas)
local UIAssets = require(ReplicatedStorage.Client.Features.UI.Data.UIAssets)

return function()
	describe("buttonTier", function()
		it("gives a button the tier its caller names", function()
			expect(UISoundFormulas.buttonTier("go", "cta")).to.equal("cta")
			expect(UISoundFormulas.buttonTier("secondary", "back")).to.equal("back")
			expect(UISoundFormulas.buttonTier("primary", "click")).to.equal("click")
		end)

		it("defaults by look: filled action buttons confirm, the rest click", function()
			expect(UISoundFormulas.buttonTier("go", nil)).to.equal("confirm")
			expect(UISoundFormulas.buttonTier("primary", nil)).to.equal("confirm")
			expect(UISoundFormulas.buttonTier("danger", nil)).to.equal("confirm")
			expect(UISoundFormulas.buttonTier("secondary", nil)).to.equal("click")
			expect(UISoundFormulas.buttonTier("prop", nil)).to.equal("click")
			expect(UISoundFormulas.buttonTier("surface", nil)).to.equal("click")
		end)
	end)

	describe("pressTier", function()
		it("plays the button's tier, or the error when it is disabled", function()
			expect(UISoundFormulas.pressTier("cta", false)).to.equal("cta")
			expect(UISoundFormulas.pressTier("confirm", true)).to.equal("error")
		end)
	end)

	describe("hovers", function()
		it("hovers an enabled button that has a pointer look", function()
			expect(UISoundFormulas.hovers("primary", false)).to.equal(true)
			expect(UISoundFormulas.hovers("prop", false)).to.equal(true)
		end)

		it("stays quiet over a disabled button and the touch surfaces", function()
			expect(UISoundFormulas.hovers("primary", true)).to.equal(false)
			expect(UISoundFormulas.hovers("surface", false)).to.equal(false)
		end)
	end)

	describe("prompts", function()
		it("fits the wind-up to the hold: PlaybackSpeed = 1 / HoldDuration", function()
			expect(UISoundFormulas.holdSpeed(1)).to.equal(1)
			expect(UISoundFormulas.holdSpeed(0.8)).to.be.near(1.25, 1e-9)
			expect(UISoundFormulas.holdSpeed(2)).to.equal(0.5)
		end)

		it("has no wind-up for a tap prompt", function()
			expect(UISoundFormulas.holdSpeed(0)).to.equal(nil)
		end)

		it("keeps an extreme hold within the speed range", function()
			expect(UISoundFormulas.holdSpeed(0.05)).to.equal(UISoundFormulas.MAX_SPEED)
			expect(UISoundFormulas.holdSpeed(100)).to.equal(UISoundFormulas.MIN_SPEED)
		end)

		it("completes a CTA prompt with the CTA, any other hold with the done sound", function()
			local cta = { "shift-clockout" }
			expect(UISoundFormulas.doneTier("shift-clockout", cta)).to.equal("cta")
			expect(UISoundFormulas.doneTier("cargo-search", cta)).to.equal("done")
			expect(UISoundFormulas.doneTier(nil, cta)).to.equal("done")
		end)
	end)

	describe("scenes", function()
		it("plays the open when a scene is pushed (the stack grows)", function()
			expect(UISoundFormulas.stackTier(0, 1)).to.equal("open")
			expect(UISoundFormulas.stackTier(1, 2)).to.equal("open")
		end)

		it("plays nothing when the stack shrinks or stays (back / close buttons play their own)", function()
			expect(UISoundFormulas.stackTier(2, 1)).to.equal(nil)
			expect(UISoundFormulas.stackTier(1, 0)).to.equal(nil)
			expect(UISoundFormulas.stackTier(1, 1)).to.equal(nil)
		end)

		-- Owner 11-16: no menu swipe when the Locker cutscene starts (its Open button plays the buy instead).
		it("stays quiet when the scene pushed opens quietly", function()
			expect(UISoundFormulas.stackTier(1, 2, true)).to.equal(nil)
			expect(UISoundFormulas.stackTier(1, 2, false)).to.equal("open")
		end)
	end)

	-- Owner tryout round 3 (2026-11-17): the emote and chat wheels open with their own paper-fan flick, not the menu
	-- swipe (their scenes open quietly; their service clients play this tier).
	describe("wheels", function()
		it("opens a wheel with its own tier, mapped to the wheel's sound", function()
			expect(UISoundFormulas.wheelOpen()).to.equal("wheel")
			expect(UIAssets.soundTiers[UISoundFormulas.wheelOpen()]).to.equal("uiWheelOpen")
			expect(UIAssets.sounds.uiWheelOpen).to.be.ok()
		end)
	end)

	describe("buying", function()
		it("plays the purchase when a buy goes through (an empty reason)", function()
			expect(UISoundFormulas.buyTier("")).to.equal("purchase")
		end)

		it("plays the error when a buy is refused", function()
			expect(UISoundFormulas.buyTier("short")).to.equal("error")
			expect(UISoundFormulas.buyTier("owned")).to.equal("error")
		end)
	end)

	-- Owner pick 2026-11-17 ("For legendary purchase - orchestra hit style!"): a buy whose top rarity is Legendary plays
	-- an extra sting on top of the purchase; the other rarities have no extra yet (a data change in UIAssets.buySounds).
	describe("buy extras", function()
		it("plays the Legendary sting for a Legendary buy that went through", function()
			expect(UISoundFormulas.buyExtra("", "legendary", UIAssets.buySounds)).to.equal("shopBuyLegendary")
			expect(UIAssets.sounds.shopBuyLegendary).to.be.ok()
			expect(UIAssets.sounds.shopBuyLegendary.bus).to.equal("Reward")
		end)

		it("plays no extra for a refused buy", function()
			expect(UISoundFormulas.buyExtra("short", "legendary", UIAssets.buySounds)).to.equal(nil)
			expect(UISoundFormulas.buyExtra("owned", "legendary", UIAssets.buySounds)).to.equal(nil)
		end)

		it("plays no extra for the other rarities yet, or an unknown one", function()
			for _, rarity in { "default", "uncommon", "rare", "epic", "odd" } do
				expect(UISoundFormulas.buyExtra("", rarity, UIAssets.buySounds)).to.equal(nil)
			end
			expect(UISoundFormulas.buyExtra("", nil, UIAssets.buySounds)).to.equal(nil)
		end)

		it("follows the rarity map it is given", function()
			expect(UISoundFormulas.buyExtra("", "epic", { epic = "someEpicSting" })).to.equal("someEpicSting")
		end)
	end)
end
