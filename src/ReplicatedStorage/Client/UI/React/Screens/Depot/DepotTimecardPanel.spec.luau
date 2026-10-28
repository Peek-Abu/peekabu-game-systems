local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Panel = require(script.Parent.DepotTimecardPanel)
local Rules = require(ReplicatedStorage.Shared.Features.Timecard.Rules.TimecardRules)
return function()
	describe("DepotTimecardPanel", function()
		it("keeps the clock button accessible and disables today's recorded punch", function()
			local tree = Panel({
				phone = false,
				open = true,
				status = Rules.status({ week = 1792972800, punched = { 1 }, weeks = 0 }, 1792972800),
				progress = 0,
				target = 2,
				order = "Work 2 shifts",
				claimed = false,
				feedback = "",
				onToggle = function() end,
				onPunch = function() end,
			})
			expect(tree.props.children.toggle.props.text).to.equal("COMPANY CLIPBOARD")
			expect(tree.props.children.workOrderToggle).to.equal(nil)
			expect(tree.props.children.card.props.factor).to.equal(1)
			expect(tree.props.children.card.props.content.header.props.hue).to.equal("grape")
			expect(tree.props.children.card.props.content.card.props.pattern).to.equal("sparkle")
			expect(tree.props.children.card.props.content.card.props.children.dayTile1.props.hue).to.equal("mint")
			expect(tree.props.children.card.props.content.card.props.children.day1.props.wrapped).to.equal(true)
			expect(tree.props.children.card.props.content.card.props.children.punch.props.disabled).to.equal(true)
			expect(tree.props.children.card.props.content.card.props.children.day1.props.text).to.equal("MON\nPUNCHED")
		end)
		it("opens a separate daily order with progress, reset timer and automatic reward", function()
			local opened, closed = false, false
			local tree = Panel({
				phone = false,
				open = true,
				view = "workOrder",
				now = 1793059199,
				status = Rules.status({ week = 0, punched = {}, weeks = 0 }, 1793059199),
				progress = 1,
				target = 2,
				order = "Work 2 shifts",
				kind = "shifts",
				claimed = false,
				feedback = "",
				onToggle = function() end,
				onPunch = function() end,
				onWorkOrder = function()
					opened = true
				end,
				onClose = function()
					closed = true
				end,
			})
			tree.props.children.card.props.content.tabs.props.children.daily.props.onActivated()
			expect(opened).to.equal(true)
			local face = tree.props.children.card.props.content.card.props.children
			expect(face.objective.props.text).to.equal("Work 2 shifts")
			expect(face.meter.props.fill).to.equal(0.5)
			expect(face.meter.props.label).to.equal("1 / 2")
			expect(face.reset.props.text).to.equal("NEW ORDER IN 00:00:01 • UTC")
			expect(face.reward.props.text).to.equal("REWARD: 100 CREDITS")
			expect(face.punch).to.equal(nil)
			face.close.props.onActivated()
			expect(closed).to.equal(true)
		end)
		it("shows paid completion and keeps phone access within the header", function()
			local tree = Panel({
				phone = true,
				open = true,
				view = "workOrder",
				now = 1793059200,
				status = Rules.status({ week = 0, punched = {}, weeks = 0 }, 1793059200),
				progress = 2,
				target = 2,
				order = "Work 2 shifts",
				kind = "shifts",
				claimed = true,
				feedback = "",
				onToggle = function() end,
				onPunch = function() end,
			})
			local button = tree.props.children.toggle
			expect(button.props.position.X.Offset + button.props.size.X.Offset <= 650).to.equal(true)
			expect(tree.props.children.workOrderToggle).to.equal(nil)
			local face = tree.props.children.card.props.content.card.props.children
			expect(face.state.props.text).to.equal("COMPLETED • REWARD PAID")
			expect(face.reset.props.text).to.equal("NEW ORDER IN 24:00:00 • UTC")
			expect(face.meter.props.fill).to.equal(1)
		end)
	end)
end
