local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Face = require(script.Parent.DepotTimecardFace)
local Rules = require(ReplicatedStorage.Shared.Features.Timecard.Rules.TimecardRules)
local MONDAY = 1792972800
return function()
	describe("DepotTimecardFace", function()
		local function face(overrides)
			local props = {
				status = Rules.status({ week = MONDAY, punched = { 1 }, weeks = 0 }, MONDAY),
				feedback = "",
				onPunch = function() end,
			}
			for key, value in overrides or {} do
				props[key] = value
			end
			return Face(props)
		end

		it("draws a slot per punch with the prizes under the key and last punches", function()
			local nodes = face()
			expect(nodes.slot1).to.be.ok()
			expect(nodes.slot5).to.be.ok()
			expect(nodes.prize3).to.be.ok()
			expect(nodes.prize5).to.be.ok()
			expect(nodes.track).to.be.ok()
			expect(nodes.paycheck).to.be.ok()
			expect(nodes.done.props.text).to.equal("1 of 5 done")
		end)

		it("shows the feedback in place of the done count when there is some", function()
			expect(face({ feedback = "Punched!" }).done.props.text).to.equal("Punched!")
		end)

		it("turns the punch button off and still once today is punched", function()
			local nodes = face()
			expect(nodes.punch.props.active).to.equal(false)
			expect(nodes.punch.props.children.button.props.disabled).to.equal(true)
			expect(nodes.punch.props.children.button.props.text).to.equal("PUNCHED TODAY")
		end)

		it("pulses PUNCH IN! while today's punch is free, and not while one is pending", function()
			local free = Rules.status({ week = MONDAY, punched = {}, weeks = 0 }, MONDAY)
			local nodes = face({ status = free })
			expect(nodes.punch.props.active).to.equal(true)
			expect(nodes.punch.props.children.button.props.text).to.equal("PUNCH IN!")
			expect(nodes.punch.props.children.button.props.disabled).to.equal(false)
			local pending = face({ status = free, pending = true })
			expect(pending.punch.props.active).to.equal(false)
			expect(pending.punch.props.children.button.props.disabled).to.equal(true)
		end)

		it("draws today's stamp only while one shows", function()
			expect(face().stamp).to.equal(nil)
			local shown = face({ stamp = { day = 1, count = 1, paycheque = false, id = "1792972800:1" } }).stamp
			expect(shown.props.banner).to.equal("DAY 1! 2 MORE FOR A GLOOM KEY")
		end)
	end)
end
