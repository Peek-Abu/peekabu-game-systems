local SocialPerksPanel = require(script.Parent.SocialPerksPanel)

return function()
	describe("SocialPerksPanel", function()
		it("offers the invite and the group perk with its Gleam", function()
			local invited, joined = false, false
			local tree = SocialPerksPanel({
				phone = false,
				showGroup = true,
				onInvite = function()
					invited = true
				end,
				onJoinGroup = function()
					joined = true
				end,
			})
			local buttons = tree.props.children
			expect(buttons.invite.props.text).to.equal("INVITE FRIENDS")
			expect(buttons.group.props.text).to.equal("JOIN GROUP +100")
			buttons.invite.props.onActivated()
			buttons.group.props.onActivated()
			expect(invited).to.equal(true)
			expect(joined).to.equal(true)
		end)

		it("drops the group button once the perk is paid, and the invite takes the whole row", function()
			local tree = SocialPerksPanel({
				phone = true,
				showGroup = false,
				onInvite = function() end,
				onJoinGroup = function() end,
			})
			local buttons = tree.props.children
			expect(buttons.group).to.equal(nil)
			expect(buttons.invite.props.size.X.Scale).to.equal(1)
		end)
	end)
end
