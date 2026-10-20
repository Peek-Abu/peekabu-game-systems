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

	describe("the open crew roster", function()
		local function member(userId, name)
			return {
				userId = userId,
				name = name,
				status = "vacuuming",
				short = "vacuuming",
				tone = "ok",
				struck = false,
				box = "empty",
			}
		end
		local roster = {
			title = "CREW ROSTER · TRUCK 2",
			members = { member(1, "Sam"), member(2, "Alex"), member(3, "Jo") },
			compact = {},
			compactDanger = {},
		}

		local function open(layout, viewport)
			local view = VM.hud(Fixtures.snapshot({}), {}, 0, false)
			local node = Panel({ view = view, roster = roster, layout = layout, viewport = viewport, crewOpen = true })
			return node.props.children.roster
		end

		it("draws over the Gloom meter's layer (the meter keeps the default ZIndex)", function()
			expect(open("phone", Vector2.new(844, 390)).props.zIndex).to.equal(2)
			expect(open("desktop", Vector2.new(1920, 1080)).props.zIndex).to.equal(2)
		end)

		it("opens on the left under the meter on phone and beside or under the crew list on desktop", function()
			-- Phone: 10 px in, 8 px under the meter (28 + 70 + 8), left of the clock-out board.
			expect(open("phone", Vector2.new(844, 390)).props.position).to.equal(UDim2.fromOffset(10, 106))
			-- 1920x1080: beside the list, as before.
			expect(open("desktop", Vector2.new(1920, 1080)).props.position).to.equal(UDim2.fromOffset(272, 66))
			-- 1366x768 (drawn at 0.75): the meter's Gloom render reaches past 572, so under the list.
			expect(open("desktop", Vector2.new(1366 / 0.75, 768 / 0.75)).props.position).to.equal(
				UDim2.fromOffset(24, 66 + 150 + 12)
			)
		end)

		it("on phone, ends before the clock-out board's clock render for 1-4 members", function()
			for _, viewport in { Vector2.new(844, 390), Vector2.new(667, 375) } do
				local half = viewport.X / 2
				for count = 1, 4 do
					local view = VM.hud(Fixtures.snapshot({}), {}, 0, false)
					local crew = table.clone(roster)
					crew.members = table.move(roster.members, 1, math.min(count, 3), 1, {})
					if count == 4 then
						table.insert(crew.members, member(4, "Pat"))
					end
					local node =
						Panel({ view = view, roster = crew, layout = "phone", viewport = viewport, crewOpen = true })
					local card = node.props.children.roster.props
					local right = card.position.X.Offset + card.size.X
					local bottom = card.position.Y.Offset + card.size.Y
					-- Board: 330 wide centred, its clock render reaching 29 px further left.
					expect(right <= half - 165 - 29 - 8).to.equal(true)
					-- Above the thumbstick's resting ring (bottom 150 px) with 8 px to spare.
					expect(bottom <= viewport.Y - 150 - 8).to.equal(true)
				end
			end
		end)

		it("cuts a long name short on a narrow phone and keeps the status whole", function()
			local view = VM.hud(Fixtures.snapshot({}), {}, 0, false)
			local crew = table.clone(roster)
			crew.members = { member(1, "Alexandria_Bloom2222") }
			local node = Panel({
				view = view,
				roster = crew,
				layout = "phone",
				viewport = Vector2.new(667, 375),
				crewOpen = true,
			})
			local text = node.props.children.roster.props.children.member1.props.text
			expect(text).never.to.equal("Alexandria_Bloom2222: vacuuming")
			expect(string.sub(text, -#": vacuuming")).to.equal(": vacuuming")
		end)
	end)
end
