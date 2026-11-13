local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Panel = require(script.Parent.DepotTimecardPanel)
local Rules = require(ReplicatedStorage.Shared.Features.Timecard.Rules.TimecardRules)
local MONDAY = 1792972800
return function()
	describe("DepotTimecardPanel", function()
		local function base(overrides)
			local props = {
				phone = false,
				open = true,
				status = Rules.status({ week = MONDAY, punched = { 1 }, weeks = 0 }, MONDAY),
				progress = 0,
				target = 2,
				order = "Work 2 shifts",
				claimed = false,
				feedback = "",
				onToggle = function() end,
				onPunch = function() end,
			}
			for key, value in overrides or {} do
				props[key] = value
			end
			return Panel(props)
		end

		it("draws today's stamp over the Timecard face only while one shows", function()
			local function face(stamp)
				return base({ stamp = stamp }).props.children.card.props.content.card.props.children
			end
			expect(face(nil).stamp).to.equal(nil)
			local shown = face({ day = 1, count = 1, paycheque = false, id = "1792972800:1" }).stamp
			expect(shown.props.banner).to.equal("DAY 1! 2 MORE FOR A GLOOM KEY")
		end)

		it("is a coral clipboard with a sky Timecard sheet and a punch track", function()
			local tree = base()
			expect(tree.props.children.toggle.props.text).to.equal("COMPANY CLIPBOARD")
			expect(tree.props.children.card.props.factor).to.equal(1)
			local content = tree.props.children.card.props.content
			expect(content.board.props.hue).to.equal("coral")
			expect(content.card.props.hue).to.equal("sky")
			local face = content.card.props.children
			expect(face.slot1).to.be.ok()
			expect(face.slot5).to.be.ok()
			expect(face.prize3).to.be.ok()
			expect(face.prize5).to.be.ok()
			expect(face.done.props.text).to.equal("1 of 5 done")
			-- Today is already punched: the button says so and is off.
			expect(face.punch.props.disabled).to.equal(true)
			expect(face.punch.props.text).to.equal("PUNCHED TODAY")
		end)

		it("keeps only the big facts: no week code, no UTC, no filled-weeks line", function()
			local face = base().props.children.card.props.content.card.props.children
			for _, node in face do
				local text = node.props and node.props.text
				if type(text) == "string" then
					expect(string.find(text, "UTC", 1, true)).to.equal(nil)
					expect(string.find(text, "WEEK OF", 1, true)).to.equal(nil)
					expect(string.find(text, "filled weeks", 1, true)).to.equal(nil)
				end
			end
		end)

		it("opens today's job on a mint sheet with progress, the reward and the time to the next job", function()
			local opened, closed = false, false
			local tree = base({
				view = "workOrder",
				now = 1793059199,
				status = Rules.status({ week = 0, punched = {}, weeks = 0 }, 1793059199),
				progress = 1,
				kind = "shifts",
				onWorkOrder = function()
					opened = true
				end,
				onClose = function()
					closed = true
				end,
			})
			local content = tree.props.children.card.props.content
			content.tabs.props.children.daily.props.onActivated()
			expect(opened).to.equal(true)
			expect(content.card.props.hue).to.equal("mint")
			local face = content.card.props.children
			expect(face.objective.props.text).to.equal("WORK 2 SHIFTS")
			expect(face.meter.props.fill).to.equal(0.5)
			expect(face.meter.props.label).to.equal("1 / 2")
			expect(face.reset.props.children.text.props.text).to.equal("NEW JOB IN 1M")
			expect(face.rewardPlate.props.children.reward.props.text).to.equal("+100")
			expect(face.punch).to.equal(nil)
			expect(face.paid).to.equal(nil)
			content.close.props.onActivated()
			expect(closed).to.equal(true)
		end)

		it("marks a paid job and keeps the phone button within the header", function()
			local tree = base({
				phone = true,
				view = "workOrder",
				now = 1793059200,
				status = Rules.status({ week = 0, punched = {}, weeks = 0 }, 1793059200),
				progress = 2,
				kind = "shifts",
				claimed = true,
			})
			local button = tree.props.children.toggle
			expect(button.props.position.X.Offset + button.props.size.X.Offset <= 650).to.equal(true)
			local face = tree.props.children.card.props.content.card.props.children
			expect(face.paid.props.text).to.equal("PAID")
			expect(face.reset.props.children.text.props.text).to.equal("NEW JOB IN 24H 0M")
			expect(face.meter.props.fill).to.equal(1)
		end)
	end)
end
