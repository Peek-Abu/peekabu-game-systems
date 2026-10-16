local Panel = require(script.Parent.ShiftCompactHudPanel)
local VM = require(script.Parent.ShiftHudViewModel)
local Fixtures = require(script.Parent.ShiftStoryFixtures)
return function()
	describe("compact HUD disclosure", function()
		it("starts with crew detail closed and no permanent key-hint tray", function()
			local view = VM.hud(Fixtures.snapshot({}), {}, 0, false)
			local node = Panel({ view = view, layout = "desktop", viewport = Vector2.new(1192, 588), crewOpen = false })
			expect(node.props.children.roster).to.equal(nil)
			expect(node.props.children.hints).to.equal(nil)
		end)

		it("always draws the hotbar, and no separate tool card or cargo slip", function()
			local empty = VM.hud(Fixtures.snapshot({}), {}, 0, false)
			local node =
				Panel({ view = empty, layout = "desktop", viewport = Vector2.new(1192, 588), crewOpen = false })
			expect(node.props.children.hotbar).to.be.ok()
			expect(node.props.children.tool).to.equal(nil)
			expect(node.props.children.cargo).to.equal(nil)
			local phone = Panel({ view = empty, layout = "phone", viewport = Vector2.new(844, 390), crewOpen = false })
			expect(phone.props.children.hotbar).to.be.ok()
		end)

		it("names what the hands hold, with its keys, above the hotbar on desktop", function()
			local view =
				VM.hud(Fixtures.snapshot({}), { carrying = "monitor", inv1 = "monitor", invHands = 1 }, 0, false)
			local node = Panel({
				view = view,
				layout = "desktop",
				viewport = Vector2.new(1192, 588),
				crewOpen = false,
				bindings = { drop = { Enum.KeyCode.G } },
			})
			expect(node.props.children.holding).to.be.ok()
			local idle = Panel({
				view = VM.hud(Fixtures.snapshot({}), {}, 0, false),
				layout = "desktop",
				viewport = Vector2.new(1192, 588),
				crewOpen = false,
			})
			expect(idle.props.children.holding).to.equal(nil)
		end)
	end)
end
