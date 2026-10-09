local SettingKeybindUtils = require(script.Parent.SettingKeybindUtils)

return function()
	describe("parse", function()
		it("parses actions with keyboard and gamepad keys", function()
			local map = SettingKeybindUtils.parse("interact=kb:F,MouseButton1/gp:ButtonY;sprint=kb:LeftControl")
			expect(map).to.be.ok()
			expect(map.interact.keyboard[1]).to.equal("F")
			expect(map.interact.keyboard[2]).to.equal("MouseButton1")
			expect(map.interact.gamepad[1]).to.equal("ButtonY")
			expect(map.sprint.keyboard[1]).to.equal("LeftControl")
			expect(#map.sprint.gamepad).to.equal(0)
		end)

		it("parses the empty string as no rebinds", function()
			local map = SettingKeybindUtils.parse("")
			expect(map).to.be.ok()
			expect(next(map)).to.equal(nil)
		end)

		it("rejects unknown keys, gamepad keys on the keyboard list and vice versa", function()
			expect((SettingKeybindUtils.parse("a=kb:NotAKey"))).to.equal(nil)
			expect((SettingKeybindUtils.parse("a=gp:E"))).to.equal(nil)
			expect((SettingKeybindUtils.parse("a=kb:ButtonA"))).to.equal(nil)
			expect((SettingKeybindUtils.parse("a=gp:MouseButton1"))).to.equal(nil)
		end)

		it("rejects malformed text", function()
			expect((SettingKeybindUtils.parse("noequals"))).to.equal(nil)
			expect((SettingKeybindUtils.parse("a=xx:E"))).to.equal(nil)
			expect((SettingKeybindUtils.parse("bad action=kb:E"))).to.equal(nil)
			expect((SettingKeybindUtils.parse("a=kb:E;a=kb:F"))).to.equal(nil)
			expect((SettingKeybindUtils.parse("a=kb:A,B,C,D,E"))).to.equal(nil)
			expect((SettingKeybindUtils.parse(string.rep("a", 2000)))).to.equal(nil)
		end)
	end)

	describe("format", function()
		it("round-trips through parse, sorted by action", function()
			local text = SettingKeybindUtils.format({
				sprint = { keyboard = { "LeftControl" }, gamepad = {} },
				interact = { keyboard = { "F" }, gamepad = { "ButtonY" } },
			})
			expect(text).to.equal("interact=kb:F/gp:ButtonY;sprint=kb:LeftControl")
			local map = SettingKeybindUtils.parse(text)
			expect(map.interact.gamepad[1]).to.equal("ButtonY")
		end)

		it("formats an empty map as the empty string", function()
			expect(SettingKeybindUtils.format({})).to.equal("")
		end)
	end)

	describe("toBindings", function()
		it("turns key names into enums", function()
			local bindings =
				SettingKeybindUtils.toBindings({ keyboard = { "F", "MouseButton2" }, gamepad = { "ButtonY" } })
			expect(bindings.keyboard[1]).to.equal(Enum.KeyCode.F)
			expect(bindings.keyboard[2]).to.equal(Enum.UserInputType.MouseButton2)
			expect(bindings.gamepad[1]).to.equal(Enum.KeyCode.ButtonY)
		end)
	end)
end
