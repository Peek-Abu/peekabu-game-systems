local EventPayFormulas = require(script.Parent.EventPayFormulas)

return function()
	local PAY = { finished = 10, contract = 10, firstToday = 20, friend = 5 }

	it("pays every finished shift its base", function()
		local out = EventPayFormulas.payout(PAY, { quotaMet = false, firstToday = false, withFriend = false })
		expect(out.total).to.equal(10)
		expect(table.concat(out.parts, ",")).to.equal("finished")
	end)

	it("adds the contract, the day's first shift and a friend, listing each part", function()
		local out = EventPayFormulas.payout(PAY, { quotaMet = true, firstToday = true, withFriend = true })
		expect(out.total).to.equal(45)
		expect(table.concat(out.parts, ",")).to.equal("finished,contract,firstToday,friend")
	end)

	it("leaves out a part worth 0", function()
		local out = EventPayFormulas.payout(
			{ finished = 10, contract = 0, firstToday = 20, friend = 0 },
			{ quotaMet = true, firstToday = false, withFriend = true }
		)
		expect(out.total).to.equal(10)
		expect(table.concat(out.parts, ",")).to.equal("finished")
	end)

	it("turns leftover money into the other currency at the rate", function()
		expect(EventPayFormulas.converted(37, 5)).to.equal(185)
		expect(EventPayFormulas.converted(0, 5)).to.equal(0)
	end)
end
