local UIGamepadRules = require(script.Parent.UIGamepadRules)

local function hosted(scene, key)
	return { scene = scene, screen = { key = key } }
end

return function()
	describe("isGamepad", function()
		it("is true for every gamepad and false for keyboard, mouse and touch", function()
			expect(UIGamepadRules.isGamepad(Enum.UserInputType.Gamepad1)).to.equal(true)
			expect(UIGamepadRules.isGamepad(Enum.UserInputType.Gamepad4)).to.equal(true)
			expect(UIGamepadRules.isGamepad(Enum.UserInputType.Keyboard)).to.equal(false)
			expect(UIGamepadRules.isGamepad(Enum.UserInputType.MouseButton1)).to.equal(false)
			expect(UIGamepadRules.isGamepad(Enum.UserInputType.Touch)).to.equal(false)
		end)
	end)

	describe("targetFrame", function()
		it("names the top scene's first panel screen the way SceneHost keys it", function()
			local stack = { "shop", "reveal" }
			local screens = { hosted("shop", "shop"), hosted("reveal", "reveal"), hosted("reveal", "extra") }
			expect(UIGamepadRules.targetFrame(stack, screens)).to.equal("reveal:reveal")
		end)

		it("is nil when nothing is open or the top scene has no panel screen (a wheel)", function()
			expect(UIGamepadRules.targetFrame({}, {})).to.equal(nil)
			expect(UIGamepadRules.targetFrame({ "shop", "emoteWheel" }, { hosted("shop", "shop") })).to.equal(nil)
		end)
	end)

	describe("action", function()
		it("selects a button in the open panel for a gamepad player", function()
			expect(UIGamepadRules.action(true, "shop:shop", false)).to.equal("select")
		end)

		it("leaves a selection that is already inside the open panel alone", function()
			expect(UIGamepadRules.action(true, "shop:shop", true)).to.equal("none")
		end)

		it("never grabs focus for a mouse or touch player", function()
			expect(UIGamepadRules.action(false, "shop:shop", false)).to.equal("none")
		end)

		it("clears the selection once no panel is open, so the stick moves the character again", function()
			expect(UIGamepadRules.action(true, nil, false)).to.equal("clear")
			expect(UIGamepadRules.action(false, nil, false)).to.equal("clear")
		end)
	end)
end
