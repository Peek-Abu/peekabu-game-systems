local ShiftKeyHintViewModel = require(script.Parent.ShiftKeyHintViewModel)

return function()
	describe("key hints", function()
		it("names keys and mouse buttons the way the HUD prints them", function()
			expect(ShiftKeyHintViewModel.keyName(Enum.KeyCode.G)).to.equal("G")
			expect(ShiftKeyHintViewModel.keyName(Enum.KeyCode.LeftControl)).to.equal("Ctrl")
			expect(ShiftKeyHintViewModel.keyName(Enum.UserInputType.MouseButton1)).to.equal("LMB")
			expect(ShiftKeyHintViewModel.keyName(Enum.KeyCode.Left)).to.equal("←")
		end)

		it("lists the actions in Figma's order with each first keyboard binding", function()
			local hints = ShiftKeyHintViewModel.keyHints({
				vacuum = { Enum.UserInputType.MouseButton1 },
				drop = { Enum.KeyCode.G },
				throw = { Enum.KeyCode.F },
				interact = { Enum.KeyCode.E },
			})
			expect(#hints).to.equal(4)
			expect(hints[1].prefix).to.equal("Hold")
			expect(hints[1].key).to.equal("LMB")
			expect(hints[1].label).to.equal("vacuum")
			expect(hints[4].key).to.equal("E")
			expect(hints[4].label).to.equal("bank / search")
		end)

		it("names gamepad buttons the way a controller prints them", function()
			expect(ShiftKeyHintViewModel.keyName(Enum.KeyCode.ButtonX)).to.equal("X")
			expect(ShiftKeyHintViewModel.keyName(Enum.KeyCode.ButtonR1)).to.equal("RB")
			expect(ShiftKeyHintViewModel.keyName(Enum.KeyCode.ButtonR2)).to.equal("RT")
			expect(ShiftKeyHintViewModel.keyName(Enum.KeyCode.ButtonL1)).to.equal("LB")
			expect(ShiftKeyHintViewModel.keyName(Enum.KeyCode.ButtonL2)).to.equal("LT")
			expect(ShiftKeyHintViewModel.keyName(Enum.KeyCode.ButtonL3)).to.equal("L3")
			expect(ShiftKeyHintViewModel.keyName(Enum.KeyCode.DPadDown)).to.equal("D↓")
		end)

		it("prints a prompt's gamepad button for a controller player and its key otherwise", function()
			expect(ShiftKeyHintViewModel.promptKey(Enum.KeyCode.E, Enum.KeyCode.ButtonX, true)).to.equal("X")
			expect(ShiftKeyHintViewModel.promptKey(Enum.KeyCode.E, Enum.KeyCode.ButtonX, false)).to.equal("E")
			expect(ShiftKeyHintViewModel.promptKey(Enum.KeyCode.C, Enum.KeyCode.ButtonL1, true)).to.equal("LB")
		end)

		it("reads each hint's gamepad bindings for a controller player, crouch from its toggle", function()
			local hints = ShiftKeyHintViewModel.keyHints({
				vacuum = { Enum.KeyCode.ButtonR2 },
				drop = { Enum.KeyCode.DPadDown },
				crouch = { Enum.KeyCode.ButtonB },
			}, true)
			expect(#hints).to.equal(3)
			expect(hints[1].key).to.equal("RT")
			expect(hints[1].prefix).to.equal("Hold")
			expect(hints[2].key).to.equal("D↓")
			-- On a gamepad crouch is a toggle (crouchToggle), not a hold.
			expect(hints[3].key).to.equal("B")
			expect(hints[3].prefix).to.equal(nil)
		end)

		it("names the gamepad action each hint reads (crouch reads its toggle)", function()
			expect(ShiftKeyHintViewModel.padAction("crouch")).to.equal("crouchToggle")
			expect(ShiftKeyHintViewModel.padAction("drop")).to.equal("drop")
		end)

		it("skips an action with no binding", function()
			expect(#ShiftKeyHintViewModel.keyHints({ drop = { Enum.KeyCode.G } })).to.equal(1)
		end)

		it("names the hint actions it reads bindings for", function()
			local actions = ShiftKeyHintViewModel.HINT_ACTIONS
			expect(#actions).to.equal(6)
			expect(actions[1]).to.equal("vacuum")
			expect(actions[4]).to.equal("interact")
			expect(actions[5]).to.equal("sprint")
			expect(actions[6]).to.equal("crouch")
		end)
	end)
end
